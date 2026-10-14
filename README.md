# The Brightening

[![License](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2027%2B-lightgrey)](#requirements)
![Architecture](https://img.shields.io/badge/architecture-Apple%20silicon-black?logo=apple&logoColor=white)
[![Release](https://img.shields.io/github/v/release/drabhikroy/the-brightening)](https://github.com/drabhikroy/the-brightening/releases/latest)

The Brightening is a small menu bar app that lets everyday content on a
MacBook Pro's Liquid Retina XDR display get brighter than the display
normally allows.

![The Brightening popover in dark appearance, with the power button on, the Level slider at 160 percent, Launch at Login checked, and the About and Quit buttons](Screenshots/popover.png)

The app works entirely on your Mac. You don't need an account, and there is
no server behind it, because the app never makes a network connection.

## What it does

A MacBook Pro with a Liquid Retina XDR display can show HDR highlights (HDR
stands for high dynamic range) that are far brighter than the white of an
ordinary window. The Brightening lets everything else on screen borrow some
of that extra range. It lives in the menu bar, and you control it from a
small popover.

- The power button turns the boost on and off. When it is off, the display
  returns to normal right away.
- The Level slider sets the boost anywhere from 100 to 160 percent, and the
  app remembers your choice the next time it opens.
- If sleep, a display change, or another app resets the display, the app
  notices within a second and restores the boost.
- Launch at Login is optional. It becomes available once the app is in your
  Applications folder.

## What it does not do

The Brightening only works on the built-in display, and it leaves external
displays alone, including the Pro Display XDR.

It doesn't change HDR video or photos, since those already use the extended
range. It also doesn't save anything to your display profile, so quitting the
app or turning the boost off puts the display back exactly as it was.

## Requirements

The Brightening needs both of these:

- A MacBook Pro with a Liquid Retina XDR display, which means a 14 inch or
  16 inch model from 2021 or later with Apple silicon
- macOS 27 or later

On any other Mac the app opens, but there is nothing for it to boost.

## Install

1. Download `The-Brightening-1.0.0.pkg` from the
   [latest release](https://github.com/drabhikroy/the-brightening/releases/latest).
2. Open the package and follow the steps. macOS asks for an administrator
   password because the installer puts the app in your Applications folder.
3. When the installer finishes, the app opens by itself. Look in the menu bar
   for a sun rising out of a screen.

If you install a newer version over an older one, the installer quits the
running copy first and opens the new one afterward.

### Checking the download

Each release includes a file named `SHA256SUMS.txt`, which lets you confirm
that the package arrived intact. Put it in the same folder as the package and
run the command below. It should report `OK` for the package.

```bash
shasum -a 256 -c SHA256SUMS.txt
```

### Removing The Brightening

1. Open the popover and clear **Launch at Login** if it is on, so macOS
   doesn't try to open the app again.
2. Click **Quit**. The display goes back to normal.
3. Move The Brightening from the Applications folder to the Trash.

If you also want macOS to forget the install record, run the command below.
This step is optional and doesn't affect anything else.

```bash
sudo pkgutil --forget com.abhikroy.thebrightening.pkg
```

## Using The Brightening

1. Click the menu bar icon to open the popover.
2. Click the round power button to turn the boost on or off.
3. Drag the **Level** slider to choose how bright the screen gets.

Right-click or Control-click the menu bar icon to reach **About The
Brightening** and **Quit The Brightening**. The About window shows the
version, the license, and a link to the latest release, and the **About**
button in the popover opens the same window.

## Your data

The app makes no network connections. The links in the About window open in
your browser only when you click them, and it is the browser, not the app,
that goes online.

| What the app writes | Where | How long it stays |
| --- | --- | --- |
| Whether the boost is on, and the level | The app's private preferences | Until you remove the app |
| The login item, when turned on | macOS login items | Until you turn it off |
| The display brightness boost | The display's gamma table, in memory | Until the app quits or the boost is turned off |

While it runs, the installer also keeps a small note for itself that records
whether the app was open. That lets it quit the app first and open the new
copy afterward. The note lives in a folder that only the system can write to,
and the installer deletes it before it finishes.

## Accessibility

- **VoiceOver.** The power button is read as a checkbox named The
  Brightening, along with whether it is on or off. The slider is named Level
  and reads its value as a percentage. Launch at Login, About, and Quit are
  standard macOS controls.
- **Keyboard.** With keyboard navigation turned on in System Settings, you
  can move to the power button with Tab, see a focus ring around it, and
  toggle it with Space.
- **Reduce Motion.** When it is on, the power button changes state at once
  and skips its press animation.
- **Contrast.** Text and the slider fill meet the AA level of the Web Content
  Accessibility Guidelines (WCAG) 2.2 in both light and dark appearance, and
  so does the dimmed power symbol while the boost is off.
- **More than color.** An off boost is shown by a raised button, a dimmed
  symbol, and a faded, disabled slider, so the state doesn't depend on color
  alone.
- **Menu bar.** The icon is a template image, so macOS draws it to match a
  light or dark menu bar and respects Increase Contrast.

## How it works

macOS lifts a display above standard white only while something on screen
asks for extended range. To make that request, the app opens a window one
point in size in the bottom left corner of the screen, and the window's
single pixel is brighter than white. That small request is enough for the
system to open up the extra headroom.

Once the headroom is open, the app writes a new gamma table to the built-in
display. A gamma table is the list of values that tells the display how
bright to make each shade. This one is a straight ramp from black up to the
level you chose, so black stays black and every other value is scaled evenly.
Values above standard white then land in the extended range instead of being
clipped.

A background check looks at the display once a second. If the headroom has
closed, the app opens it again, and if something else has reset the table, the
app writes it again.

When the app puts the display back, it resets the gamma of every display, not
only the built-in one, because macOS has no way to reset a single display. If
another app was tinting an external display, that app may need to apply its
tint again.

## For developers

### Project layout

| Path | Holds |
| --- | --- |
| `Sources/` | The app, written in plain AppKit with no Xcode project |
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

The app is assembled in `~/Library/Caches/TheBrighteningBuild` and not in the
repository. In a repository inside an iCloud synced folder, macOS can add
extended attributes to files while they are being signed, and that breaks the
signature.

`build.sh` passes no optimizer flag and no deployment target to `swiftc`. The
plain build is the one that has been checked on an XDR display, so please test
on the hardware before adding either one. Without a deployment target, the app
requires the macOS version of the Mac that builds it, and the build writes
that version into `Info.plist`.

### Tests and standards gates

```bash
python3 Scripts/standards_gate.py
```

The gate enforces the house writing rules described in
[CONTRIBUTING.md](CONTRIBUTING.md). Continuous integration runs it and
compiles the app on every push.

Two scripts help when a change touches the display. `Scripts/Diagnose.swift`
prints the headroom and the gamma table of every display without changing
anything. `Scripts/compare.sh` builds two copies of the repository in turn,
runs each one, and records those readings, so you can compare two builds as
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

The package and `SHA256SUMS.txt` end up in `dist/`. The version number comes
from `build.sh` alone, and the installer reads it back from the finished app.

If you leave out the three variables, the script builds an unsigned package
that is suitable only for local testing.

### Code signing and verification

The app is signed with a Developer ID Application certificate and the
hardened runtime. The package is signed with a Developer ID Installer
certificate, and then notarized and stapled. You only need to create the
notary profile once.

```bash
xcrun notarytool store-credentials "Notarization"
```

To check a finished package, run these commands.

```bash
pkgutil --check-signature dist/The-Brightening-1.0.0.pkg
spctl --assess --type install --verbose=2 dist/The-Brightening-1.0.0.pkg
```

## Contributing

Conventions and the house writing rules are in
[CONTRIBUTING.md](CONTRIBUTING.md). If you find a security problem, please
follow the steps in [SECURITY.md](SECURITY.md) to report it.

## Releases

Each release lists its changes in [CHANGELOG.md](CHANGELOG.md). The installer
and `SHA256SUMS.txt` are on the
[Releases](https://github.com/drabhikroy/the-brightening/releases) page.

## License

[PolyForm Noncommercial License 1.0.0](LICENSE). The full text is also at
<https://polyformproject.org/licenses/noncommercial/1.0.0>.

The license permits personal use, personal study, hobby projects, teaching,
academic research, and use by charitable, educational, nonprofit, public
research, public health, and government organizations. Commercial use needs a
separate license.

Required notice: Copyright 2026 Abhik Roy.
