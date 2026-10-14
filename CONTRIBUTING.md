# Contributing

Thank you for helping improve The Brightening.

## Before opening a pull request

1. Build the app and run the writing gate. Both must pass.

   ```bash
   ./build.sh
   python3 Scripts/standards_gate.py
   ```

2. The build treats warnings as errors. Fix a warning rather than turning the
   flag off.
3. Keep the app in plain AppKit under `Sources/`, compiled by `build.sh` with
   `swiftc` and no Xcode project.
4. Test any change on a MacBook Pro with a Liquid Retina XDR display. A
   change that compiles cleanly can still change what the screen looks like.

## Changes that touch the display

The boost depends on details that cannot be checked away from the hardware.
For any change to `EDRTrigger.swift`, `XDRBrightnessController.swift`, the
boost logic in `AppDelegate.swift`, or the compiler flags in `build.sh`:

- Compare the change against the current release with
  `Scripts/compare.sh`, which records the headroom and gamma table of each
  build so the two can be compared as numbers.
- Set the same level in both builds before comparing them by eye. Both builds
  share one set of preferences, so the level carries over from one to the
  other.
- Check at full display brightness and at a lower setting, with mostly white
  content on screen, at the top of the slider.
- Make sure quitting the app, turning the boost off, and closing the lid all
  put the display back to normal.

Judge the result on the display itself. Reasoning about nits and gamma can
predict a problem that the panel does not actually show, so a change that
only looks right on paper is not done.

## Accessibility

Check any change to the popover with VoiceOver, keyboard navigation, light
and dark appearance, Increase Contrast, and Reduce Motion. New controls need
an accessibility label. Text and the controls that carry meaning must keep
WCAG 2.2 AA contrast in both appearances, and a state shown by color also
needs a change in shape or position.

## Changes to the icon

The icon is generated. Edit `Scripts/make_icons.py` rather than the SVG files,
then run it and commit the SVG and PNG output together. The menu bar icon is
drawn in `Sources/MenuBarIcon.swift` from the same numbers as
`MENU` in the script, so change both together. See
[Assets/README.md](Assets/README.md) for how the artwork is constructed.

## House writing rules

These apply to code comments, documentation, and messages in the interface,
and `Scripts/standards_gate.py` checks them.

- No em or en dashes. Use a comma, a period, or a rewrite.
- No contractions. Write the words out.
- None of the words on the short banned list in `Scripts/standards_gate.py`.
- American spelling.
- Comments explain why the code is the way it is, not what each line does.

## Reporting problems

Bug reports are most useful with the MacBook Pro model, the macOS version,
the version of The Brightening shown in its About window, the level setting,
and the output of the display diagnostic taken while the problem is on
screen.

```bash
swiftc Scripts/Diagnose.swift -framework AppKit -o /tmp/brightening-diagnose
/tmp/brightening-diagnose
```

By contributing, you agree that your contribution is licensed under the
repository's PolyForm Noncommercial License 1.0.0.
