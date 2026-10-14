import AppKit
import CoreGraphics

// Prints what the displays are doing right now, so a running copy of the app
// can be compared with another build. It only reads state and changes nothing.
_ = NSApplication.shared

for screen in NSScreen.screens {
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
        continue
    }

    let id = CGDirectDisplayID(number.uint32Value)
    print("display \(id), built in: \(CGDisplayIsBuiltin(id) != 0)")
    print("  extended range now: \(screen.maximumExtendedDynamicRangeColorComponentValue)")
    print("  extended range possible: \(screen.maximumPotentialExtendedDynamicRangeColorComponentValue)")
    print("  top inset: \(screen.safeAreaInsets.top)")

    let capacity = CGDisplayGammaTableCapacity(id)
    var red = [CGGammaValue](repeating: 0, count: Int(capacity))
    var green = red
    var blue = red
    var count: UInt32 = 0

    guard
        CGGetDisplayTransferByTable(id, capacity, &red, &green, &blue, &count) == .success,
        count > 0
    else {
        print("  gamma table could not be read")
        continue
    }

    let used = Int(count)
    print("  gamma entries: \(used)")
    print("  gamma first \(red[0]), middle \(red[used / 2]), last \(red[used - 1])")
    print("  gamma red max \(red.prefix(used).max() ?? 0), green max \(green.prefix(used).max() ?? 0), blue max \(blue.prefix(used).max() ?? 0)")
}
