import Foundation

public enum RuleDecision: Equatable, Sendable {
    case allow(String)
    case block(String, RecoveryAction)
    case conflict(String)
    case noDecision

    public var isTerminal: Bool {
        switch self {
        case .allow, .block, .conflict: true
        case .noDecision: false
        }
    }
}

public enum RuleKind: String, Codable, Sendable, Equatable {
    case allow
    case block
}

public enum RuleScope: Int, Codable, Sendable, Equatable, Comparable {
    case defaultRules = 0
    case global = 1
    case promise = 2
    case session = 3

    public static func < (lhs: RuleScope, rhs: RuleScope) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum RuleTarget: Codable, Sendable, Equatable {
    case app(String)
    case domain(String)
    case titleContains(String)

    public func matches(_ context: ContextSnapshot) -> Bool {
        switch self {
        case .app(let app):
            return context.foregroundApp.localizedCaseInsensitiveContains(app)
                || context.bundleIdentifier?.localizedCaseInsensitiveContains(app) == true
        case .domain(let domain):
            guard let contextDomain = context.domain else { return false }
            return Self.domain(contextDomain, matches: domain)
        case .titleContains(let text):
            return context.windowTitle?.localizedCaseInsensitiveContains(text) == true
                || context.browserTitle?.localizedCaseInsensitiveContains(text) == true
        }
    }

    private static func domain(_ candidate: String, matches rule: String) -> Bool {
        let candidate = normalizedDomain(candidate)
        let rule = normalizedDomain(rule)
        guard candidate.isEmpty == false, rule.isEmpty == false else { return false }
        return candidate == rule || candidate.hasSuffix(".\(rule)")
    }

    private static func normalizedDomain(_ value: String) -> String {
        let host = URL(string: value)?.host(percentEncoded: false) ?? value
        return host
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .replacing(/^www\./, with: "")
    }

    public var label: String {
        switch self {
        case .app(let app): app
        case .domain(let domain): domain
        case .titleContains(let text): text
        }
    }

    fileprivate var isPageSpecific: Bool {
        switch self {
        case .domain, .titleContains: true
        case .app: false
        }
    }
}

public struct FocusRule: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var kind: RuleKind
    public var scope: RuleScope
    public var target: RuleTarget
    public var promiseContains: String?
    public var reason: String
    public var recoveryAction: RecoveryAction

    public init(
        id: UUID = UUID(),
        kind: RuleKind,
        scope: RuleScope,
        target: RuleTarget,
        promiseContains: String? = nil,
        reason: String,
        recoveryAction: RecoveryAction = .none
    ) {
        self.id = id
        self.kind = kind
        self.scope = scope
        self.target = target
        self.promiseContains = promiseContains
        self.reason = reason
        self.recoveryAction = recoveryAction
    }

    public func applies(to context: ContextSnapshot, promise: String) -> Bool {
        if let promiseContains,
           promise.localizedCaseInsensitiveContains(promiseContains) == false {
            return false
        }
        return target.matches(context)
    }
}

public protocol RuleStore {
    var rules: [FocusRule] { get }
    func save(_ rule: FocusRule) throws
    func remove(_ ruleID: UUID) throws
}

public final class LocalRuleStore: ObservableObject, RuleStore {
    @Published public private(set) var rules: [FocusRule]
    private let storageURL: URL?
    private static let directoryPermissions = 0o700
    private static let filePermissions = 0o600

    public static var defaultStorageURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/FocusGuard/rules.json")
    }

    public init(rules: [FocusRule] = FocusGuardDefaults.rules, storageURL: URL? = nil) {
        self.rules = rules
        self.storageURL = storageURL
        if let storageURL,
           let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode([FocusRule].self, from: data) {
            self.rules = decoded
        }
        if let storageURL {
            try? Self.hardenStoragePermissions(for: storageURL)
        }
    }

    public func save(_ rule: FocusRule) throws {
        rules.removeAll { $0.id == rule.id }
        rules.append(rule)
        try persist()
    }

    public func remove(_ ruleID: UUID) throws {
        rules.removeAll { $0.id == ruleID }
        try persist()
    }

    private func persist() throws {
        guard let storageURL else { return }
        let data = try JSONEncoder().encode(rules)
        let directoryURL = storageURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: Self.directoryPermissions]
        )
        try data.write(to: storageURL, options: [.atomic])
        try Self.hardenStoragePermissions(for: storageURL)
    }

    private static func hardenStoragePermissions(for storageURL: URL) throws {
        let fileManager = FileManager.default
        let directoryURL = storageURL.deletingLastPathComponent()
        if fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.setAttributes([.posixPermissions: directoryPermissions], ofItemAtPath: directoryURL.path)
        }
        if fileManager.fileExists(atPath: storageURL.path) {
            try fileManager.setAttributes([.posixPermissions: filePermissions], ofItemAtPath: storageURL.path)
        }
    }
}

