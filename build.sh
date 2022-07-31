#!/bin/bash

#
# build.sh
#

# Exit on error
set -e

if [ $# -eq 0 ]; then
  echo "Usage: build.sh [Debug|Release|Clean]"
  exit 1
fi

# Get the path to this script
SCRIPT_PATH="$(dirname "$0")"

killall MouseFilter || true

if [ "$1" == "Clean" ]; then
  echo "Cleaning build directory"
  rm -rf "$SCRIPT_PATH/build"
  echo "Deregistering from launchd"
  (launchctl bootout GUI/$(id -u) ~/Library/LaunchAgents/com.rdinse.MouseFilter.plist \
    > /dev/null 2>&1) || true
  echo "Removing system files"
  rm -f ~/Library/Preferences/com.rdinse.MouseFilter.plist
  rm -f ~/Library/LaunchAgents/com.rdinse.MouseFilter.plist
  tccutil reset Accessibility com.rdinse.MouseFilter
  exit 0
fi

xcodebuild -configuration $1 build

if [ $1 == "Release" ]; then
    # Create dmg
    TMPDIR=$(mktemp -d)
    cp -r "$SCRIPT_PATH/build/Release/MouseFilter.app" "$TMPDIR"
    ln -s "/Applications" "$TMPDIR/Applications"
    hdiutil create -volname "MouseFilter" -srcfolder "$TMPDIR" -ov -format UDZO \
      "$SCRIPT_PATH/build/Release/MouseFilter.dmg"
    rm -rf "$TMPDIR"

    (cd $SCRIPT_PATH/build/Release; zip -r MouseFilter.zip MouseFilter.app)

    # Put the app in quarantine in ~/Downloads to simulate a fresh download.
    dlfile="$HOME/Downloads/MouseFilter.app"
    uuid=$(/usr/bin/uuidgen)
    url="http://${uuid}.example.com/MouseFilter.zip"
    app="Safari"
    date="$(printf %x $(date +%s))"
    ndate=$(($(date +%s) - 978307200))
    cp -r "$SCRIPT_PATH/build/Release/MouseFilter.app" "$dlfile"
    /usr/bin/xattr -w com.apple.quarantine "0002;${date};${app};${uuid}" "$dlfile"
    /usr/bin/sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2 \
      "INSERT INTO \"LSQuarantineEvent\" VALUES('${uuid}',${ndate},'com.apple.${app}','${app}','${url}',NULL,NULL,0,NULL,'${url}',NULL);"

    # Set the download url.
    /usr/bin/xattr -w com.apple.metadata:kMDItemWhereFroms "${url}" "$dlfile"

    # Reset accessibility permissions.
    tccutil reset Accessibility com.rdinse.MouseFilter

    open $SCRIPT_PATH/build/Release/
    open "$(dirname "$dlfile")"

    echo "Build completed. Exiting..."
    exit 0
fi

if [ $1 == "Debug" ]; then
  lldb build/Debug/MouseFilter.app --one-line "run" --one-line-on-crash "bt"
  # Run target immediately. Quit lldb when the target quits. Print the stack trace
  # on crash.
fi