import Foundation

public final class DiagnosticsStore: ObservableObject {
    @Published public private(set) var entries: [DiagnosticEntry] = []
    private let maxEntries: Int

    public init(maxEntries: Int = 80) {
        self.maxEntries = maxEntries
    }

    public func record(_ level: DiagnosticLevel, _ message: String) {
        entries.append(DiagnosticEntry(level: level, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
}
