import Combine
import Foundation

@MainActor
public final class SessionStore: ObservableObject {
    @Published public var promiseDraft: String = ""
    @Published public var durationMinutes: Int = 25
    @Published public private(set) var session: FocusSession?
    @Published public private(set) var remainingSeconds: TimeInterval = 0
    @Published public private(set) var currentContext: ContextSnapshot?
    @Published public private(set) var captureState: CaptureState = .inactive
    @Published public private(set) var permissionSnapshot = PermissionSnapshot(
        accessibilityGranted: false,
        screenRecordingGranted: false,
        codexReady: false
    )
    @Published public private(set) var lastClassification: ClassificationResult?
    @Published public private(set) var activeRecoveryPlan: RecoveryPlan?
    @Published public private(set) var lastRuleDecision: RuleDecision = .noDecision
    @Published public private(set) var correctionNotice: String?
    @Published public var classifierSettings: AIClassifierSettings {
        didSet {
            classifierSettingsStore.save(classifierSettings)
            aiDecisionMemory = nil
        }
    }
    @Published public private(set) var aiUsageStats = AIClassifierUsageStats()

    public let diagnostics: DiagnosticsStore
    public let ruleStore: LocalRuleStore
    public let screenshotBuffer: ScreenshotBuffer

    private let classifierSettingsStore: AIClassifierSettingsStoring
    private let permissionManager: PermissionManager
    private let sampler: ContextSampling
    private let ruleEngine: RuleEngine
    private let classifier: Classifier
    private let recoveryPlanner: RecoveryPlanner

    private var timerTask: Task<Void, Never>?
    private var samplerTask: Task<Void, Never>?
    private var lastCodexAttemptAt: Date?
    private var aiDecisionMemory: AIContextDecision?
    private var interruptionPausedAt: Date?

    public init(
        diagnostics: DiagnosticsStore = DiagnosticsStore(),
        ruleStore: LocalRuleStore = LocalRuleStore(storageURL: LocalRuleStore.defaultStorageURL),
        screenshotBuffer: ScreenshotBuffer = ScreenshotBuffer(),
        classifierSettings: AIClassifierSettings? = nil,
        classifierSettingsStore: AIClassifierSettingsStoring = UserDefaultsAIClassifierSettingsStore(),
        permissionManager: PermissionManager = PermissionManager(),
        sampler: ContextSampling = ContextSampler(),
        ruleEngine: RuleEngine = RuleEngine(),
        classifier: Classifier = CodexCliClassifier(),
        recoveryPlanner: RecoveryPlanner = RecoveryPlanner()
    ) {
        self.diagnostics = diagnostics
        self.ruleStore = ruleStore
        self.screenshotBuffer = screenshotBuffer
        self.classifierSettingsStore = classifierSettingsStore
        self.classifierSettings = classifierSettings ?? classifierSettingsStore.load()
        self.permissionManager = permissionManager
        self.sampler = sampler
        self.ruleEngine = ruleEngine
        self.classifier = classifier
        self.recoveryPlanner = recoveryPlanner
    }

    deinit {
        timerTask?.cancel()
        samplerTask?.cancel()
    }

    public func refreshSetup() {
        Task {
            let snapshot = await permissionManager.snapshot(classifierSettings: classifierSettings)
            permissionSnapshot = snapshot
            captureState = snapshot.screenRecordingGranted ? captureState : .blockedByPermission
            if snapshot.codexReady == false {
                diagnostics.record(.warning, "Codex preflight is not ready: \(snapshot.codexError ?? "unknown error")")
            }
        }
    }

    public func startSession() {
        let promise = promiseDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard promise.isEmpty == false else {
            diagnostics.record(.warning, "A promise is required before starting a session.")
            return
        }

        setRecoveryPlan(nil)
        lastClassification = nil
        lastRuleDecision = .noDecision
        correctionNotice = nil
        aiUsageStats = AIClassifierUsageStats()
        aiDecisionMemory = nil
        lastCodexAttemptAt = nil
        let initialContext = currentContext
        let newSession = FocusSession(
            promise: promise,
            durationSeconds: TimeInterval(durationMinutes * 60),
            lastFocusedApp: initialContext?.foregroundApp
        )
        session = newSession
        remainingSeconds = newSession.durationSeconds
        captureState = permissionSnapshot.screenRecordingGranted ? .activeLocally : .blockedByPermission
        diagnostics.record(.info, "Started promise: \(promise)")
        startTicker()
        startSamplingLoop()
    }

    public func endSession() {
        completeSession(diagnostic: "Ended current session.")
    }

