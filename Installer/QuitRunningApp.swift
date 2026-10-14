import AppKit
import Darwin

let bundleIdentifier = "com.abhikroy.thebrightening"
let applications = NSRunningApplication.runningApplications(
    withBundleIdentifier: bundleIdentifier
)

// terminate() only sends the request. The preinstall script waits for the
// process to actually exit, so this helper reports only whether every
// request could be sent.
var failed = false

for application in applications {
    if !application.isTerminated && !application.terminate() {
        failed = true
    }
}

exit(failed ? EXIT_FAILURE : EXIT_SUCCESS)
