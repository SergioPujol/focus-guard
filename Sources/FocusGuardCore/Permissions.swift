import Foundation
#if canImport(ApplicationServices)
import ApplicationServices
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public enum SetupItemKind: String, Sendable, Equatable {
    case accessibility
    case screenRecording
    case codex
}

public enum SetupStatus: String, Sendable, Equatable {
    case ready
    case missing
    case degraded
}

public struct SetupItem: Identifiable, Sendable, Equatable {
    public var id: SetupItemKind { kind }
    public var kind: SetupItemKind
    public var title: String
    public var status: SetupStatus
    public var detail: String
    public var fix: String

    public init(kind: SetupItemKind, title: String, status: SetupStatus, detail: String, fix: String) {
        self.kind = kind
        self.title = title
        self.status = status
        self.detail = detail
        self.fix = fix
    }
}

public struct PermissionSnapshot: Sendable, Equatable {
    public var accessibilityGranted: Bool
    public var screenRecordingGranted: Bool
    public var codexReady: Bool
    public var codexVersion: String?
    public var codexError: String?

    public init(
        accessibilityGranted: Bool,
        screenRecordingGranted: Bool,
        codexReady: Bool,
        codexVersion: String? = nil,
        codexError: String? = nil
    ) {
        self.accessibilityGranted = accessibilityGranted
        self.screenRecordingGranted = screenRecordingGranted
        self.codexReady = codexReady
        self.codexVersion = codexVersion
        self.codexError = codexError
    }

    public var isReady: Bool {
        accessibilityGranted && screenRecordingGranted && codexReady
    }

    public var setupItems: [SetupItem] {
        PermissionManager.map(snapshot: self)
    }
}

public struct PermissionManager: Sendable {
    private var classifier: CodexCliClassifier

    public init(classifier: CodexCliClassifier = CodexCliClassifier()) {
        self.classifier = classifier
    }

    public func snapshot(classifierSettings: AIClassifierSettings = .default) async -> PermissionSnapshot {
        let codex = await classifier.preflight(settings: classifierSettings)
        return PermissionSnapshot(
            accessibilityGranted: Self.checkAccessibility(),
            screenRecordingGranted: Self.checkScreenRecording(),
            codexReady: codex.authUsable && codex.testPromptSucceeded,
            codexVersion: codex.version,
            codexError: codex.lastError
        )
    }

    public static func checkAccessibility() -> Bool {
        #if canImport(ApplicationServices)
        AXIsProcessTrusted()
        #else
        false
        #endif
    }

    public static func checkScreenRecording() -> Bool {
        #if canImport(CoreGraphics)
        CGPreflightScreenCaptureAccess()
        #else
        false
        #endif
    }

    public static func map(snapshot: PermissionSnapshot) -> [SetupItem] {
        [
            SetupItem(
                kind: .accessibility,
                title: "Accessibility",
                status: snapshot.accessibilityGranted ? .ready : .missing,
                detail: snapshot.accessibilityGranted
                    ? "FocusGuard can read active window metadata."
                    : "Accessibility is off. FocusGuard cannot read active window titles.",
                fix: "Open System Settings -> Privacy & Security -> Accessibility, enable FocusGuard, then click Test Again."
            ),
            SetupItem(
                kind: .screenRecording,
                title: "Screen Recording",
                status: snapshot.screenRecordingGranted ? .ready : .missing,
                detail: snapshot.screenRecordingGranted
                    ? "FocusGuard can inspect the work surface when screenshots are enabled."
                    : "Screen Recording is off. FocusGuard cannot inspect your work surface.",
                fix: "Open System Settings -> Privacy & Security -> Screen & System Audio Recording, enable FocusGuard, then click Test Again."
            ),
            SetupItem(
                kind: .codex,
                title: "Codex CLI",
                status: snapshot.codexReady ? .ready : .missing,
                detail: snapshot.codexReady
                    ? "Codex is ready. \(snapshot.codexVersion ?? "")"
                    : "Codex is not ready. FocusGuard uses your local Codex CLI for classification.",
                fix: snapshot.codexError ?? "Install or log in to Codex, then click Test Again."
            )
        ]
    }
}