    public func restart(minutes: Int) {
        guard var active = session else { return }
        active.startedAt = Date()
        active.durationSeconds = TimeInterval(minutes * 60)
        session = active
        remainingSeconds = active.durationSeconds
        interruptionPausedAt = nil
        activeRecoveryPlan = nil
        diagnostics.record(.info, "Restarted timer for \(minutes) minutes.")
    }

    public func dismissInterruption() {
        setRecoveryPlan(nil)
    }

    @discardableResult
    public func allowCurrentContext(scope: RuleScope = .session) -> Bool {
        guard let context = currentContext else {
            diagnostics.record(.warning, "Could not save allow correction because no current context was available.")
            return false
        }
        let target: RuleTarget
        if let domain = context.domain {
            target = .domain(domain)
        } else {
            target = .app(context.foregroundApp)
        }
        let rule = FocusRule(
            kind: .allow,
            scope: scope,
            target: target,
            promiseContains: scope == .promise ? session?.promise : nil,
            reason: "Allowed by correction.",
            recoveryAction: .none
        )
        do {
            try ruleStore.save(rule)
            correctionNotice = "Allowed \(target.label)."
            setRecoveryPlan(nil)
            diagnostics.record(.info, "Saved allow correction for \(target.label).")
            aiDecisionMemory = nil
            return true
        } catch {
            diagnostics.record(.error, "Could not save allow correction: \(error)")
            return false
        }
    }

    @discardableResult
    public func blockCurrentContextForSession() -> Bool {
        guard let context = currentContext else {
            diagnostics.record(.warning, "Could not save block correction because no current context was available.")
            return false
        }
        let target: RuleTarget
        if let domain = context.domain {
            target = .domain(domain)
        } else {
            target = .app(context.foregroundApp)
        }
        let rule = FocusRule(
            kind: .block,
            scope: .session,
            target: target,
            reason: "Blocked by correction.",
            recoveryAction: context.domain == nil ? .quitApp : .closeTab
        )
        do {
            try ruleStore.save(rule)
            correctionNotice = "Blocked \(target.label) for this session."
            diagnostics.record(.info, "Saved block correction for \(target.label).")
            aiDecisionMemory = nil
            return true
        } catch {
            diagnostics.record(.error, "Could not save block correction: \(error)")
            return false
        }
    }

    public func evaluateOnce() {
        guard session != nil else { return }
        Task { await evaluateCurrentContext() }
    }

