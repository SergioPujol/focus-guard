import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(ApplicationServices)
import ApplicationServices
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public protocol ContextSampling: Sendable {
    func sample(captureState: CaptureState) async -> ContextSnapshot
}

public struct ContextSampler: ContextSampling, Sendable {
    public var commandRunner: CommandRunning

    public init(commandRunner: CommandRunning = ProcessCommandRunner()) {
        self.commandRunner = commandRunner
    }

    public func sample(captureState: CaptureState = .activeLocally) async -> ContextSnapshot {
        let app = Self.foregroundApplication()
        let idle = Self.idleSeconds()
        let windowTitle = Self.activeWindowTitle()
        let browser = await browserMetadata(appName: app.name)

        return ContextSnapshot(
            foregroundApp: app.name,
            bundleIdentifier: app.bundleIdentifier,
            windowTitle: windowTitle ?? browser.title,
            browserURL: browser.url,
            browserTitle: browser.title,
            idleSeconds: idle,
            captureState: captureState
        )
    }

    public static func foregroundApplication() -> (name: String, bundleIdentifier: String?) {
        #if canImport(AppKit)
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.localizedName ?? "Unknown", app?.bundleIdentifier)
        #else
        return ("Unknown", nil)
        #endif
    }

    public static func idleSeconds() -> TimeInterval {
        #if canImport(CoreGraphics)
        let keyboard = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let mouse = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        return min(keyboard, mouse)
        #else
        return 0
        #endif
    }

    public static func activeWindowTitle() -> String? {
        #if canImport(ApplicationServices)
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success,
              let focusedWindow,
              CFGetTypeID(focusedWindow) == AXUIElementGetTypeID() else {
            return nil
        }
        let window = focusedWindow as! AXUIElement

        var title: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
        guard titleResult == .success else { return nil }
        return title as? String
        #else
        return nil
        #endif
    }

    private func browserMetadata(appName: String) async -> (url: String?, title: String?) {
        let lower = appName.lowercased()
        if lower.contains("safari") {
            return await runAppleScript("""
            tell application "Safari"
              if (count of windows) is 0 then return ""
              set theURL to URL of current tab of front window
              set theTitle to name of current tab of front window
              return theURL & "\n" & theTitle
            end tell
            """)
        }
        if lower.contains("chrome") || lower.contains("arc") || lower.contains("brave") {
            let app = lower.contains("arc") ? "Arc" : (lower.contains("brave") ? "Brave Browser" : "Google Chrome")
            return await runAppleScript("""
            tell application "\(app)"
              if (count of windows) is 0 then return ""
              set theURL to URL of active tab of front window
              set theTitle to title of active tab of front window
              return theURL & "\n" & theTitle
            end tell
            """)
        }
        return (nil, nil)
    }

    private func runAppleScript(_ script: String) async -> (url: String?, title: String?) {
        do {
            let result = try await commandRunner.run("/usr/bin/osascript", arguments: ["-e", script], timeoutSeconds: 2)
            guard result.exitCode == 0 else { return (nil, nil) }
            let lines = result.standardOutput
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
            return (lines.first?.nilIfEmpty, lines.dropFirst().first?.nilIfEmpty)
        } catch {
            return (nil, nil)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
