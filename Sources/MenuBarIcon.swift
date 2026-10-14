import AppKit

/// The status item image: the app icon reduced to a one color template.
///
/// The geometry matches MENU in Scripts/make_icons.py, which writes the same
/// shape to Assets/MenuBarIcon.svg for reference. Change both together.
enum MenuBarIcon {
    private static let sunCenter = NSPoint(x: 9, y: 9.5)
    private static let sunRadius: CGFloat = 3.6
    private static let rayInner: CGFloat = 5.0
    private static let rayOuter: CGFloat = 7.2
    private static let rayWidth: CGFloat = 1.3
    private static let rayAngles: [CGFloat] = [205, 237.5, 270, 302.5, 335]
    private static let bezel = NSRect(x: 2.5, y: 9.5, width: 13, height: 6.5)
    private static let bezelRadius: CGFloat = 1.5
    private static let bezelWidth: CGFloat = 1.5

    static func make() -> NSImage {
        // Drawn flipped, so y grows downward and the numbers above read the
        // same as the SVG they came from.
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { bounds in
            // Template images only use alpha, so black is a stand-in. macOS
            // recolors it to suit the menu bar, light or dark.
            NSColor.black.set()

            let rays = NSBezierPath()
            for degrees in rayAngles {
                let angle = degrees * .pi / 180
                rays.move(to: point(at: angle, distance: rayInner))
                rays.line(to: point(at: angle, distance: rayOuter))
            }
            rays.lineWidth = rayWidth
            rays.lineCapStyle = .round
            rays.stroke()

            let sun = NSBezierPath(ovalIn: NSRect(
                x: sunCenter.x - sunRadius,
                y: sunCenter.y - sunRadius,
                width: sunRadius * 2,
                height: sunRadius * 2
            ))

            // The sun is split by the bezel the same way the app icon is. The
            // half above it is solid and the half inside the screen is faded,
            // since a template image has no gold to tell them apart.
            let edge = bezelWidth / 2
            fill(sun, clippedTo: NSRect(x: 0, y: 0, width: bounds.width, height: bezel.minY - edge))
            fill(sun, clippedTo: NSRect(x: 0, y: bezel.minY + edge, width: bounds.width, height: bounds.height), alpha: 0.45)

            let frame = NSBezierPath(roundedRect: bezel, xRadius: bezelRadius, yRadius: bezelRadius)
            frame.lineWidth = bezelWidth
            frame.stroke()

            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = "The Brightening"
        return image
    }

    private static func point(at angle: CGFloat, distance: CGFloat) -> NSPoint {
        NSPoint(x: sunCenter.x + distance * cos(angle), y: sunCenter.y + distance * sin(angle))
    }

    private static func fill(_ path: NSBezierPath, clippedTo clip: NSRect, alpha: CGFloat = 1) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: clip).addClip()
        NSColor.black.withAlphaComponent(alpha).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}
