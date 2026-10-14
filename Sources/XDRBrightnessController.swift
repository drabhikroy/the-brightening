import CoreGraphics

/// Raises the brightness of the built-in display by scaling its gamma table.
///
/// Values above 1.0 in a transfer table normally have nowhere to go. While
/// EDRTrigger holds the headroom open they land in the extended range, so
/// ordinary content is pushed past standard white. That is the whole boost.
final class XDRBrightnessController {
    /// A safety cap matching the top of the slider in the popover, so a bad
    /// saved value can never push the table further than the UI allows.
    static let maximumMultiplier: Float = 1.6

    @discardableResult
    func apply(multiplier: Float) -> Bool {
        guard let displayID = builtInDisplayID() else {
            return false
        }

        let ceiling = Self.clamped(multiplier)

        // At 1.0 there is nothing to boost, and the system profile is a better
        // identity than a hand built linear ramp.
        if ceiling <= 1.001 {
            restore()
            return true
        }

        // A straight ramp from black to the ceiling. Black stays black and
        // every other value is scaled evenly, so contrast keeps its shape.
        // Scaling the profile curve instead was tried and washed the screen
        // out, because the table the system reports is not always a plain
        // ramp. This replaces the display profile curve while the boost is
        // on, and restore() puts it back.
        let size = 256
        let table = (0..<size).map { index in
            CGGammaValue(index) / CGGammaValue(size - 1) * ceiling
        }

        return table.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else {
                return false
            }

            return CGSetDisplayTransferByTable(displayID, UInt32(size), base, base, base) == .success
        }
    }

    /// True when the table no longer carries the boost, which usually means
    /// the system or another app reset it.
    func needsReapply(multiplier: Float) -> Bool {
        guard let displayID = builtInDisplayID() else {
            return false
        }

        let capacity = CGDisplayGammaTableCapacity(displayID)
        guard capacity > 0 else {
            return false
        }

        var red = [CGGammaValue](repeating: 0, count: Int(capacity))
        var green = red
        var blue = red
        var count: UInt32 = 0

        guard
            CGGetDisplayTransferByTable(displayID, capacity, &red, &green, &blue, &count) == .success,
            count > 0
        else {
            return false
        }

        // The red channel alone is enough because apply() writes the same
        // table to all three. A little slack, because the table read back is
        // quantized and will not match the written value exactly.
        let current = red.prefix(Int(count)).max() ?? 0
        return current < Self.clamped(multiplier) - 0.02
    }

    /// Puts back the ColorSync profile. CoreGraphics only offers this for all
    /// displays at once, so an external display tinted by another app is
    /// reset too.
    func restore() {
        CGDisplayRestoreColorSyncSettings()
    }

    private static func clamped(_ multiplier: Float) -> Float {
        max(1, min(multiplier, maximumMultiplier))
    }

    private func builtInDisplayID() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return nil
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else {
            return nil
        }

        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }
}
