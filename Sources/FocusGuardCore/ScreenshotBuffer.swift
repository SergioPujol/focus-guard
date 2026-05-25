import Foundation

public struct ScreenshotFrame: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var capturedAt: Date
    public var bytes: Data
    public var width: Int
    public var height: Int
    public var context: ContextSnapshot

    public init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        bytes: Data,
        width: Int,
        height: Int,
        context: ContextSnapshot
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.bytes = bytes
        self.width = width
        self.height = height
        self.context = context
    }

    public var byteCount: Int { bytes.count }
}

public final class ScreenshotBuffer: ObservableObject {
    @Published public private(set) var frames: [ScreenshotFrame] = []
    public let maxFrames: Int
    public let maxBytes: Int
    public var sensitiveApps: Set<String>
    public var sensitiveDomains: Set<String>

    public init(
        maxFrames: Int = 8,
        maxBytes: Int = 12 * 1024 * 1024,
        sensitiveApps: Set<String> = [
            "1Password",
            "Bitwarden",
            "Dashlane",
            "Keeper",
            "KeePassXC",
            "Keychain Access",
            "LastPass",
            "Proton Pass",
            "System Settings"
        ],
        sensitiveDomains: Set<String> = [
            "1password.com",
            "account.apple.com",
            "accounts.google.com",
            "appleid.apple.com",
            "bitwarden.com",
            "dashlane.com",
            "keepersecurity.com",
            "lastpass.com",
            "login.microsoftonline.com"
        ]
    ) {
        self.maxFrames = max(1, maxFrames)
        self.maxBytes = max(1, maxBytes)
        self.sensitiveApps = sensitiveApps
        self.sensitiveDomains = sensitiveDomains
    }

    public var totalBytes: Int {
        frames.reduce(0) { $0 + $1.byteCount }
    }

    public func canCapture(context: ContextSnapshot) -> Bool {
        if sensitiveApps.contains(where: { context.foregroundApp.localizedCaseInsensitiveContains($0) }) {
            return false
        }
        if let domain = context.domain,
           sensitiveDomains.contains(where: { domain.localizedCaseInsensitiveContains($0) }) {
            return false
        }
        return true
    }

    public func append(_ frame: ScreenshotFrame) {
        guard canCapture(context: frame.context) else { return }
        frames.append(frame)
        enforceLimits()
    }

    public func clear() {
        frames.removeAll(keepingCapacity: false)
    }

    private func enforceLimits() {
        while frames.count > maxFrames {
            frames.removeFirst()
        }
        while totalBytes > maxBytes, frames.count > 1 {
            frames.removeFirst()
        }
        if totalBytes > maxBytes, let last = frames.last {
            frames = [last]
        }
    }
}
