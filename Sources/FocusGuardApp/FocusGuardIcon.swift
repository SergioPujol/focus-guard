import AppKit
import SwiftUI

enum FocusGuardIcon {
    static func statusBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            drawTemplateMark(in: context, rect: CGRect(x: 1, y: 1, width: 16, height: 16))
        }
        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "FocusGuard"
        return image
    }

    static func applicationIconImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 128, height: 128))
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            drawApplicationIcon(in: context, rect: CGRect(x: 0, y: 0, width: 128, height: 128))
        }
        image.unlockFocus()
        return image
    }

    private static func drawTemplateMark(in context: CGContext, rect: CGRect) {
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: -rect.midX, y: -rect.midY)

        context.setFillColor(NSColor.black.cgColor)
        context.addPath(shellPath(in: rect))
        context.fillPath()

        context.setBlendMode(.clear)
        context.addPath(aperturePath(in: rect.insetBy(dx: rect.width * 0.19, dy: rect.height * 0.19)))
        context.fillPath()
        context.restoreGState()

        context.setFillColor(NSColor.black.cgColor)
        let dot = rect.width * 0.17
        context.fillEllipse(in: CGRect(
            x: rect.midX + rect.width * 0.06,
            y: rect.midY - dot * 0.52,
            width: dot,
            height: dot
        ))
    }

    private static func drawApplicationIcon(in context: CGContext, rect: CGRect) {
        context.saveGState()
        let background = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.11, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.01, green: 0.012, blue: 0.014, alpha: 1).cgColor
            ] as CFArray,
            locations: [0, 1]
        )
        let corner = rect.width * 0.22
        let roundedBackground = CGPath(roundedRect: rect.insetBy(dx: 6, dy: 6), cornerWidth: corner, cornerHeight: corner, transform: nil)
        context.addPath(roundedBackground)
        context.clip()
        if let background {
            context.drawLinearGradient(
                background,
                start: CGPoint(x: rect.minX, y: rect.maxY),
                end: CGPoint(x: rect.maxX, y: rect.minY),
                options: []
            )
        }
        context.restoreGState()

        let markRect = rect.insetBy(dx: 26, dy: 22)
        context.setFillColor(NSColor(calibratedWhite: 0.96, alpha: 1).cgColor)
        context.addPath(shellPath(in: markRect))
        context.fillPath()

        context.saveGState()
        context.setBlendMode(.clear)
        context.addPath(aperturePath(in: markRect.insetBy(dx: markRect.width * 0.19, dy: markRect.height * 0.19)))
        context.fillPath()
        context.restoreGState()

        let dot = markRect.width * 0.18
        context.setFillColor(NSColor(calibratedRed: 0.48, green: 0.94, blue: 0.62, alpha: 1).cgColor)
        context.fillEllipse(in: CGRect(
            x: markRect.midX + markRect.width * 0.06,
            y: markRect.midY - dot * 0.52,
            width: dot,
            height: dot
        ))

        context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.16).cgColor)
        context.setLineWidth(1)
        context.addPath(backgroundPath(in: rect.insetBy(dx: 6.5, dy: 6.5)))
        context.strokePath()
    }

    fileprivate static func shellPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        path.move(to: point(0.50, 0.04))
        path.addCurve(to: point(0.88, 0.20), control1: point(0.64, 0.06), control2: point(0.80, 0.10))
        path.addCurve(to: point(0.86, 0.49), control1: point(0.89, 0.29), control2: point(0.89, 0.39))
        path.addCurve(to: point(0.50, 0.94), control1: point(0.81, 0.70), control2: point(0.66, 0.86))
        path.addCurve(to: point(0.14, 0.49), control1: point(0.34, 0.86), control2: point(0.19, 0.70))
        path.addCurve(to: point(0.12, 0.20), control1: point(0.11, 0.39), control2: point(0.11, 0.29))
        path.addCurve(to: point(0.50, 0.04), control1: point(0.20, 0.10), control2: point(0.36, 0.06))
        path.closeSubpath()
        return path
    }

    fileprivate static func aperturePath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        path.move(to: point(0.11, 0.53))
        path.addCurve(to: point(0.57, 0.13), control1: point(0.24, 0.41), control2: point(0.39, 0.27))
        path.addLine(to: point(0.90, 0.31))
        path.addCurve(to: point(0.43, 0.71), control1: point(0.76, 0.42), control2: point(0.60, 0.56))
        path.closeSubpath()
        return path
    }

    private static func backgroundPath(in rect: CGRect) -> CGPath {
        CGPath(
            roundedRect: rect,
            cornerWidth: rect.width * 0.22,
            cornerHeight: rect.height * 0.22,
            transform: nil
        )
    }
}

struct FocusGuardMark: View {
    let size: CGFloat
    var baseColor: Color = Color.white.opacity(0.94)
    var cutoutColor: Color = Color.black.opacity(0.68)
    var accentColor: Color = Color(red: 0.48, green: 0.94, blue: 0.62)

    var body: some View {
        ZStack {
            FocusGuardShellShape()
                .fill(baseColor)
            FocusGuardApertureShape()
                .fill(cutoutColor)
                .frame(width: size * 0.62, height: size * 0.62)
            Circle()
                .fill(accentColor)
                .frame(width: size * 0.17, height: size * 0.17)
                .offset(x: size * 0.14, y: size * 0.02)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct FocusGuardShellShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(FocusGuardIcon.shellPath(in: rect))
    }
}

private struct FocusGuardApertureShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(FocusGuardIcon.aperturePath(in: rect))
    }
}
