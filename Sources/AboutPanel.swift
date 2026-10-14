import AppKit

/// The standard About window, filled in with the details every app in the
/// portfolio shows: what it is, its license, and where to get the latest
/// version.
enum AboutPanel {
    static let latestReleaseURL = URL(string: "https://github.com/drabhikroy/the-brightening/releases/latest")!
    static let licenseURL = URL(string: "https://polyformproject.org/licenses/noncommercial/1.0.0")!

    static func show() {
        let size: CGFloat = 11
        let plain: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size),
            .foregroundColor: NSColor.labelColor,
        ]

        // The panel reads the name, icon, version, and copyright from the app
        // bundle, so the numbers here can never disagree with Info.plist. Only
        // the credits, which carry the links, are written by hand.
        let credits = NSMutableAttributedString(
            string: "Raises the brightness of the built-in XDR display above its usual limit.\n\n",
            attributes: plain
        )

        credits.append(link("PolyForm Noncommercial License 1.0.0", to: licenseURL, size: size))
        credits.append(NSAttributedString(string: "\n", attributes: plain))
        credits.append(link("Latest version on GitHub", to: latestReleaseURL, size: size))

        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))

        // An empty build number keeps the panel to "Version 1.0.0" instead of
        // "Version 1.0.0 (1)", which would mean nothing to most people.
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits, .version: ""])

        // A menu bar app is never the active app on its own, and without this
        // the panel opens behind whatever window has focus.
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func link(_ text: String, to url: URL, size: CGFloat) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.link: url, .font: NSFont.systemFont(ofSize: size)])
    }
}
