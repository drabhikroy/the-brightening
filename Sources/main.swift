import AppKit

// A plain entry point instead of @main, because build.sh compiles the sources
// with swiftc directly and there is no Xcode target to supply one.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
