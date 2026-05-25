import AppKit
import SwiftUI

enum FocusGuardIcon {
    static func statusBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            drawTemplateMark(in: context, rect: CGRect(x: -1, y: -1, width: 20, height: 20))
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
        context.addPath(sliverMarkPath(in: rect))
        context.fillPath()
        context.restoreGState()
    }

    private static func drawApplicationIcon(in context: CGContext, rect: CGRect) {
        context.saveGState()
        let background = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(calibratedWhite: 0.99, alpha: 1).cgColor,
                NSColor(calibratedWhite: 0.90, alpha: 1).cgColor
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

        let markRect = rect.insetBy(dx: 30, dy: 24)
        context.setFillColor(NSColor(calibratedWhite: 0.05, alpha: 1).cgColor)
        context.addPath(sliverMarkPath(in: markRect))
        context.fillPath()

        context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.78).cgColor)
        context.setLineWidth(1)
        context.addPath(CGPath(
            roundedRect: rect.insetBy(dx: 7, dy: 7),
            cornerWidth: corner * 0.94,
            cornerHeight: corner * 0.94,
            transform: nil
        ))
        context.strokePath()

        context.setStrokeColor(NSColor(calibratedWhite: 0, alpha: 0.10).cgColor)
        context.setLineWidth(1)
        context.addPath(backgroundPath(in: rect.insetBy(dx: 6.5, dy: 6.5)))
        context.strokePath()
    }

    fileprivate static func sliverMarkPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()

        addSliver(
            to: path,
            in: rect,
            x: 0.10,
            width: 0.20,
            top: 0.72,
            bottom: 0.28,
            slant: 0.13
        )
        addSliver(
            to: path,
            in: rect,
            x: 0.40,
            width: 0.21,
            top: 0.92,
            bottom: 0.08,
            slant: 0.15
        )
        addSliver(
            to: path,
            in: rect,
            x: 0.70,
            width: 0.20,
            top: 0.76,
            bottom: 0.22,
            slant: 0.14
        )

        return path
    }

    private static func addSliver(
        to path: CGMutablePath,
        in rect: CGRect,
        x: CGFloat,
        width: CGFloat,
        top: CGFloat,
        bottom: CGFloat,
        slant: CGFloat
    ) {
        func point(_ px: CGFloat, _ py: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * px, y: rect.minY + rect.height * py)
        }

        path.move(to: point(x, bottom))
        path.addLine(to: point(x + width, bottom + slant))
        path.addLine(to: point(x + width, top))
        path.addLine(to: point(x, top - slant))
        path.closeSubpath()
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

    var body: some View {
        FocusGuardSliverMarkShape()
            .fill(baseColor)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct FocusGuardSliverMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(FocusGuardIcon.sliverMarkPath(in: rect))
    }
}
