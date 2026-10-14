# The Brightening

[![License](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2027%2B-lightgrey)](#requirements)
![Architecture](https://img.shields.io/badge/architecture-Apple%20silicon-black?logo=apple&logoColor=white)
[![Release](https://img.shields.io/github/v/release/drabhikroy/the-brightening)](https://github.com/drabhikroy/the-brightening/releases/latest)

The Brightening is a small menu bar app that lets everyday content on a
MacBook Pro's Liquid Retina XDR display get brighter than the display
normally allows.

![The Brightening popover in dark appearance, with the power button on, the Level slider at 160 percent, Launch at Login checked, and the About and Quit buttons](Screenshots/popover.png)

Everything happens on your Mac and the app never connects to the internet. That
means there is no account to create and no server involved.

## What it does

A MacBook Pro with a Liquid Retina XDR display can show HDR highlights that
are far brighter than the white of an ordinary window. HDR stands for high
dynamic range. The Brightening lets everything else on screen borrow some of
that extra range through a small popover in the menu bar.

- The power button turns the boost on and off and the display returns to normal
  as soon as it is off.
- The Level slider sets the boost anywhere from 100 to 160 percent and the app
  remembers your choice the next time it opens.
- Sleep and display changes can reset the display and so can other apps. The
  app notices within a second and restores the boost.
- Launch at Login is optional and becomes available once the app is in your
  Applications folder.

## What it does not do

The Brightening works only on the built-in display and leaves external
displays alone. That includes the Pro Display XDR.

It does not change HDR video or photos because they already use the extended
range. It also saves nothing to your display profile so quitting the app or
turning the boost off puts the display back exactly as it was.

## Requirements

To use The Brightening you need both of the following.

- A 14 inch or 16 inch MacBook Pro from 2021 or later with Apple silicon and a
  Liquid Retina XDR display
- macOS 27 or later

On any other Mac the app opens but has nothing to boost.

## Install

1. Download `The-Brightening-1.0.0.pkg` from the
   [latest release](https://github.com/drabhikroy/the-brightening/releases/latest).
2. Open the package and follow the steps. macOS asks for an administrator
   password because the installer puts the app in your Applications folder.
3. The app opens by itself when the installer finishes so look in the menu bar
   for a sun rising out of a screen.

Installing a newer version over an older one quits the running copy first and
opens the new one afterward.

### Checking the download

Each release includes a file named `SHA256SUMS.txt` that lets you confirm the
package arrived intact. Put it in the same folder as the package and run the
command below and it should report `OK` for the package.

```bash
shasum -a 256 -c SHA256SUMS.txt
```

### Removing The Brightening

1. Open the popover and clear **Launch at Login** if it is on so macOS does not
   open the app again.
2. Click **Quit** and the display goes back to normal.
3. Move The Brightening from the Applications folder to the Trash.

Run the command below if you also want macOS to forget the install record. That
step is optional and changes nothing else.

```bash
sudo pkgutil --forget com.abhikroy.thebrightening.pkg
```

## Using The Brightening

1. Click the menu bar icon to open the popover.
2. Click the round power button to turn the boost on or off.
3. Drag the **Level** slider to choose how bright the screen gets.

Right-click or Control-click the menu bar icon to reach **About The
Brightening** and **Quit The Brightening**. The About window lists the version
and the license and links to the latest release. You can open the same window
from the **About** button in the popover.

## Your data

The app makes no network connections of its own. Links in the About window open
in your browser only when you click them and it is the browser that goes online.

| What the app writes | Where | How long it stays |
| --- | --- | --- |
| Whether the boost is on, and the level | The app's private preferences | Until you remove the app |
| The login item, when turned on | macOS login items | Until you turn it off |
| The display brightness boost | The display's gamma table, in memory | Until the app quits or the boost is turned off |

The installer keeps a small note recording whether the app was open while it
runs so that it can quit the app first and open the new copy afterward. The
note lives in a folder that only the system can write to and the installer
deletes it before finishing.

## Accessibility

- **VoiceOver.** The power button reads as a checkbox named The Brightening
  along with its on or off state. The slider is named Level and reads its
  value as a percentage. Launch at Login, About, and Quit are standard macOS
  controls.
- **Keyboard.** Turn on keyboard navigation in System Settings and the power
  button takes focus with Tab. It shows a focus ring and toggles with Space.
- **Reduce Motion.** With Reduce Motion on the power button changes state at
  once and skips its press animation.
- **Contrast.** Text and the slider fill meet the AA level of the Web Content
  Accessibility Guidelines (WCAG) 2.2 in light and dark appearance and so does
  the dimmed power symbol while the boost is off.
- **More than color.** An off boost is shown by a raised button, a dimmed
  symbol, and a faded slider that is disabled so color is never the only
  signal.
- **Menu bar.** The icon is a template image so macOS renders it to match a
  light or dark menu bar and respects Increase Contrast.

## How it works

macOS raises a display above standard white only while something on screen asks
for extended range. The app makes that request by opening a window one point in
size in the bottom left corner of the screen. The single pixel in that window
is brighter than white and that small request is enough for the system to open
the extra headroom.

The app then writes a new gamma table to the built-in display. A gamma table is
the list of values that tells the display how bright to make each shade. This
one is a straight ramp from black up to the level you chose so black stays black
and every other value is scaled evenly. Values above standard white land in the
extended range instead of clipping.

The app checks the display once a second and opens the headroom again if it has
closed. It also writes the table again if something else has reset it.

Putting the display back resets the gamma of every display rather than only the
built-in one because macOS offers no way to reset a single display. An external
display tinted by another app may need that app to tint it again.

## For developers

### Project layout

| Path | Holds |
| --- | --- |
| `Sources/` | The app, in plain AppKit with no Xcode project |
| `Installer/` | The installer scripts, the installer window text, and the helper that quits a running copy |
| `Screenshots/` | The picture of the popover used in this README |
| `Assets/` | Icon sources and rendered PNGs. See [Assets/README.md](Assets/README.md) |
| `Scripts/` | The icon generator, the writing gate, and two display diagnostics |
| `build.sh` | Builds and signs the app |
| `build-installer.sh` | Builds the signed, notarized installer package |
| `TheBrightening.entitlements` | The app sandbox entitlement |

### Dependencies

| Task | Needs |
| --- | --- |
| Building | Xcode or the Command Line Tools |
| The writing gate | Python 3 |
| Rebuilding the icons | The `cairosvg` and `Pillow` Python packages |

### Running from source

```bash
git clone https://github.com/drabhikroy/the-brightening.git
cd the-brightening
./build.sh
open "$HOME/Library/Caches/TheBrighteningBuild/The Brightening.app"
```

The app is assembled in `~/Library/Caches/TheBrighteningBuild` rather than in
the repository. A repository in an iCloud synced folder can have extended
attributes added to its files while they are being signed and that breaks the
signature.

`build.sh` passes no optimizer flag and no deployment target to `swiftc`. The
plain build is the one checked on an XDR display so please test on the hardware
before adding either one. Without a target the app requires the macOS version of
the Mac that builds it and the build writes that version into `Info.plist`.

### Tests and standards gates

```bash
python3 Scripts/standards_gate.py
```

The gate enforces the house writing rules in [CONTRIBUTING.md](CONTRIBUTING.md)
and continuous integration runs it and compiles the app on every push.

Two scripts help when a change touches the display. `Scripts/Diagnose.swift`
prints the headroom and the gamma table of every display without changing
anything. `Scripts/compare.sh` builds two copies of the repository in turn and
runs each one and records those readings so two builds can be compared as
numbers.

```bash
./Scripts/compare.sh /path/to/one/copy /path/to/another/copy
```

### Building distributable packages

```bash
export THE_BRIGHTENING_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export THE_BRIGHTENING_INSTALLER_IDENTITY="Developer ID Installer: Your Name (TEAMID)"
export THE_BRIGHTENING_NOTARY_PROFILE="Notarization"
./build-installer.sh
```

The package and `SHA256SUMS.txt` land in `dist/`. The version comes from
`build.sh` alone and the installer reads it back from the finished app.

Without the three variables the script builds an unsigned package for local
testing.

### Code signing and verification

The app is signed with a Developer ID Application certificate and the hardened
runtime. The package is signed with a Developer ID Installer certificate and
then notarized and stapled. Create the notary profile once.

```bash
xcrun notarytool store-credentials "Notarization"
```

Run these commands to check a finished package.

```bash
pkgutil --check-signature dist/The-Brightening-1.0.0.pkg
spctl --assess --type install --verbose=2 dist/The-Brightening-1.0.0.pkg
```

## Contributing

Conventions and house writing rules are in [CONTRIBUTING.md](CONTRIBUTING.md).
Report security problems as described in [SECURITY.md](SECURITY.md).

## Releases

Each release lists its changes in [CHANGELOG.md](CHANGELOG.md). The installer
and `SHA256SUMS.txt` are on the
[Releases](https://github.com/drabhikroy/the-brightening/releases) page.

## License

[PolyForm Noncommercial License 1.0.0](LICENSE). The full text is also at
<https://polyformproject.org/licenses/noncommercial/1.0.0>.

Personal use, personal study, hobby projects, teaching, academic research, and
use by charitable, educational, nonprofit, public research, public health, and
government organizations are permitted. Commercial use is not permitted without
a separate license.

Required notice: Copyright 2026 Abhik Roy.
