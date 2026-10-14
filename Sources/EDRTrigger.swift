import AppKit
import CoreGraphics
import Metal
import QuartzCore

/// Keeps EDR headroom open on the built-in display.
///
/// macOS only raises a display above standard white while something on
/// screen asks for extended range. This class puts up a one pixel window
/// whose Metal layer holds a color brighter than white, which is the
/// smallest request that still counts. The gamma boost in
/// XDRBrightnessController relies on that headroom being there.
final class EDRTrigger {
    private var window: NSWindow?
    private var metalLayer: CAMetalLayer?
    private var commandQueue: MTLCommandQueue?

    /// True when a built-in screen that can show EDR is connected.
    var isSupported: Bool {
        targetScreen() != nil
    }

    /// How far above standard white the system will currently let content
    /// go, as a multiple of it. It falls as the display brightness rises.
    var headroom: CGFloat {
        targetScreen()?.maximumExtendedDynamicRangeColorComponentValue ?? 1
    }

    /// True once the system has actually raised the headroom. The small
    /// margin keeps rounding noise around 1.0 from counting as open.
    var hasHeadroom: Bool {
        headroom > 1.01
    }

    func start() {
        stop()

        guard
            let screen = targetScreen(),
            let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue()
        else {
            return
        }

        // One point in the bottom left corner. The bright dot is visible if
        // you look for it, but a corner is the least intrusive place for it.
        // It stays on visible screen area, because the system may not count a
        // pixel that sits under the notch housing as content asking for range.
        let frame = NSRect(x: screen.frame.minX, y: screen.frame.minY, width: 1, height: 1)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true

        // A covered window stops asking for headroom, so the panel sits above
        // full screen apps and follows the user to every Space.
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        guard let contentView = panel.contentView else {
            return
        }

        // Half float pixels in extended linear Display P3 are what let a
        // component go past 1.0. An 8 bit or non extended layer would clamp
        // the clear color below back down to plain white.
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .rgba16Float
        layer.framebufferOnly = true
        layer.wantsExtendedDynamicRangeContent = true
        layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        layer.contentsScale = screen.backingScaleFactor
        layer.frame = contentView.bounds
        layer.drawableSize = CGSize(
            width: max(1, contentView.bounds.width * screen.backingScaleFactor),
            height: max(1, contentView.bounds.height * screen.backingScaleFactor)
        )

        contentView.wantsLayer = true
        contentView.layer = layer

        window = panel
        metalLayer = layer
        commandQueue = queue

        panel.orderFrontRegardless()
        drawBrightPixel()
    }

    func stop() {
        window?.orderOut(nil)
        window = nil
        metalLayer = nil
        commandQueue = nil
    }

    // One frame is enough. The layer keeps showing its last drawable, so
    // nothing has to redraw while the window stays up.
    private func drawBrightPixel() {
        guard
            let layer = metalLayer,
            let queue = commandQueue,
            let drawable = layer.nextDrawable(),
            let commandBuffer = queue.makeCommandBuffer()
        else {
            return
        }

        // Clearing to 2.0 asks for twice standard white. The exact number does
        // not matter much, as long as it is above 1.0.
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 2, green: 2, blue: 2, alpha: 1)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            return
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // Only the built-in panel is boosted. XDRBrightnessController writes to
    // the built-in display as well, so both sides agree on which screen.
    private func targetScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard
                screen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1,
                let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else {
                return false
            }

            return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
        }
    }
}
