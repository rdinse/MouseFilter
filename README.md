# MouseFilter

MouseFilter is an assistive macOS app for patients with tremor
(essential tremor, parkinson's disease and multiple sclerosis). It was
inspired by [SteadyMouse](https://steadymouse.com).

Please note that MouseFilter is not a finished product. Install at your own risk!
Consider setting up SSH access to be able to stop it in case it gets stuck from
another machine.

## How to install

1. Download the
[latest version](https://github.com/rdinse/mousefilter/releases/latest/download/MouseFilter.zip).
1. Navigate to the download folder.
1. Douple-click the ZIP-file to unpack the MouseFilter app.
1. Then double-click the unpacked app.

## Usage

MouseFilter can be enabled/disabled in the menu bar or with the F12 key (on some
keyboards it is necessary to press the `fn` key to get access to the F-keys).
The sensitivty and display of the red dot can be changed in the Settings which
can be opened in the menu bar. Rubber banding refers to how quickly the cursor
catches up with large movements.

## Recommended system settings

Set the double-click speed to a relatively low setting: System Settings >
Accessibility > Pointer Control > Double-click speed.

Consider setting the mouse speed (System Settings > Mouse) to a fairly low
setting which also helps reducing the impact of unintended movements.

## Build

Build normally using Xcode or with `build.sh`.

## License

MIT