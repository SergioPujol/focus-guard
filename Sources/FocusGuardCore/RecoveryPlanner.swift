import Foundation

public struct RecoveryPlan: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var template: RecoveryAction
    public var trigger: String
    public var primaryActionTitle: String
    public var correctionActionTitle: String
    public var fallbackInstruction: String
    public var undoTitle: String
    public var shouldInterrupt: Bool

    public init(
        id: UUID = UUID(),
        template: RecoveryAction,
        trigger: String,
        primaryActionTitle: String,
        correctionActionTitle: String,
        fallbackInstruction: String,
        undoTitle: String = "Undo correction",
        shouldInterrupt: Bool
    ) {
        self.id = id
        self.template = template
        self.trigger = trigger
        self.primaryActionTitle = primaryActionTitle
        self.correctionActionTitle = correctionActionTitle
        self.fallbackInstruction = fallbackInstruction
        self.undoTitle = undoTitle
        self.shouldInterrupt = shouldInterrupt
    }

    public static let none = RecoveryPlan(
        template: .none,
        trigger: "No recovery needed.",
        primaryActionTitle: "Continue",
        correctionActionTitle: "Allow This",
        fallbackInstruction: "No action is needed.",
        shouldInterrupt: false
    )
}

public struct RecoveryPlanner: Sendable {
    public init() {}

    public func plan(
        classification: ClassificationResult,
        context: ContextSnapshot,
        session: FocusSession
    ) -> RecoveryPlan {
        guard classification.status == .distracted, classification.interrupt else {
            if classification.status == .inactive {
                return RecoveryPlan(
                    template: .restartTimer,
                    trigger: "You have been inactive during this promise.",
                    primaryActionTitle: "Restart Timer",
                    correctionActionTitle: "Keep Running",
                    fallbackInstruction: "Restart the session when you are ready to continue.",
                    shouldInterrupt: false
                )
            }
            return .none
        }

        switch classification.recoveryAction {
        case .closeTab:
            return RecoveryPlan(
                template: .closeTab,
                trigger: classification.reason,
                primaryActionTitle: "Close Tab",
                correctionActionTitle: "Allow This",
                fallbackInstruction: "Close this browser tab manually, then return to \(session.promise).",
                shouldInterrupt: true
            )
        case .blockDomain:
            return RecoveryPlan(
                template: .blockDomain,
                trigger: classification.reason,
                primaryActionTitle: "Block for Session",
                correctionActionTitle: "Allow Domain",
                fallbackInstruction: "Add \(context.domain ?? "this domain") to session blocks, then return to \(session.promise).",
                shouldInterrupt: true
            )
        case .quitApp:
            return RecoveryPlan(
                template: .quitApp,
                trigger: classification.reason,
                primaryActionTitle: "Quit App",
                correctionActionTitle: "Allow App",
                fallbackInstruction: "Quit \(context.foregroundApp) manually, then return to \(session.promise).",
                shouldInterrupt: true
            )
        case .returnToApp:
            return RecoveryPlan(
                template: .returnToApp,
                trigger: classification.reason,
                primaryActionTitle: "Return to Promise",
                correctionActionTitle: "Allow Current Context",
                fallbackInstruction: "Switch back to \(session.lastFocusedApp ?? "your promise work") and continue.",
                shouldInterrupt: true
            )
        case .restartTimer:
            return RecoveryPlan(
                template: .restartTimer,
                trigger: classification.reason,
                primaryActionTitle: "Restart 10",
                correctionActionTitle: "Keep Current Timer",
                fallbackInstruction: "Start a fresh 10 minute recovery interval.",
                shouldInterrupt: true
            )
        case .none:
            return RecoveryPlan(
                template: .returnToApp,
                trigger: classification.reason,
                primaryActionTitle: "Return to Promise",
                correctionActionTitle: "Allow This",
                fallbackInstruction: "Return to \(session.promise).",
                shouldInterrupt: true
            )
        }
    }
}
