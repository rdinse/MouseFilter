# MouseFilter

MouseFilter is an assistive macOS app for patients with tremor
(essential tremor, parkinson's disease and multiple sclerosis). It was
inspired by [SteadyMouse](https://steadymouse.com).

**MouseFilter is not a finished product.** It may cause your Mac
to freeze, requiring you to to restart or to stop MouseFilter via SSH.
Auto-updating is not guaranteed to be reliable yet, so you might need to update
manually.

![](https://raw.githubusercontent.com/rdinse/MouseFilter/master/MouseFilter.gif)

## Requirements

macOS Monterey (version 12).

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

Tremor patients might benefit from reducing input speed and repeat rates in *System Settings*:

* Mouse speed: System Settings > Mouse
* Double-click speed: System Settings > Accessibility > Pointer Control > Double-click speed
* Slow keys: System Settings > Accessibility > Keyboard > Hardware > Slow keys (consider changing the delay)
* Key Repeat rate and delay: System Settings > Keyboard

## Known issues

* In some applications dragging the mouse is constrained to the x- and y-axes and
  laggy, e.g. when setting the boundaries for screen recording with QuickTime.

## Uninstall

Choose "Uninstall" from the MouseFilter app's menu. The following files will be
removed:

* `/Applications/MouseFilter.app`
* `~/Library/LaunchAgents/com.rdinse.MouseFilter.plist`
* `~/Library/Preferences/com.rdinse.MouseFilter.plist`

## TODO

* Support multiple screens when clipping mouse cursor position.