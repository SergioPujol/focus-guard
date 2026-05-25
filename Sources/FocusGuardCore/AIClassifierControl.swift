import Foundation

public enum AIReasoningEffort: String, Codable, CaseIterable, Identifiable, Sendable, Equatable {
    case low
    case medium
    case high

    public var id: String { rawValue }

    public var displayText: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

public enum AICheckCadence: String, Codable, CaseIterable, Identifiable, Sendable, Equatable {
    case conservative
    case balanced
    case aggressive

    public var id: String { rawValue }

    public var displayText: String {
        switch self {
        case .conservative: "Conservative"
        case .balanced: "Balanced"
        case .aggressive: "Aggressive"
        }
    }

    public var changedContextMinimumInterval: TimeInterval {
        switch self {
        case .conservative: 60
        case .balanced: 20
        case .aggressive: 6
        }
    }

    public var unchangedContextReviewInterval: TimeInterval {
        switch self {
        case .conservative: 300
        case .balanced: 120
        case .aggressive: 30
        }
    }
}

public struct AIClassifierSettings: Codable, Sendable, Equatable {
    public var model: String
    public var reasoningEffort: AIReasoningEffort
    public var cadence: AICheckCadence

    public init(
        model: String = "gpt-5.3-codex",
        reasoningEffort: AIReasoningEffort = .low,
        cadence: AICheckCadence = .balanced
    ) {
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.cadence = cadence
    }

    public var normalizedModel: String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.default.model : trimmed
    }

    public static let `default` = AIClassifierSettings()
}

public protocol AIClassifierSettingsStoring: Sendable {
    func load() -> AIClassifierSettings
    func save(_ settings: AIClassifierSettings)
}

public struct UserDefaultsAIClassifierSettingsStore: AIClassifierSettingsStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "FocusGuard.AIClassifierSettings"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> AIClassifierSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AIClassifierSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(_ settings: AIClassifierSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}

public struct AIContextFingerprint: Sendable, Hashable, Equatable {
    public var promise: String
    public var app: String
    public var domain: String?
    public var title: String?
    public var idleBucket: String

    public init(promise: String, context: ContextSnapshot) {
        self.promise = Self.normalized(promise, maxLength: 96)
        self.app = Self.normalized(context.foregroundApp, maxLength: 80)
        self.domain = context.domain.map { Self.normalized($0, maxLength: 120) }
        self.title = (context.windowTitle ?? context.browserTitle).map { Self.normalized($0, maxLength: 120) }
        self.idleBucket = context.idleSeconds >= 30 ? "idle" : "active"
    }

    private static func normalized(_ value: String, maxLength: Int) -> String {
        let collapsed = value
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(maxLength))
    }
}

public struct AIClassifierUsageStats: Sendable, Equatable {
    public var aiChecks: Int
    public var reusedDecisions: Int
    public var localRuleDecisions: Int
    public var cooldownSkips: Int
    public var unavailableSkips: Int
    public var screenshotsSent: Int
    public var estimatedInputTokens: Int
    public var estimatedOutputTokens: Int
    public var estimatedCostUSD: Double

    public init(
        aiChecks: Int = 0,
        reusedDecisions: Int = 0,
        localRuleDecisions: Int = 0,
        cooldownSkips: Int = 0,
        unavailableSkips: Int = 0,
        screenshotsSent: Int = 0,
        estimatedInputTokens: Int = 0,
        estimatedOutputTokens: Int = 0,
        estimatedCostUSD: Double = 0
    ) {
        self.aiChecks = aiChecks
        self.reusedDecisions = reusedDecisions
        self.localRuleDecisions = localRuleDecisions
        self.cooldownSkips = cooldownSkips
        self.unavailableSkips = unavailableSkips
        self.screenshotsSent = screenshotsSent
        self.estimatedInputTokens = estimatedInputTokens
        self.estimatedOutputTokens = estimatedOutputTokens
        self.estimatedCostUSD = estimatedCostUSD
    }

    public mutating func recordAICheck(settings: AIClassifierSettings, screenshotSent: Bool) {
        aiChecks += 1
        if screenshotSent {
            screenshotsSent += 1
        }

        let inputTokens = screenshotSent ? 5_000 : 2_000
        let outputTokens = 500
        estimatedInputTokens += inputTokens
        estimatedOutputTokens += outputTokens
        estimatedCostUSD += Self.estimatedCost(
            model: settings.normalizedModel,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
    }

    public mutating func recordReuse() {
        reusedDecisions += 1
    }

    public mutating func recordLocalRuleDecision() {
        localRuleDecisions += 1
    }

    public mutating func recordCooldownSkip() {
        cooldownSkips += 1
    }

    public mutating func recordUnavailableSkip() {
        unavailableSkips += 1
    }

    public static func estimatedCost(model: String, inputTokens: Int, outputTokens: Int) -> Double {
        let pricing = pricingForModel(model)
        return (Double(inputTokens) / 1_000_000 * pricing.inputPerMillion)
            + (Double(outputTokens) / 1_000_000 * pricing.outputPerMillion)
    }

    private static func pricingForModel(_ model: String) -> (inputPerMillion: Double, outputPerMillion: Double) {
        let normalized = model.lowercased()
        if normalized.contains("gpt-5.4-nano") {
            return (0.20, 1.25)
        }
        if normalized.contains("gpt-5.3-codex") {
            return (1.75, 14.00)
        }
        if normalized.contains("gpt-5.5") {
            return (5.00, 30.00)
        }
        if normalized.contains("gpt-5.4-mini") {
            return (0.80, 5.00)
        }
        return (0.20, 1.25)
    }
}

public struct AIContextDecision: Sendable, Equatable {
    public var fingerprint: AIContextFingerprint
    public var result: ClassificationResult
    public var decidedAt: Date
    public var model: String

    public init(
        fingerprint: AIContextFingerprint,
        result: ClassificationResult,
        decidedAt: Date = Date(),
        model: String
    ) {
        self.fingerprint = fingerprint
        self.result = result
        self.decidedAt = decidedAt
        self.model = model
    }

    public func canReuse(
        for fingerprint: AIContextFingerprint,
        settings: AIClassifierSettings,
        now: Date = Date()
    ) -> Bool {
        self.fingerprint == fingerprint
            && model == settings.normalizedModel
            && result.status != .unknown
            && now.timeIntervalSince(decidedAt) < settings.cadence.unchangedContextReviewInterval
    }
}
