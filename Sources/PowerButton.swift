import AppKit

/// The round power button at the top of the popover. It sinks a little when
/// on, the way a physical push button stays down once it is engaged.
final class PowerButton: NSControl {
    private(set) var isOn = true

    // How far the button has sunk, from 0 (raised) to 1 (pressed). It is kept
    // apart from isOn so the drawing can sit between the two mid-animation.
    private var pressProgress: CGFloat = 1
    private var animationTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        // VoiceOver treats a custom NSControl as an unnamed group unless told
        // otherwise. A checkbox role gives it a name and an on or off state.
        setAccessibilityElement(true)
        setAccessibilityRole(.checkBox)
        setAccessibilityLabel("The Brightening")
        setAccessibilityValue(NSNumber(value: isOn))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    func setOn(_ newValue: Bool, animated: Bool = false) {
        guard newValue != isOn else {
            needsDisplay = true
            return
        }

        isOn = newValue
        setAccessibilityValue(NSNumber(value: isOn))
        NSAccessibility.post(element: self, notification: .valueChanged)

        let goal: CGFloat = isOn ? 1 : 0

        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            animatePress(to: goal)
        } else {
            animationTimer?.invalidate()
            animationTimer = nil
            pressProgress = goal
            redraw()
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let dark = Theme.isDark(effectiveAppearance)
        let rect = faceRect()
        let face = NSBezierPath(ovalIn: rect)

        // A pressed button sits closer to the panel, so its shadow is tighter
        // and shallower than the shadow of a raised one.
        let shadow = NSShadow()
        if dark {
            shadow.shadowBlurRadius = isOn ? 2.0 : 3.0
            shadow.shadowOffset = NSSize(width: 0, height: isOn ? -0.5 : -1.2)
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.36)
        } else {
            shadow.shadowBlurRadius = isOn ? 1.5 : 2.5
            shadow.shadowOffset = NSSize(width: 0, height: isOn ? -0.3 : -1.0)
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
        }

        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        (dark ? Theme.rgb(46, 47, 51) : NSColor.white).setFill()
        face.fill()
        NSGraphicsContext.restoreGraphicsState()

        (dark ? NSColor.white.withAlphaComponent(0.14) : Theme.rgb(198, 201, 194)).setStroke()
        face.lineWidth = 1
        face.stroke()

        drawPowerSymbol(in: rect, dark: dark)
    }

    override var focusRingMaskBounds: NSRect { bounds }

    override func drawFocusRingMask() {
        NSBezierPath(ovalIn: faceRect()).fill()
    }

    private func faceRect() -> NSRect {
        let diameter = min(bounds.width, bounds.height)

        // About a point of travel reads as a press without looking like the
        // button moved. The inset below leaves room for it inside the bounds.
        let travel: CGFloat = 1.2

        return NSRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2 - travel * pressProgress,
            width: diameter,
            height: diameter
        ).insetBy(dx: 1.5, dy: 1.5)
    }

    private func drawPowerSymbol(in rect: NSRect, dark: Bool) {
        let center = NSPoint(x: rect.midX, y: rect.midY)

        // Off dims the symbol instead of hiding it, so the button still says
        // what it does. At 0.55 the dimmed stroke keeps 3 to 1 contrast
        // against the white face in light mode.
        let alpha: CGFloat = isOn ? 1 : 0.55
        let color = dark
            ? NSColor.white.withAlphaComponent(alpha)
            : Theme.rgb(38, 39, 36, alpha: alpha)
        color.setStroke()

        // The ring runs counterclockwise from 130 to 410 degrees, which leaves
        // a gap at the top for the stem.
        let ring = NSBezierPath()
        ring.appendArc(withCenter: center, radius: 5.3, startAngle: 130, endAngle: 410, clockwise: false)

        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: center.x, y: center.y + 6.4))
        stem.line(to: NSPoint(x: center.x, y: center.y + 0.7))

        for path in [ring, stem] {
            path.lineWidth = 1.8
            path.lineCapStyle = .round
            path.stroke()
        }
    }

    private func redraw() {
        needsDisplay = true
        noteFocusRingMaskChanged()
    }

    // MARK: Input

    override func mouseDown(with event: NSEvent) {
        toggle()
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            toggle()
        } else {
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        toggle()
        return true
    }

    private func toggle() {
        setOn(!isOn, animated: true)
        sendAction(action, to: target)
    }

    private func animatePress(to goal: CGFloat) {
        animationTimer?.invalidate()

        let start = pressProgress
        let startTime = Date.timeIntervalSinceReferenceDate
        let duration: TimeInterval = 0.35

        // A timer rather than NSAnimationContext, because the animated value
        // is a drawing parameter and not a property AppKit knows how to tween.
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            let t = min(1, (Date.timeIntervalSinceReferenceDate - startTime) / duration)

            // Smoothstep eases in and out, so the press starts and lands softly.
            let eased = CGFloat(t * t * (3 - 2 * t))
            self.pressProgress = start + (goal - start) * eased
            self.redraw()

            if t >= 1 {
                timer.invalidate()
                self.animationTimer = nil
            }
        }

        animationTimer = timer

        // Common modes keep the animation running while the popover is
        // tracking the mouse. The default mode alone would freeze it.
        RunLoop.main.add(timer, forMode: .common)
    }
}
