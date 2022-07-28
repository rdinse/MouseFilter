# MouseFilter

MouseFilter is an assistive macOS app for patients with tremor
(essential tremor, parkinson's disease and multiple sclerosis). It was
inspired by [SteadyMouse](https://steadymouse.com).

**MouseFilter is not a finished product.** It may cause your Mac
to freeze, requiring you to to restart or to stop MouseFilter via SSH.

## How to install

1. Download the
[latest version](https://github.com/rdinse/MouseFilter/releases/latest/download/MouseFilter.dmg).
1. Douple-click the downloaded DMG-file. Move the app to the Applications folder.
1. Double-click Applications and then MouseFilter.
1. Right-click MouseFilter.app and choose "Open" and confirm to [open an app from an unidentified developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac).
1. Follow the instructions in the alerts that pop up.

## Usage

MouseFilter can be enabled/disabled in the menu bar or with the F12 key (on some
keyboards it is necessary to press the `fn` key to get access to the F-keys).
The sensitivty and display of the red dot can be changed in the Settings which
can be opened in the menu bar. "Rubber banding" refers to how quickly the cursor
catches up with large movements.

## Recommended system settings

Set the double-click speed to a relatively low setting: System Settings >
Accessibility > Pointer Control > Double-click speed.

Consider setting the mouse speed (System Settings > Mouse) to a fairly low
setting which also helps reducing the impact of unintended movements.

## Build

Build normally using Xcode or with `build.sh`.

## Known issues

* Revoking accessibility permissions while the app is running causes the machine
  to become unresponsive.

## License

MIT