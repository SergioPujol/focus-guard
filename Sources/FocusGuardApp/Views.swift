import AppKit
import FocusGuardCore
import SwiftUI

private enum FGTheme {
    static let backgroundOverlay = Color.black.opacity(0.34)
    static let elevated = Color.white.opacity(0.075)
    static let elevatedStrong = Color.white.opacity(0.12)
    static let stroke = Color.white.opacity(0.12)
    static let primary = Color.white.opacity(0.94)
    static let secondary = Color.white.opacity(0.58)
    static let tertiary = Color.white.opacity(0.36)
    static let focus = Color(red: 0.48, green: 0.94, blue: 0.62)
    static let warning = Color(red: 1.0, green: 0.46, blue: 0.42)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.35)
}

private enum PopoverPage: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case settings = "Settings"
    case log = "Log"

    var id: Self { self }

    var icon: String {
        switch self {
        case .overview: "target"
        case .settings: "slider.horizontal.3"
        case .log: "terminal"
        }
    }
}

struct FocusGuardPopoverView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject private var diagnostics: DiagnosticsStore
    @State private var selectedPage: PopoverPage = .overview
    @State private var showPromiseRequired = false

    init(store: SessionStore) {
        self.store = store
        self.diagnostics = store.diagnostics
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            FGTheme.backgroundOverlay

            HStack(spacing: 0) {
                sidebarNavigation

                Rectangle()
                    .fill(FGTheme.stroke)
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 14) {
                    header

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            switch selectedPage {
                            case .overview:
                                sessionControls
                                if store.permissionSnapshot.isReady == false {
                                    setupWarning
                                }
                                contextPanel
                            case .settings:
                                aiSettingsPanel
                                aiUsagePanel
                                setupPanel
                            case .log:
                                diagnosticsPanel
                            }
                        }
                        .padding(.bottom, 18)
                    }
                    .scrollIndicators(.visible)
                }
                .padding(18)
            }
        }
        .frame(width: 430, height: 560, alignment: .topLeading)
        .foregroundStyle(FGTheme.primary)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FocusGuard")
                    .font(.system(size: 16, weight: .semibold))
                Text(headerSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FGTheme.secondary)
            }

            Spacer()

            statusBadge
        }
    }

    private var sidebarNavigation: some View {
        VStack(spacing: 12) {
            FocusGuardMark(size: 18)
                .frame(width: 34, height: 34)
                .padding(.top, 14)

            VStack(spacing: 8) {
                sidebarButton(.overview)
                sidebarButton(.log)
            }

            Spacer()

            sidebarButton(.settings)

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(FGTheme.secondary)
            .help("Quit FocusGuard")
            .padding(.bottom, 14)
        }
        .frame(width: 48)
        .background(Color.black.opacity(0.12))
    }

    private func sidebarButton(_ page: PopoverPage) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedPage = page
            }
        } label: {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selectedPage == page ? FGTheme.elevatedStrong : Color.clear)
                    .frame(width: 34, height: 34)
                if selectedPage == page {
                    Capsule()
                        .fill(FGTheme.focus)
                        .frame(width: 3, height: 16)
                        .offset(x: -6)
                }
                Image(systemName: page.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selectedPage == page ? FGTheme.primary : FGTheme.secondary)
                    .frame(width: 34, height: 34)
            }
            .frame(width: 34, height: 34)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(page.rawValue)
    }

    private var sessionControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let session = store.session {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ACTIVE PROMISE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(FGTheme.tertiary)
                    Text(session.promise)
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .firstTextBaseline) {
                        Text(formatTime(store.remainingSeconds))
                            .font(.system(size: 44, weight: .medium, design: .monospaced))
                            .minimumScaleFactor(0.82)
                        Spacer()
                        Text("\(Int(session.durationSeconds / 60)) MIN")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(FGTheme.secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(FGTheme.elevatedStrong, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }

                    GeometryReader { proxy in
                        let width = proxy.size.width * max(0.04, sessionProgress(session))
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(FGTheme.focus)
                                .frame(width: width)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(16)
                .background(FGTheme.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(FGTheme.stroke)
                )

                HStack(spacing: 8) {
                    CommandButton(title: "Check", systemImage: "bolt.fill") { store.evaluateOnce() }
                    CommandButton(title: "Restart 10", systemImage: "arrow.clockwise") { store.restart(minutes: 10) }
                    CommandButton(title: "End", systemImage: "stop.fill", role: .destructive) { store.endSession() }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("WHAT ARE YOU PROTECTING?")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(FGTheme.tertiary)
                    TextField("Ship the allocator fix", text: $store.promiseDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(FGTheme.primary)
                        .padding(12)
                        .background(FGTheme.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(FGTheme.stroke)
                        )
                        .onChange(of: store.promiseDraft) { newValue in
                            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                                showPromiseRequired = false
                            }
                        }
                    if showPromiseRequired {
                        Label("Type a promise before starting.", systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FGTheme.amber)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("SESSION LENGTH")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(FGTheme.tertiary)
                    Picker("Duration", selection: $store.durationMinutes) {
                        Text("10 min").tag(10)
                        Text("25 min").tag(25)
                        Text("1h").tag(60)
                    }
                    .pickerStyle(.segmented)
                }

                Button {
                    startPromise()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Promise")
                        Spacer()
                        Text("return")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.46))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.black.opacity(0.88))
                .background(FGTheme.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var setupWarning: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedPage = .settings
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FGTheme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Setup needs attention")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FGTheme.primary)
                    Text("Open Settings to finish permissions and Codex readiness.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FGTheme.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FGTheme.tertiary)
            }
            .padding(12)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(FGTheme.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(FGTheme.amber.opacity(0.18))
            )
        }
        .buttonStyle(.plain)
    }

    private var contextPanel: some View {
        SectionBlock(title: "Current Signal", actionTitle: nil, systemImage: "waveform.path.ecg") {
            if let context = store.currentContext {
                SignalRow(systemImage: "app.dashed", label: "App", value: context.foregroundApp)
                SignalRow(systemImage: "macwindow", label: "Window", value: context.windowTitle ?? "Unavailable")
                if let browserURL = context.browserURL {
                    SignalRow(systemImage: "link", label: "URL", value: browserURL)
                }
                SignalRow(systemImage: "clock", label: "Idle", value: "\(Int(context.idleSeconds))s")
                if let classification = store.lastClassification {
                    SignalRow(
                        systemImage: classificationIcon(classification.status),
                        label: "Classifier",
                        value: "\(classification.status.rawValue) / \(classification.recoveryAction.rawValue)",
                        tint: classificationTint(classification.status)
                    )
                }
            } else {
                EmptyStateLine(systemImage: "dot.radiowaves.left.and.right", text: "No context sample yet.")
            }
            if let notice = store.correctionNotice {
                EmptyStateLine(systemImage: "checkmark.circle.fill", text: notice, tint: FGTheme.focus)
            }
        }
    }

    private var setupPanel: some View {
        SectionBlock(title: "Preflight", actionTitle: "Retest", systemImage: "checklist") {
            ForEach(store.permissionSnapshot.setupItems) { item in
                SetupRow(item: item) {
                    requestPermission(for: item.kind)
                    store.refreshSetup()
                }
            }
        } action: {
            store.refreshSetup()
        }
    }

    private var aiSettingsPanel: some View {
        SectionBlock(title: "AI Classifier", actionTitle: nil, systemImage: "brain.head.profile") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MODEL")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(FGTheme.tertiary)
                    TextField("gpt-5.3-codex", text: $store.classifierSettings.model)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(FGTheme.primary)
                        .padding(9)
                        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(FGTheme.stroke)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("REASONING")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(FGTheme.tertiary)
                    Picker("Reasoning", selection: $store.classifierSettings.reasoningEffort) {
                        ForEach(AIReasoningEffort.allCases) { effort in
                            Text(effort.displayText).tag(effort)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("CADENCE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(FGTheme.tertiary)
                    Picker("Cadence", selection: $store.classifierSettings.cadence) {
                        ForEach(AICheckCadence.allCases) { cadence in
                            Text(cadence.displayText).tag(cadence)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
    }

    private var aiUsagePanel: some View {
        let stats = store.aiUsageStats
        return SectionBlock(title: "AI Usage", actionTitle: nil, systemImage: "chart.bar.xaxis") {
            SignalRow(systemImage: "cpu", label: "Model", value: store.classifierSettings.normalizedModel)
            SignalRow(systemImage: "brain", label: "AI checks", value: "\(stats.aiChecks)")
            SignalRow(systemImage: "arrow.triangle.2.circlepath", label: "Reused", value: "\(stats.reusedDecisions)")
            SignalRow(systemImage: "checkmark.shield", label: "Rules", value: "\(stats.localRuleDecisions)")
            SignalRow(systemImage: "timer", label: "Cooldown", value: "\(stats.cooldownSkips)")
            SignalRow(systemImage: "camera.viewfinder", label: "Shots sent", value: "\(stats.screenshotsSent)")
            SignalRow(systemImage: "dollarsign.circle", label: "Est. cost", value: formatCost(stats.estimatedCostUSD))
        }
    }

    private var diagnosticsPanel: some View {
        SectionBlock(title: "Console", actionTitle: nil, systemImage: "terminal") {
            if diagnostics.entries.isEmpty {
                EmptyStateLine(systemImage: "terminal", text: "No events yet.")
            } else {
                ForEach(diagnostics.entries.suffix(3)) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(diagnosticTint(entry.level))
                            .frame(width: 6, height: 6)
                        Text(entry.message)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(entry.level == .error ? FGTheme.warning : FGTheme.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var headerSubtitle: String {
        store.session == nil ? "Menu-bar focus recovery" : store.captureState.displayText
    }

    private var statusBadge: some View {
        let ready = store.permissionSnapshot.isReady
        let active = store.session != nil
        return HStack(spacing: 6) {
            Circle()
                .fill(active ? FGTheme.focus : (ready ? FGTheme.secondary : FGTheme.amber))
                .frame(width: 7, height: 7)
            Text(active ? "LIVE" : (ready ? "READY" : "SETUP"))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(FGTheme.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(FGTheme.stroke)
        )
    }

    private func sessionProgress(_ session: FocusSession) -> Double {
        guard session.durationSeconds > 0 else { return 0 }
        return 1 - (store.remainingSeconds / session.durationSeconds)
    }

    private func startPromise() {
        let promise = store.promiseDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard promise.isEmpty == false else {
            showPromiseRequired = true
            return
        }
        showPromiseRequired = false
        store.startSession()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatCost(_ cost: Double) -> String {
        if cost <= 0 {
            return "$0.00"
        }
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        }
        return String(format: "$%.2f", cost)
    }

    private func classificationIcon(_ status: ClassifierStatus) -> String {
        switch status {
        case .focused: "checkmark.circle.fill"
        case .related: "arrow.triangle.branch"
        case .distracted: "exclamationmark.triangle.fill"
        case .inactive: "moon.zzz.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func classificationTint(_ status: ClassifierStatus) -> Color {
        switch status {
        case .focused, .related: FGTheme.focus
        case .distracted: FGTheme.warning
        case .inactive, .unknown: FGTheme.amber
        }
    }

    private func diagnosticTint(_ level: DiagnosticLevel) -> Color {
        switch level {
        case .info: FGTheme.focus
        case .warning: FGTheme.amber
        case .error: FGTheme.warning
        }
    }

    private func requestPermission(for kind: SetupItemKind) {
        switch kind {
        case .accessibility:
            let promptKey = "AXTrustedCheckOptionPrompt"
            AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        case .screenRecording:
            CGRequestScreenCaptureAccess()
        case .codex:
            break
        }
    }
}

struct InterruptionView: View {
    @ObservedObject var store: SessionStore
    let plan: RecoveryPlan
    @State private var isPerformingPrimaryAction = false
    @State private var actionMessage: String?
    @State private var actionMessageIsError = false
    @State private var manualFallbackActive = false

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            Color.black.opacity(0.46)

            VStack(spacing: 0) {
                interruptionTitleBar

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(FGTheme.warning)
                            .frame(width: 38, height: 38)
                            .background(FGTheme.warning.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text("DRIFT DETECTED")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(FGTheme.warning)
                            Text("Return to the promise")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(FGTheme.primary)
                            Text("Handle the distraction, mark it relevant, or end the session.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(FGTheme.secondary)
                        }

                        Spacer(minLength: 0)
                    }

                    promiseCard

                    VStack(alignment: .leading, spacing: 12) {
                        SignalRow(systemImage: "scope", label: "Current", value: contextText, tint: FGTheme.warning)
                        SignalRow(systemImage: "text.badge.checkmark", label: "Reason", value: plan.trigger)
                        SignalRow(systemImage: "arrow.turn.up.left", label: "Next", value: plan.fallbackInstruction)
                    }

                    if let actionMessage {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: actionMessageIsError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(actionMessageIsError ? FGTheme.amber : FGTheme.focus)
                            Text(actionMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(FGTheme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FGTheme.elevated.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(actionMessageIsError ? FGTheme.amber.opacity(0.22) : FGTheme.stroke)
                        )
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        Button {
                            let saved = store.allowCurrentContext()
                            if saved == false {
                                actionMessage = "No current app or tab was available to save, so this interruption was dismissed."
                                actionMessageIsError = false
                            }
                        } label: {
                            Label(plan.correctionActionTitle, systemImage: "checkmark.circle")
                                .lineLimit(1)
                                .minimumScaleFactor(0.88)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(InterruptionButtonStyle(kind: .secondary))
                        .help("Mark this app or domain as relevant for this session")

                        Button {
                            store.endSession()
                        } label: {
                            Label("End Session", systemImage: "stop.fill")
                                .lineLimit(1)
                                .minimumScaleFactor(0.88)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(InterruptionButtonStyle(kind: .destructive))
                        .help("End the current promise")

                        Button {
                            performPrimaryAction()
                        } label: {
                            HStack(spacing: 7) {
                                if isPerformingPrimaryAction {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.72)
                                } else {
                                    Image(systemName: manualFallbackActive ? "checkmark.circle.fill" : "arrow.up.forward.circle.fill")
                                }
                                Text(primaryButtonTitle)
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(InterruptionButtonStyle(kind: .primary))
                        .keyboardShortcut(.defaultAction)
                        .disabled(isPerformingPrimaryAction)
                        .help(primaryButtonHelp)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 22)
            }
        }
        .frame(width: 520, height: 460)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FGTheme.stroke)
        )
    }

    private var interruptionTitleBar: some View {
        HStack(spacing: 8) {
            FocusGuardMark(
                size: 13,
                baseColor: FGTheme.secondary
            )
            Text("FocusGuard")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FGTheme.secondary)
            Spacer()
            Button {
                store.dismissInterruption()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(FGTheme.secondary)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(FGTheme.stroke)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .keyboardShortcut(.cancelAction)
            .help("Dismiss")
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.18))
    }

    private var promiseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROMISE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(FGTheme.tertiary)
            Text(store.session?.promise ?? "Focus session")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FGTheme.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FGTheme.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FGTheme.stroke)
        )
    }

    private var contextText: String {
        guard let context = store.currentContext else { return "Unavailable" }
        if let title = context.windowTitle {
            return "\(context.foregroundApp) · \(title)"
        }
        if let url = context.browserURL {
            return "\(context.foregroundApp) · \(url)"
        }
        return context.foregroundApp
    }

    private var primaryButtonTitle: String {
        if manualFallbackActive {
            return "Done"
        }
        switch plan.template {
        case .closeTab:
            return "Close Tab"
        case .quitApp:
            return "Quit App"
        default:
            return plan.primaryActionTitle
        }
    }

    private var primaryButtonHelp: String {
        switch plan.template {
        case .closeTab:
            return "Close the active browser tab"
        case .quitApp:
            return "Quit the distracted app"
        default:
            return plan.fallbackInstruction
        }
    }

    private func performPrimaryAction() {
        guard isPerformingPrimaryAction == false else { return }
        if manualFallbackActive {
            store.dismissInterruption()
            return
        }

        switch plan.template {
        case .closeTab:
            let context = store.currentContext
            runAutomatedRecovery(
                failureMessage: "FocusGuard could not close the active browser tab automatically. Close it manually, then press Done."
            ) {
                await RecoveryActionExecutor.closeActiveBrowserTab(context: context)
            }
        case .quitApp:
            let context = store.currentContext
            runAutomatedRecovery(
                failureMessage: "FocusGuard could not quit the distracted app automatically. Quit it manually, then press Done."
            ) {
                await RecoveryActionExecutor.quitForegroundApplication(context: context)
            }
        case .restartTimer:
            store.restart(minutes: 10)
        case .blockDomain:
            let saved = store.blockCurrentContextForSession()
            if saved == false {
                actionMessage = "No current domain was available to block, so this interruption was dismissed."
                actionMessageIsError = false
            }
            store.dismissInterruption()
        default:
            store.dismissInterruption()
        }
    }

    private func runAutomatedRecovery(
        failureMessage: String,
        action: @escaping () async -> Bool
    ) {
        isPerformingPrimaryAction = true
        actionMessage = nil
        Task {
            let succeeded = await action()
            await MainActor.run {
                isPerformingPrimaryAction = false
                if succeeded {
                    store.dismissInterruption()
                } else {
                    manualFallbackActive = true
                    actionMessage = failureMessage
                    actionMessageIsError = true
                }
            }
        }
    }
}

private enum RecoveryActionExecutor {
    static func closeActiveBrowserTab(context: ContextSnapshot?) async -> Bool {
        guard let appName = browserApplicationName(from: context) else { return false }
        let script: String
        if appName == "Safari" {
            script = """
            tell application "Safari"
              if (count of windows) is 0 then return
              close current tab of front window
            end tell
            """
        } else {
            script = """
            tell application "\(appName)"
              if (count of windows) is 0 then return
              close active tab of front window
            end tell
            """
        }
        return await runAppleScript(script)
    }

    static func quitForegroundApplication(context: ContextSnapshot?) async -> Bool {
        guard let appName = context?.foregroundApp,
              appName.localizedCaseInsensitiveCompare("FocusGuard") != .orderedSame else {
            return false
        }
        return await runAppleScript("""
        tell application "\(escapedAppleScriptString(appName))" to quit
        """)
    }

    private static func browserApplicationName(from context: ContextSnapshot?) -> String? {
        guard let app = context?.foregroundApp.lowercased() else { return nil }
        if app.contains("safari") { return "Safari" }
        if app.contains("arc") { return "Arc" }
        if app.contains("brave") { return "Brave Browser" }
        if app.contains("chrome") { return "Google Chrome" }
        return nil
    }

    private static func runAppleScript(_ script: String) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            do {
                try process.run()
                let deadline = Date().addingTimeInterval(4)
                while process.isRunning && Date() < deadline {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                if process.isRunning {
                    process.terminate()
                    return false
                }
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }

    private static func escapedAppleScriptString(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}

private struct SectionBlock<Content: View>: View {
    let title: String
    let actionTitle: String?
    let systemImage: String
    let content: Content
    let action: (() -> Void)?

    init(
        title: String,
        actionTitle: String?,
        systemImage: String,
        @ViewBuilder content: () -> Content,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.systemImage = systemImage
        self.content = content()
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FGTheme.secondary)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(FGTheme.tertiary)
                Spacer()
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FGTheme.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FGTheme.elevated.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(FGTheme.stroke)
            )
        }
    }
}

private struct SignalRow: View {
    let systemImage: String
    let label: String
    let value: String
    var tint: Color = FGTheme.secondary

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FGTheme.tertiary)
                .frame(width: 68, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FGTheme.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct EmptyStateLine: View {
    let systemImage: String
    let text: String
    var tint: Color = FGTheme.secondary

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FGTheme.secondary)
        }
    }
}

private struct SetupRow: View {
    let item: SetupItem
    let openSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FGTheme.primary)
                        .lineLimit(1)
                    Text(item.status.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(tint)
                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FGTheme.tertiary)
                        .help(item.fix)
                    Spacer(minLength: 0)
                    if canRequestPermission {
                        Button {
                            openSettings()
                        } label: {
                            Text("Request")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(FGTheme.primary)
                        .background(FGTheme.elevatedStrong, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(FGTheme.stroke)
                        )
                        .help(item.fix)
                    }
                }
                Text(item.detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FGTheme.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var icon: String {
        switch item.status {
        case .ready: "checkmark.circle.fill"
        case .missing: "exclamationmark.circle.fill"
        case .degraded: "minus.circle.fill"
        }
    }

    private var tint: Color {
        switch item.status {
        case .ready: FGTheme.focus
        case .missing: FGTheme.warning
        case .degraded: FGTheme.amber
        }
    }

    private var canOpenSettings: Bool {
        item.status != .ready && (item.kind == .accessibility || item.kind == .screenRecording)
    }

    private var canRequestPermission: Bool {
        canOpenSettings
    }
}

private struct CommandButton: View {
    enum Role {
        case normal
        case destructive
    }

    let title: String
    let systemImage: String
    var role: Role = .normal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? FGTheme.warning : FGTheme.primary)
        .background(FGTheme.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FGTheme.stroke)
        )
    }
}

private struct InterruptionButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case destructive
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .font(.system(size: 12, weight: .semibold))
            .padding(.vertical, 10)
            .foregroundStyle(foregroundColor)
            .background(
                backgroundColor(isPressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(strokeColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary:
            Color.black.opacity(0.88)
        case .secondary:
            FGTheme.primary
        case .destructive:
            FGTheme.warning
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch kind {
        case .primary:
            FGTheme.primary.opacity(isPressed ? 0.78 : 0.94)
        case .secondary:
            FGTheme.elevatedStrong.opacity(isPressed ? 0.72 : 1)
        case .destructive:
            FGTheme.warning.opacity(isPressed ? 0.18 : 0.11)
        }
    }

    private var strokeColor: Color {
        switch kind {
        case .primary:
            Color.clear
        case .secondary:
            FGTheme.stroke
        case .destructive:
            FGTheme.warning.opacity(0.2)
        }
    }
}
