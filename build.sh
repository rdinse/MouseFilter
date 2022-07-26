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
  (launchctl bootout GUI/$(id -u) ~/Library/LaunchAgents/com.robd.MouseFilter.plist > /dev/null 2>&1) || true
  echo "Removing system files"
  rm -f ~/Library/Preferences/com.robd.MouseFilter.plist
  rm -f ~/Library/LaunchAgents/com.robd.MouseFilter.plist
  exit 0
fi

xcodebuild -configuration $1 build

# Exit if the build failed.
if [ $? -ne 0 ]; then
    echo "Build failed. Exiting..."
    exit 1
fi

# Exit here if built for Release.
if [ $1 == "Release" ]; then
    echo "Build successful. The app is in the build/Release directory. Exiting..."
    open $SCRIPT_PATH/build/Release/
    exit 0
fi

# Start with lldb and run immediately, quit lldb when the target quits.
lldb build/Debug/MouseFilter.app --one-line "run" --one-line-on-crash "bt"
# Optional lldb argument to quit on error: -o quit