import Foundation

public enum ClassifierStatus: String, Codable, CaseIterable, Sendable, Equatable {
    case focused
    case related
    case distracted
    case inactive
    case unknown
}

public enum RecoveryAction: String, Codable, CaseIterable, Sendable, Equatable {
    case none
    case closeTab = "close_tab"
    case blockDomain = "block_domain"
    case quitApp = "quit_app"
    case returnToApp = "return_to_app"
    case restartTimer = "restart_timer"
}

public enum CaptureState: String, Codable, CaseIterable, Sendable, Equatable {
    case inactive
    case activeLocally = "active_locally"
    case snapshotSelectedForCodex = "snapshot_selected_for_codex"
    case blockedByPermission = "blocked_by_permission"
    case sensitiveAppExcluded = "sensitive_app_excluded"
    case localRulesOnly = "local_rules_only"

    public var displayText: String {
        switch self {
        case .inactive: "Capture inactive"
        case .activeLocally: "Active locally"
        case .snapshotSelectedForCodex: "Snapshot selected for Codex"
        case .blockedByPermission: "Blocked by permission"
        case .sensitiveAppExcluded: "Sensitive app excluded"
        case .localRulesOnly: "Local rules only"
        }
    }
}

public struct ClassificationResult: Codable, Sendable, Equatable {
    public var status: ClassifierStatus
    public var confidence: Double
    public var reason: String
    public var recoveryAction: RecoveryAction
    public var interrupt: Bool

    public init(
        status: ClassifierStatus,
        confidence: Double,
        reason: String,
        recoveryAction: RecoveryAction,
        interrupt: Bool
    ) {
        self.status = status
        self.confidence = confidence
        self.reason = reason
        self.recoveryAction = recoveryAction
        self.interrupt = interrupt
    }

    public static let unknown = ClassificationResult(
        status: .unknown,
        confidence: 0,
        reason: "Classifier did not return a usable decision.",
        recoveryAction: .none,
        interrupt: false
    )
}

public struct ContextSnapshot: Codable, Sendable, Equatable {
    public var sampledAt: Date
    public var foregroundApp: String
    public var bundleIdentifier: String?
    public var windowTitle: String?
    public var browserURL: String?
    public var browserTitle: String?
    public var idleSeconds: TimeInterval
    public var captureState: CaptureState

    public init(
        sampledAt: Date = Date(),
        foregroundApp: String,
        bundleIdentifier: String? = nil,
        windowTitle: String? = nil,
        browserURL: String? = nil,
        browserTitle: String? = nil,
        idleSeconds: TimeInterval,
        captureState: CaptureState
    ) {
        self.sampledAt = sampledAt
        self.foregroundApp = foregroundApp
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
        self.browserURL = browserURL
        self.browserTitle = browserTitle
        self.idleSeconds = idleSeconds
        self.captureState = captureState
    }

    public var domain: String? {
        guard let browserURL, let host = URL(string: browserURL)?.host(percentEncoded: false) else {
            return nil
        }
        return host.replacing(/^www\./, with: "")
    }
}

public struct FocusSession: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var promise: String
    public var startedAt: Date
    public var durationSeconds: TimeInterval
    public var lastFocusedApp: String?

    public init(
        id: UUID = UUID(),
        promise: String,
        startedAt: Date = Date(),
        durationSeconds: TimeInterval = 25 * 60,
        lastFocusedApp: String? = nil
    ) {
        self.id = id
        self.promise = promise
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.lastFocusedApp = lastFocusedApp
    }

    public func remainingSeconds(now: Date = Date()) -> TimeInterval {
        max(0, durationSeconds - now.timeIntervalSince(startedAt))
    }

    public func isDone(now: Date = Date()) -> Bool {
        remainingSeconds(now: now) <= 0
    }
}

public enum DiagnosticLevel: String, Codable, Sendable, Equatable {
    case info
    case warning
    case error
}

public struct DiagnosticEntry: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var createdAt: Date
    public var level: DiagnosticLevel
    public var message: String

    public init(id: UUID = UUID(), createdAt: Date = Date(), level: DiagnosticLevel, message: String) {
        self.id = id
        self.createdAt = createdAt
        self.level = level
        self.message = message
    }
}