    private func startTicker() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while Task.isCancelled == false {
                guard let self else { return }
                await MainActor.run {
                    guard let session = self.session else { return }
                    guard self.interruptionPausedAt == nil else { return }
                    self.remainingSeconds = session.remainingSeconds()
                    if session.isDone() {
                        self.completeSession(diagnostic: "Promise timer completed.")
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func startSamplingLoop() {
        samplerTask?.cancel()
        samplerTask = Task { [weak self] in
            while Task.isCancelled == false {
                await self?.evaluateCurrentContext()
                try? await Task.sleep(nanoseconds: 6_000_000_000)
            }
        }
    }

    private func evaluateCurrentContext() async {
        guard let activeSession = session, activeSession.isDone() == false else { return }
        guard activeRecoveryPlan?.shouldInterrupt != true else { return }

        let state = permissionSnapshot.screenRecordingGranted ? CaptureState.activeLocally : .blockedByPermission
        let context = await sampler.sample(captureState: state)
        currentContext = context
        captureState = screenshotBuffer.canCapture(context: context) ? state : .sensitiveAppExcluded

        if context.idleSeconds >= 90 {
            let result = ClassificationResult(
                status: .inactive,
                confidence: 1,
                reason: "The Mac has been idle for \(Int(context.idleSeconds)) seconds.",
                recoveryAction: .restartTimer,
                interrupt: false
            )
            lastClassification = result
            setRecoveryPlan(recoveryPlanner.plan(classification: result, context: context, session: activeSession))
            diagnostics.record(.info, "Context is inactive, not distracted.")
            return
        }

        let ruleDecision = ruleEngine.decide(context: context, promise: activeSession.promise, rules: ruleStore.rules)
        lastRuleDecision = ruleDecision

        switch ruleDecision {
        case .allow(let reason):
            aiUsageStats.recordLocalRuleDecision()
            lastClassification = ClassificationResult(status: .focused, confidence: 1, reason: reason, recoveryAction: .none, interrupt: false)
            setRecoveryPlan(nil)
            return
        case .block(let reason, let action):
            aiUsageStats.recordLocalRuleDecision()
            let result = ClassificationResult(status: .distracted, confidence: 1, reason: reason, recoveryAction: action, interrupt: true)
            lastClassification = result
            setRecoveryPlan(recoveryPlanner.plan(classification: result, context: context, session: activeSession))
            diagnostics.record(.warning, "Rule interruption: \(reason)")
            return
        case .conflict(let reason):
            aiUsageStats.recordLocalRuleDecision()
            lastClassification = ClassificationResult(status: .unknown, confidence: 0, reason: reason, recoveryAction: .none, interrupt: false)
            setRecoveryPlan(nil)
            diagnostics.record(.warning, reason)
            return
        case .noDecision:
            break
        }

        guard permissionSnapshot.codexReady else {
            captureState = .localRulesOnly
            aiUsageStats.recordUnavailableSkip()
            diagnostics.record(.warning, "Codex unavailable; staying in local-rules-only mode.")
            return
        }

        let now = Date()
        let fingerprint = AIContextFingerprint(promise: activeSession.promise, context: context)
        if let memory = aiDecisionMemory,
           memory.canReuse(for: fingerprint, settings: classifierSettings, now: now) {
            aiUsageStats.recordReuse()
            lastClassification = memory.result
            let plan = recoveryPlanner.plan(classification: memory.result, context: context, session: activeSession)
            setRecoveryPlan(plan.shouldInterrupt ? plan : nil)
            diagnostics.record(.info, "Reused AI decision for unchanged context.")
            return
        }

        let contextChanged = aiDecisionMemory?.fingerprint != fingerprint
        if let lastCodexAttemptAt,
           now.timeIntervalSince(lastCodexAttemptAt) < classifierSettings.cadence.changedContextMinimumInterval,
           contextChanged {
            aiUsageStats.recordCooldownSkip()
            lastClassification = ClassificationResult(
                status: .unknown,
                confidence: 0,
                reason: "AI check delayed by cadence after a recent classification.",
                recoveryAction: .none,
                interrupt: false
            )
            setRecoveryPlan(nil)
            diagnostics.record(.info, "AI check delayed by cadence after context changed.")
            return
        }

        captureState = .snapshotSelectedForCodex
        lastCodexAttemptAt = now
        aiUsageStats.recordAICheck(settings: classifierSettings, screenshotSent: false)
        let result = await classifier.classify(
            promise: activeSession.promise,
            context: context,
            screenshotPath: nil,
            settings: classifierSettings
        )
        lastClassification = result
        captureState = .activeLocally
        if result.status != .unknown {
            aiDecisionMemory = AIContextDecision(
                fingerprint: fingerprint,
                result: result,
                decidedAt: now,
                model: classifierSettings.normalizedModel
            )
        }
        let plan = recoveryPlanner.plan(classification: result, context: context, session: activeSession)
        setRecoveryPlan(plan.shouldInterrupt ? plan : nil)
        diagnostics.record(.info, "Codex \(classifierSettings.normalizedModel) classified \(result.status.rawValue) at \(String(format: "%.2f", result.confidence)).")
    }

    private func setRecoveryPlan(_ plan: RecoveryPlan?) {
        if plan?.shouldInterrupt == true {
            pauseTimerForInterruption()
        } else {
            resumeTimerAfterInterruption()
        }
        activeRecoveryPlan = plan
    }

    private func pauseTimerForInterruption() {
        guard interruptionPausedAt == nil else { return }
        remainingSeconds = session?.remainingSeconds() ?? remainingSeconds
        interruptionPausedAt = Date()
        diagnostics.record(.info, "Paused timer for interruption.")
    }

    private func resumeTimerAfterInterruption() {
        guard let interruptionPausedAt else { return }
        if var active = session {
            let pausedDuration = max(0, Date().timeIntervalSince(interruptionPausedAt))
            active.startedAt = active.startedAt.addingTimeInterval(pausedDuration)
            session = active
            remainingSeconds = active.remainingSeconds()
            diagnostics.record(.info, "Resumed timer after interruption.")
        }
        self.interruptionPausedAt = nil
    }

    private func completeSession(diagnostic: String) {
        diagnostics.record(.info, diagnostic)
        timerTask?.cancel()
        samplerTask?.cancel()
        timerTask = nil
        samplerTask = nil
        session = nil
        remainingSeconds = 0
        interruptionPausedAt = nil
        activeRecoveryPlan = nil
        captureState = .inactive
        screenshotBuffer.clear()
        aiDecisionMemory = nil
        lastCodexAttemptAt = nil
    }
}
