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
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FGTheme.primary)
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
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("SESSION LENGTH")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(FGTheme.tertiary)
                    Picker("Duration", selection: $store.durationMinutes) {
                        Text("10 min").tag(10)
                        Text("25 min").tag(25)
                        Text("45 min").tag(45)
                    }
                    .pickerStyle(.segmented)
                }

                Button {
                    store.startSession()
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

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            Color.black.opacity(0.38)

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FGTheme.warning)
                        .frame(width: 36, height: 36)
                        .background(FGTheme.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("DRIFT DETECTED")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(FGTheme.warning)
                        Text("Return to the promise")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(FGTheme.primary)
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("PROMISE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(FGTheme.tertiary)
                    Text(store.session?.promise ?? "Focus session")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FGTheme.primary)
                        .lineLimit(2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FGTheme.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(FGTheme.stroke)
                )

                VStack(alignment: .leading, spacing: 12) {
                    SignalRow(systemImage: "scope", label: "Current", value: contextText, tint: FGTheme.warning)
                    SignalRow(systemImage: "text.badge.checkmark", label: "Reason", value: plan.trigger)
                    SignalRow(systemImage: "arrow.turn.up.left", label: "Recovery", value: plan.fallbackInstruction)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        store.allowCurrentContext()
                    } label: {
                        Label(plan.correctionActionTitle, systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InterruptionButtonStyle(kind: .secondary))

                    Button {
                        store.endSession()
                    } label: {
                        Label("End", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InterruptionButtonStyle(kind: .secondary))

                    Button {
                        performPrimaryAction()
                    } label: {
                        Label(plan.primaryActionTitle, systemImage: "arrow.up.forward.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InterruptionButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
        .frame(width: 500, height: 420)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
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

    private func performPrimaryAction() {
        switch plan.template {
        case .restartTimer:
            store.restart(minutes: 10)
        case .blockDomain:
            store.blockCurrentContextForSession()
            store.dismissInterruption()
        default:
            store.dismissInterruption()
        }
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
                        Button("Request") {
                            openSettings()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(FGTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
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
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.vertical, 10)
            .foregroundStyle(kind == .primary ? Color.black.opacity(0.88) : FGTheme.primary)
            .background(
                kind == .primary
                    ? FGTheme.primary.opacity(configuration.isPressed ? 0.78 : 0.94)
                    : FGTheme.elevatedStrong.opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(kind == .primary ? Color.clear : FGTheme.stroke)
            )
    }
}
