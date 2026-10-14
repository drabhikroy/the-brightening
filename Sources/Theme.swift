import AppKit

/// Colors for the popover. Each one resolves against the appearance it is
/// drawn in, so the panel follows light and dark mode without observers.
enum Theme {
    static let background = adaptive(light: rgb(247, 247, 243), dark: rgb(32, 33, 36))
    static let primaryText = adaptive(light: rgb(32, 33, 31), dark: rgb(242, 242, 239))
    static let secondaryText = adaptive(light: rgb(91, 94, 87), dark: rgb(186, 189, 182))

    // The light value is darker than it looks like it needs to be. Anything
    // brighter falls under 3 to 1 against the panel background, which is the
    // WCAG floor for the filled part of a control.
    static let sliderFill = adaptive(light: rgb(90, 145, 46), dark: rgb(131, 190, 70))

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
    }

    private static func adaptive(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            isDark(appearance) ? dark : light
        }
    }
}

/// Plain view that paints the theme background behind the popover controls.
final class PanelBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        Theme.background.setFill()
        bounds.fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
