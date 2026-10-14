# Security policy

## What The Brightening can do

The Brightening is a small signed menu bar app. It runs in the macOS app
sandbox with no entitlement beyond the sandbox itself. It has no network
code, no updater, and no telemetry. Links in the About window, to the license
and the release page, open in the browser only when a person clicks them.

While the boost is on, the app does two things to the built-in display.

- It shows a window one point square in the bottom left corner of the screen,
  holding a single pixel brighter than white, so macOS opens the display's
  extended range.
- It writes a gamma table to the built-in display through CoreGraphics.

Both end when the boost is turned off or the app quits. Quitting through the
app, logging out, and the installer asking the app to quit all put the
display profile back. A gamma table set by an app is also discarded by macOS
when that app exits for any other reason.

## Files and settings it touches

- Two preferences, whether the boost is on and the level, in the app's own
  sandbox container
- A login item, registered with macOS only when a person turns on Launch at
  Login, and only for a copy of the app in `/Applications`

The app reads no files and writes nothing outside its container.

## The installer

The package installs `/Applications/The Brightening.app` and runs two short
scripts as root.

- `preinstall` checks whether the app is running for the person at the
  screen and, if so, asks it to quit through a small signed helper, so it can
  restore the display before its files are replaced. It records what it found
  in `/private/var/db/com.abhikroy.thebrightening.install`, a folder only root
  can write to, so no other account can plant a link there for a root owned
  write to follow.
- `postinstall` reads that record, removes the folder, and opens the app in
  that person's own session. It never runs the app as root.

## Permissions

The Brightening requests no Full Disk Access, no Accessibility, no
Automation, no camera, no microphone, and no location. macOS may ask once
for approval in Login Items when Launch at Login is turned on.

## Signing

The app is signed with a Developer ID Application certificate and the
hardened runtime. The installer package is signed with a Developer ID
Installer certificate, notarized by Apple, and stapled. Each release
publishes a `SHA256SUMS.txt` so a download can be checked before it is
opened.

## Known limits

Putting the display back resets the gamma table of every display, because
CoreGraphics offers no way to reset a single one. An external display tinted
by another app may need that app to apply its setting again.

The bright pixel in the corner of the screen is visible to anyone looking
closely while the boost is on.

## Reporting a vulnerability

Please report a vulnerability privately through a [GitHub security
advisory](https://github.com/drabhikroy/the-brightening/security/advisories/new)
rather than a public issue. Include the macOS version, the version of The
Brightening, and steps to reproduce.
