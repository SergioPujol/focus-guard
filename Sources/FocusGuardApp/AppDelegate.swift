import AppKit
import Combine
import FocusGuardCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusBarController?
    private var interruptionPresenter: InterruptionPresenter?
    private let store = SessionStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = FocusGuardIcon.applicationIconImage()
        statusController = StatusBarController(store: store)
        interruptionPresenter = InterruptionPresenter(store: store)
        store.refreshSetup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.endSession()
    }
}

@MainActor
final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let store: SessionStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: SessionStore) {
        self.store = store
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 430, height: 560)
        popover.contentViewController = NSHostingController(rootView: FocusGuardPopoverView(store: store))

        if let button = statusItem.button {
            button.image = FocusGuardIcon.statusBarImage()
            button.imagePosition = .imageOnly
            button.title = ""
            button.target = self
            button.action = #selector(togglePopover)
        }
        statusItem.length = NSStatusItem.squareLength

        store.$session.combineLatest(store.$remainingSeconds)
            .receive(on: RunLoop.main)
            .sink { [weak self] session, remaining in
                self?.updateTitle(session: session, remaining: remaining)
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.isOpaque = false
            popover.contentViewController?.view.window?.backgroundColor = .clear
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateTitle(session: FocusSession?, remaining: TimeInterval) {
        guard let session else {
            statusItem.length = NSStatusItem.squareLength
            statusItem.button?.imagePosition = .imageOnly
            statusItem.button?.title = ""
            return
        }
        statusItem.length = 190
        statusItem.button?.imagePosition = .imageLeading
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        let promise = session.promise.count > 16 ? "\(session.promise.prefix(16))..." : session.promise
        statusItem.button?.title = "  \(String(format: "%02d:%02d", minutes, seconds)) · \(promise)"
    }
}

@MainActor
final class InterruptionPresenter: NSObject, NSWindowDelegate {
    private let store: SessionStore
    private var cancellables: Set<AnyCancellable> = []
    private var window: NSWindow?

    init(store: SessionStore) {
        self.store = store
        super.init()
        store.$activeRecoveryPlan
            .receive(on: RunLoop.main)
            .sink { [weak self] plan in
                self?.update(plan: plan)
            }
            .store(in: &cancellables)
    }

    private func update(plan: RecoveryPlan?) {
        guard let plan, plan.shouldInterrupt else {
            closeInterruptionWindow()
            return
        }

        let controller = FirstMouseHostingController(rootView: InterruptionView(store: store, plan: plan))
        if let window {
            window.contentViewController = controller
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let newWindow = FocusInterruptionPanel(
            contentRect: NSRect(x: 0, y: 0, width: InterruptionPanelMetrics.width, height: InterruptionPanelMetrics.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        newWindow.contentViewController = controller
        newWindow.delegate = self
        newWindow.level = .floating
        newWindow.isReleasedWhenClosed = false
        newWindow.isMovableByWindowBackground = true
        newWindow.hasShadow = true
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.setContentSize(InterruptionPanelMetrics.size)
        newWindow.center()
        window = newWindow
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        store.dismissInterruption()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        window = nil
        if store.activeRecoveryPlan?.shouldInterrupt == true {
            store.dismissInterruption()
        }
    }

    private func closeInterruptionWindow() {
        window?.delegate = nil
        window?.close()
        window = nil
    }
}

private final class FocusInterruptionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class FirstMouseHostingController<Content: View>: NSHostingController<Content> {
    override func loadView() {
        view = FirstMouseHostingView(rootView: rootView)
    }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
