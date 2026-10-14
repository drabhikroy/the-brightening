import AppKit

/// The popover that opens from the menu bar icon. It only reports what the
/// user changed. AppDelegate owns the state and decides what happens.
final class PanelViewController: NSViewController {
    // The layout below uses fixed frames sized to this. The popover never
    // resizes, so Auto Layout would add constraints without buying anything.
    static let size = NSSize(width: 260, height: 144)

    var onBoostChange: ((Bool) -> Void)?
    var onLevelChange: ((Int) -> Void)?
    var onLaunchAtLoginChange: ((Bool) -> Void)?
    var onAbout: (() -> Void)?
    var onQuit: (() -> Void)?

    private let powerButton = PowerButton(frame: NSRect(x: 16, y: 104, width: 28, height: 28))
    private let levelValue = NSTextField(labelWithString: "")
    private let levelSlider = NSSlider(
        value: Double(AppDelegate.defaultLevel),
        minValue: Double(AppDelegate.levelRange.lowerBound),
        maxValue: Double(AppDelegate.levelRange.upperBound),
        target: nil,
        action: nil
    )
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)

    override func loadView() {
        let panel = PanelBackgroundView(frame: NSRect(origin: .zero, size: Self.size))

        powerButton.target = self
        powerButton.action = #selector(powerChanged)
        powerButton.toolTip = "Turn The Brightening on or off"

        let levelTitle = NSTextField(labelWithString: "Level")
        levelTitle.frame = NSRect(x: 16, y: 69, width: 80, height: 18)
        levelTitle.font = .systemFont(ofSize: 13, weight: .medium)
        levelTitle.textColor = Theme.primaryText

        // Set flush right so the percentage sits over the end of the slider
        // track no matter how many digits it has.
        levelValue.frame = NSRect(x: 188, y: 69, width: 55, height: 18)
        levelValue.alignment = .right
        levelValue.font = .systemFont(ofSize: 13, weight: .medium)

        levelSlider.frame = NSRect(x: 16, y: 40, width: 228, height: 24)
        levelSlider.target = self
        levelSlider.action = #selector(levelChanged)
        // Continuous, so the screen follows the knob while it is dragged
        // rather than jumping once on release.
        levelSlider.isContinuous = true
        levelSlider.trackFillColor = Theme.sliderFill
        // The visible "Level" text is a separate label, so the slider needs
        // its own name for VoiceOver.
        levelSlider.setAccessibilityLabel("Level")

        // The checkbox carries its own title so that clicking the words
        // toggles it and VoiceOver reads a name. A separate label did neither.
        // Kept narrow so it does not run under the About button on its right.
        launchAtLoginButton.frame = NSRect(x: 16, y: 11, width: 140, height: 18)
        launchAtLoginButton.controlSize = .small
        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(launchAtLoginChanged)
        styleLaunchAtLoginTitle(available: true)

        let aboutButton = NSButton(title: "About", target: self, action: #selector(aboutPressed))
        aboutButton.frame = NSRect(x: 190, y: 8, width: 54, height: 24)
        aboutButton.bezelStyle = .rounded
        aboutButton.controlSize = .small
        aboutButton.font = .systemFont(ofSize: 11, weight: .medium)
        aboutButton.contentTintColor = Theme.secondaryText

        let quitButton = NSButton(title: "Quit", target: self, action: #selector(quitPressed))
        quitButton.frame = NSRect(x: 202, y: 106, width: 42, height: 24)
        quitButton.bezelStyle = .rounded
        quitButton.controlSize = .small
        quitButton.font = .systemFont(ofSize: 11, weight: .medium)
        quitButton.contentTintColor = Theme.secondaryText

        let controls: [NSView] = [powerButton, levelTitle, levelValue, levelSlider, launchAtLoginButton, aboutButton, quitButton]
        for control in controls {
            panel.addSubview(control)
        }

        view = panel
    }

    func update(boostOn: Bool, level: Int) {
        // Touching view forces loadView, so the controls exist even when an
        // update arrives before the popover has ever been shown.
        _ = view

        powerButton.setOn(boostOn)

        levelSlider.doubleValue = Double(level)
        // The level is kept while the boost is off, but it cannot do anything,
        // so the slider is disabled and faded rather than hidden.
        levelSlider.isEnabled = boostOn
        levelSlider.alphaValue = boostOn ? 1 : 0.35
        showLevel(level)

        levelValue.textColor = boostOn
            ? Theme.primaryText
            : Theme.secondaryText.withAlphaComponent(0.45)
    }

    func updateLaunchAtLogin(enabled: Bool, available: Bool) {
        _ = view

        launchAtLoginButton.state = enabled ? .on : .off
        launchAtLoginButton.isEnabled = available
        styleLaunchAtLoginTitle(available: available)

        launchAtLoginButton.toolTip = available
            ? "Open The Brightening automatically when you log in."
            : "Available after The Brightening is installed in Applications."
    }

    private func showLevel(_ level: Int) {
        levelValue.stringValue = "\(level)%"

        // Without this VoiceOver reads the raw slider number with no unit.
        levelSlider.setAccessibilityValueDescription("\(level) percent")
    }

    // An attributed title is the only way to set a smaller, quieter font on a
    // checkbox title. It also means the dimmed look for the disabled state has
    // to be applied by hand, since AppKit leaves custom colors alone.
    private func styleLaunchAtLoginTitle(available: Bool) {
        launchAtLoginButton.attributedTitle = NSAttributedString(
            string: "Launch at Login",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: Theme.secondaryText.withAlphaComponent(available ? 1 : 0.45),
            ]
        )
    }

    @objc private func powerChanged() {
        onBoostChange?(powerButton.isOn)
    }

    @objc private func levelChanged() {
        let level = Int(levelSlider.doubleValue.rounded())
        showLevel(level)
        onLevelChange?(level)
    }

    @objc private func launchAtLoginChanged() {
        onLaunchAtLoginChange?(launchAtLoginButton.state == .on)
    }

    @objc private func aboutPressed() {
        onAbout?()
    }

    @objc private func quitPressed() {
        onQuit?()
    }
}
