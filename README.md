# MouseFilter

MouseFilter is an assistive macOS app for patients with tremor
(essential tremor, parkinson's disease and multiple sclerosis). It was
inspired by [SteadyMouse](https://steadymouse.com).

**MouseFilter is not a finished product.** It may cause your Mac
to freeze, requiring you to to restart or to stop MouseFilter via SSH.
Auto-updating is not guaranteed to be stable, so you might need to manually
update.

## Requirements

macOS Monterey (version 12) or later.

## How to install

1. Download the
[latest release](https://github.com/rdinse/MouseFilter/releases/latest/download/MouseFilter.zip).
1. Douple-click the ZIP-file to unzip the MouseFilter app (it may have been
   unzipped automatically).
1. *Right*-click the MouseFilter app and choose "Open" and confirm to [open an app from an unidentified developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac).
1. Follow the instructions on screen. Be prepared to enter your password.

## Usage

MouseFilter lives in the menu bar in the top-right corner of the screen.
It can quickly be enabled or disabled with the `F12` key.

## Recommended system settings

Set the double-click speed to a relatively low setting: System Settings >
Accessibility > Pointer Control > Double-click speed.

Consider setting the mouse speed (System Settings > Mouse) to a fairly low
setting which also helps reducing the impact of unintended movements.

## Known issues

* Revoking accessibility permissions while the app is running causes the machine
  to become unresponsive.

## Uninstall

Choose "Uninstall" from the MouseFilter app's menu. The following files will be
removed:

* `/Applications/MouseFilter.app`
* `~/Library/LaunchAgents/com.rdinse.MouseFilter.plist`
* `~/Library/Preferences/com.rdinse.MouseFilter.plist`

## TODO

* Support multiple screens when clipping mouse cursor position.