public enum FocusGuardDefaults {
    public static let rules: [FocusRule] = [
        FocusRule(kind: .block, scope: .defaultRules, target: .domain("x.com"), reason: "X is a default distraction.", recoveryAction: .closeTab),
        FocusRule(kind: .block, scope: .defaultRules, target: .domain("twitter.com"), reason: "Twitter/X is a default distraction.", recoveryAction: .closeTab),
        FocusRule(kind: .block, scope: .defaultRules, target: .domain("youtube.com"), reason: "YouTube is a default distraction unless allowed for this promise.", recoveryAction: .closeTab),
        FocusRule(kind: .block, scope: .defaultRules, target: .domain("reddit.com"), reason: "Reddit is a default distraction.", recoveryAction: .closeTab),
        FocusRule(kind: .block, scope: .defaultRules, target: .domain("netflix.com"), reason: "Netflix is a default distraction.", recoveryAction: .closeTab),
        FocusRule(kind: .block, scope: .defaultRules, target: .domain("instagram.com"), reason: "Instagram is a default distraction.", recoveryAction: .closeTab),
        FocusRule(kind: .block, scope: .defaultRules, target: .domain("tiktok.com"), reason: "TikTok is a default distraction.", recoveryAction: .closeTab)
    ]
}

public struct RuleEngine: Sendable {
    public init() {}

    public func decide(context: ContextSnapshot, promise: String, rules: [FocusRule]) -> RuleDecision {
        let matching = rules.filter { $0.applies(to: context, promise: promise) }
        guard matching.isEmpty == false else { return .noDecision }

        let pageSpecific = matching.filter { $0.target.isPageSpecific }
        if pageSpecific.isEmpty == false {
            return decideMatching(context: context, rules: pageSpecific)
        }

        if Self.isBrowser(context),
           matching.contains(where: { $0.kind == .allow && $0.target.isPageSpecific == false }) {
            return .noDecision
        }

        return decideMatching(context: context, rules: matching)
    }

    private func decideMatching(context: ContextSnapshot, rules matching: [FocusRule]) -> RuleDecision {
        for scope in [RuleScope.session, .promise, .global, .defaultRules] {
            let scoped = matching.filter { $0.scope == scope }
            guard scoped.isEmpty == false else { continue }

            if scope == .session {
                if let allow = scoped.first(where: { $0.kind == .allow }) {
                    return .allow(allow.reason)
                }
                if let block = scoped.first(where: { $0.kind == .block }) {
                    return .block(block.reason, block.recoveryAction)
                }
            }

            let hasAllow = scoped.contains { $0.kind == .allow }
            let hasBlock = scoped.contains { $0.kind == .block }
            if hasAllow && hasBlock {
                return .conflict("Allow and block rules both matched \(context.foregroundApp).")
            }
            if let allow = scoped.first(where: { $0.kind == .allow }) {
                return .allow(allow.reason)
            }
            if let block = scoped.first(where: { $0.kind == .block }) {
                return .block(block.reason, block.recoveryAction)
            }
        }

        return .noDecision
    }

    private static func isBrowser(_ context: ContextSnapshot) -> Bool {
        let app = context.foregroundApp.lowercased()
        let bundle = context.bundleIdentifier?.lowercased() ?? ""
        return app.contains("safari")
            || app.contains("chrome")
            || app.contains("arc")
            || app.contains("brave")
            || bundle.contains("safari")
            || bundle.contains("chrome")
            || bundle.contains("thebrowser")
            || bundle.contains("brave")
    }
}
