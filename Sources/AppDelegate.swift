import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let levelRange = 100...160
    static let defaultLevel = 110

    private enum DefaultsKey {
        static let boostOn = "boostOn"
        static let level = "level"
    }

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let panel = PanelViewController()

    private let edrTrigger = EDRTrigger()
    private let brightness = XDRBrightnessController()

    private var boostOn: Bool
    private var level: Int

    private var activationTimer: Timer?
    private var watchdogTimer: Timer?

    // Bumped whenever the boost restarts or stops. Writes that were queued
    // before the bump see a stale number and skip themselves.
    private var boostGeneration = 0
    private var burstRunning = false

    private var multiplier: Float {
        Float(level) / 100
    }

    override init() {
        let defaults = UserDefaults.standard

        // bool(forKey:) reads a missing key as false, but a first launch
        // should start with the boost on.
        boostOn = defaults.object(forKey: DefaultsKey.boostOn) as? Bool ?? true

        // integer(forKey:) returns 0 when nothing is saved, which is outside
        // the slider range, so 0 doubles as "use the default".
        let savedLevel = defaults.integer(forKey: DefaultsKey.level)
        level = savedLevel == 0
            ? Self.defaultLevel
            : min(Self.levelRange.upperBound, max(Self.levelRange.lowerBound, savedLevel))

        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only. LSUIElement in Info.plist already keeps the app out
        // of the Dock, and this covers running the bare binary during work.
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = MenuBarIcon.make()
            button.target = self
            button.action = #selector(statusItemClicked)

            // A plain click opens the popover, so the menu needs the right
            // button, which only reaches the action if asked for here.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        panel.onBoostChange = { [weak self] on in self?.setBoost(on) }
        panel.onLevelChange = { [weak self] value in self?.setLevel(value) }
        panel.onLaunchAtLoginChange = { [weak self] enabled in self?.setLaunchAtLogin(enabled) }
        panel.onAbout = { [weak self] in self?.showAbout() }
        panel.onQuit = { [weak self] in self?.quit() }

        popover.contentViewController = panel
        popover.contentSize = PanelViewController.size
        popover.behavior = .transient
        popover.animates = false

        // Opening the lid or waking from sleep can bring back a built-in
        // screen that was missing at launch. The watchdog only runs after a
        // first successful start, so these two notifications cover the case
        // where the app launched with nothing to boost.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(displaysChanged),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        refreshPanel()

        if boostActive {
            startBoost()
        }
    }

    // Quitting from the popover, logging out, and the installer asking the
    // app to quit all pass through here, so the display is always put back.
    func applicationWillTerminate(_ notification: Notification) {
        stopBoost()
    }

    // MARK: Boost

    // On with the level at 100 means there is nothing to do. Treating that the
    // same as off lets the EDR window come down, so the panel is not held at
    // extended brightness for no visible gain.
    private var boostActive: Bool {
        boostOn && level > Self.levelRange.lowerBound
    }

    private func startBoost() {
        cancelPendingWrites()
        edrTrigger.start()
        startActivationTimer()
    }

    private func stopBoost() {
        stopTimers()
        cancelPendingWrites()
        brightness.restore()
        edrTrigger.stop()
    }

    private func cancelPendingWrites() {
        boostGeneration += 1
        burstRunning = false
    }

    private func startActivationTimer() {
        activationTimer?.invalidate()
        activationTimer = nil

        if tryActivation() {
            return
        }

        // With no built-in XDR screen (an older Mac, or the lid closed) the
        // poll below could never succeed. A display change notification will
        // start things again if a suitable screen shows up.
        guard edrTrigger.isSupported else {
            return
        }

        // EDR headroom opens a few frames after the trigger window appears,
        // not immediately, so poll briefly until it does.
        activationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            if !self.boostActive || self.tryActivation() {
                timer.invalidate()
                self.activationTimer = nil
            }
        }
    }

    private func tryActivation() -> Bool {
        guard boostActive, edrTrigger.hasHeadroom else {
            return false
        }

        applyBoostBurst()
        startWatchdog()
        refreshPanel()
        return true
    }

    // Other software, display changes, and the system itself can quietly put
    // the gamma table back. Once a second is often enough to catch that
    // without the check costing anything noticeable.
    private func startWatchdog() {
        guard watchdogTimer == nil else {
            return
        }

        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkBoostState()
        }
    }

    private func checkBoostState() {
        guard boostActive else {
            return
        }

        if !edrTrigger.hasHeadroom {
            if activationTimer == nil && edrTrigger.isSupported {
                edrTrigger.start()
                startActivationTimer()
            }
            return
        }

        if brightness.needsReapply(multiplier: multiplier) {
            applyBoostBurst()
        }
    }

    // A single write right after EDR turns on does not always stick, since the
    // system can still be settling the display at that moment. Repeating the
    // write over about half a second outlasts that window.
    private func applyBoostBurst() {
        guard boostActive, !burstRunning else {
            return
        }

        burstRunning = true

        let generation = boostGeneration
        let attempts = 12

        for attempt in 0..<attempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt) * 0.04) { [weak self] in
                guard let self, generation == self.boostGeneration else {
                    return
                }

                if attempt == attempts - 1 {
                    self.burstRunning = false
                }

                self.brightness.apply(multiplier: self.multiplier)
            }
        }
    }

    private func setBoost(_ on: Bool) {
        boostOn = on
        UserDefaults.standard.set(on, forKey: DefaultsKey.boostOn)

        if boostActive {
            startBoost()
        } else {
            stopBoost()
        }

        refreshPanel()
    }

    private func setLevel(_ value: Int) {
        let wasActive = boostActive

        level = value
        UserDefaults.standard.set(value, forKey: DefaultsKey.level)

        switch (wasActive, boostActive) {
        case (false, true):
            // Leaving 100 needs the EDR window back before anything can show.
            startBoost()
        case (true, false):
            stopBoost()
        case (true, true) where edrTrigger.hasHeadroom:
            // While headroom is still opening, the activation timer picks up
            // the new level on its own, so only an open screen is written here.
            brightness.apply(multiplier: multiplier)
        default:
            break
        }

        refreshPanel()
    }

    private func stopTimers() {
        activationTimer?.invalidate()
        activationTimer = nil
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    @objc private func displaysChanged() {
        // This notification also fires when EDR headroom itself rises or
        // falls. Restarting while headroom is open, or while a start is
        // already in progress, would tear down the window that opened it and
        // set off the same notification again.
        guard boostActive, activationTimer == nil, !edrTrigger.hasHeadroom else {
            return
        }

        startBoost()
    }

    // MARK: Launch at Login

    // SMAppService registers whatever bundle is running. Registering a copy
    // in Downloads or a build folder would leave a login item that breaks as
    // soon as that copy moves, so the option waits until the app is installed.
    private var isInstalledInApplications: Bool {
        Bundle.main.bundleURL.standardizedFileURL.path.hasPrefix("/Applications/")
    }

    // Waiting for approval counts as on. The user has asked for it, and the
    // checkbox flipping back off would read as the request being ignored.
    private var launchAtLoginEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        guard isInstalledInApplications else {
            refreshPanel()
            showAlert(
                title: "Install The Brightening First",
                message: "Launch at Login becomes available when The Brightening is installed in the Applications folder.",
                style: .informational
            )
            return
        }

        let service = SMAppService.mainApp

        do {
            if enabled {
                if service.status == .notRegistered || service.status == .notFound {
                    try service.register()
                }

                // Registering can succeed and still leave the item waiting for
                // the user to allow it in System Settings, which is the only
                // place that approval can be given.
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
        } catch {
            showAlert(
                title: enabled ? "Could Not Turn On Launch at Login" : "Could Not Turn Off Launch at Login",
                message: error.localizedDescription,
                style: .warning
            )
        }

        refreshPanel()
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")

        // A menu bar app is never the active app on its own, and an alert
        // from an inactive app opens behind whatever window has focus.
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: Popover

    private func refreshPanel() {
        panel.update(boostOn: boostOn, level: level)
        panel.updateLaunchAtLogin(enabled: launchAtLoginEnabled, available: isInstalledInApplications)
    }

    @objc private func statusItemClicked() {
        // Control click counts as a right click on a Mac, and trackpads often
        // send it that way.
        if let event = NSApp.currentEvent, event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    // The menu is attached only for the moment of the click. Leaving it on the
    // status item would make every click, including the left one, open the
    // menu instead of the popover.
    private func showContextMenu() {
        popover.performClose(nil)

        let menu = NSMenu()

        let about = NSMenuItem(title: "About The Brightening", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit The Brightening", action: #selector(quitFromMenu), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // The popover has to close first. It is transient, but it stays up while
    // the About panel opens, and the two would sit on top of each other.
    @objc private func showAbout() {
        popover.performClose(nil)
        AboutPanel.show()
    }

    @objc private func quitFromMenu() {
        quit()
    }

    private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        // Launch at Login can be changed in System Settings while the popover
        // is closed, so the panel is brought up to date each time it opens.
        refreshPanel()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func quit() {
        stopBoost()
        NSApp.terminate(nil)
    }
}
