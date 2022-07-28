/*
 * AppDelegate.swift
 *
 * Copyright 2022 Robin Dinse
 *
 * This library is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation; either version 2.1 of the License, or (at your option)
 * any later version.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

import AppKit
import Cocoa

import Foundation
import AppKit
import ApplicationServices
import UserNotifications

/* The mechanism for warping the mouse was inspired by the Wine project:
 * https://source.winehq.org/git/wine.git/blob/HEAD:/dlls/winemac.drv/cocoa_cursorclipping.m
 * See also this answer:
 * https://stackoverflow.com/questions/40904830/
 */

let GITHUB_REPO = "rdinse/mousefilter"

extension CGPoint {
  func distanceTo(_ point: CGPoint) -> CGFloat {
    return sqrt(pow(self.x - point.x, 2) + pow(self.y - point.y, 2))
  }
}

struct WarpRecord {
  var timeBefore: CGEventTimestamp
  var timeAfter: CGEventTimestamp
  var from: CGPoint
  var to: CGPoint
  var dx: CGFloat
  var dy: CGFloat
}

class AppDelegate: NSObject, NSApplicationDelegate {
  var settingsWindow: NSWindow!
  var dotWindow: NSWindow!
  var statusItem: NSStatusItem!
  var defaults = UserDefaults.standard
  var selfPtr: Unmanaged<AppDelegate>!
  var eventTap: CFMachPort!
  var smoothingEnabled: Bool = true
  var smoothingEnabledItem: NSMenuItem!
  var synthesizedLocation: CGPoint = CGPoint.zero
  var filteredLocation: CGPoint = CGPoint(x: CGFloat.nan, y: CGFloat.nan)
  var warpRecords: [WarpRecord] = []
  var lastMovementTime: CGEventTimestamp = 0
  var hideTimer: Timer?
  

  var timebaseInfo = mach_timebase_info_data_t()
  func machAbsoluteToSeconds(_ t: UInt64 = mach_absolute_time()) -> Double {
    let ns = Double(t * UInt64(timebaseInfo.numer)) / Double(timebaseInfo.denom)
    return ns / 1.0e9;
  }


  /*
  func getActiveScreen() -> NSScreen {
    let mouseLocation = NSEvent.mouseLocation
    let screens = NSScreen.screens()
    for screen in screens {
      if screen.frame.contains(mouseLocation) {
        return screen
      }
    }
    return screens[0]
  }
  */

  // Add a optional parameter offcenter allowing the alert to be moved to the side.
  func runModal(message: String, information: String, alertStyle: NSAlert.Style,
    defaultButton: String, alternateButton: String? = nil,
    thirdButton: String? = nil, offcenter: Bool = false)
    -> NSApplication.ModalResponse {

    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = information
    alert.alertStyle = alertStyle
    alert.addButton(withTitle: defaultButton)
    if let alternateButton = alternateButton {
      alert.addButton(withTitle: alternateButton)
    }
    if let thirdButton = thirdButton {
      alert.addButton(withTitle: thirdButton)
    }
    if offcenter {
      let t = Timer.scheduledTimer(timeInterval: 0.1, target: self,
        selector: #selector(moveAlert), userInfo: alert, repeats: false)
      RunLoop.current.add(t, forMode: .common)
    }
    return alert.runModal()
  }

  @objc func moveAlert(timer: Timer) {
    let alert = timer.userInfo as! NSAlert
    var frame = alert.window.frame
    frame.origin.x += 500
    alert.window.setFrame(frame, display: true, animate: true)
  }


  func setupMenu() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    guard let icon = NSImage(named: "MenuIcon") else { return }
    let resizedIcon = NSImage(size: NSSize(width: 18, height: 18), flipped: false) {
      (dstRect) -> Bool in
      icon.draw(in: dstRect)
      return true
    }
    if let button = statusItem.button {
      button.image = resizedIcon
    }
    let menu = NSMenu()
    smoothingEnabledItem = NSMenuItem(title: "Enable Smoothing (F12)",
      action: #selector(AppDelegate.toggleSmoothing), keyEquivalent: "")
    smoothingEnabledItem.state = smoothingEnabled ? .on : .off
    menu.addItem(smoothingEnabledItem)
    menu.addItem(NSMenuItem(title: "Settings",
                            action: #selector(openSettings), keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "Go to MouseFilter on GitHub",
                            action: #selector(openDeveloperPage), keyEquivalent: ""))
    menu.addItem(NSMenuItem(title: "Check for Updates",
                            action: #selector(checkForUpdates), keyEquivalent: ""))
    menu.addItem(NSMenuItem(title: "Uninstall MouseFilter",
                            action: #selector(uninstall), keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "Quit",
                            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    statusItem.menu = menu
  }

  @objc func toggleSmoothing() {
    smoothingEnabled = !smoothingEnabled
    smoothingEnabledItem.state = smoothingEnabled ? .on : .off
    if smoothingEnabled {
      filteredLocation = NSEvent.mouseLocation
      CGAssociateMouseAndMouseCursorPosition(0)
      showNotificationWindow(withText: "Mouse smoothing enabled")
    } else {
      CGAssociateMouseAndMouseCursorPosition(1)
      showNotificationWindow(withText: "Mouse smoothing disabled")
    }
  }

  @objc func openSettings() {
    settingsWindow.makeKeyAndOrderFront(nil)
    settingsWindow.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc func openDeveloperPage() {
    NSWorkspace.shared.open(URL(string: "https://github.com/\(GITHUB_REPO)")!)
  }
  

  func setupSettingsWindow() {
    settingsWindow = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 90),
      styleMask: [.closable, .titled],
      backing: .buffered, defer: false)
    settingsWindow.isReleasedWhenClosed = false
    settingsWindow.center()
    settingsWindow.title = "MouseFilter Settings"

    defaults.register(
        defaults: [
            "smoothing": 0.75,
            "rubberbanding": 1400,
            "showDot": true,
            "autoUpdate": true
        ]
    )
    
    let smoothing = defaults.double(forKey: "smoothing")
    let smoothingSlider = NSSlider(value: smoothing, minValue: 0, maxValue: 0.90,
      target: self, action: #selector(didChangeSmoothing))
    smoothingSlider.frame = NSRect(x: 0, y: 0, width: 240, height: 20)
    smoothingSlider.autoresizingMask = [.width]
    smoothingSlider.isContinuous = true

    let rubberbanding = defaults.double(forKey: "rubberbanding")
    let rubberbandingSlider = NSSlider(value: rubberbanding, minValue: 0, maxValue: 1800,
      target: self, action: #selector(didChangeRubberbanding))
    rubberbandingSlider.frame = NSRect(x: 0, y: 0, width: 240, height: 20)
    rubberbandingSlider.autoresizingMask = [.width]
    rubberbandingSlider.isContinuous = true
    
    let showDot = defaults.bool(forKey: "showDot")
    let showDotCheckbox = NSButton(checkboxWithTitle:"Show dot",
      target: self, action: #selector(didChangeShowDot))
    showDotCheckbox.state = showDot ? NSControl.StateValue.on
      : NSControl.StateValue.off

    let autoUpdate = defaults.bool(forKey: "autoUpdate")
    let autoUpdateCheckbox = NSButton(checkboxWithTitle:"Auto update",
      target: self, action: #selector(didChangeAutoUpdate))
    autoUpdateCheckbox.state = autoUpdate ? NSControl.StateValue.on
      : NSControl.StateValue.off
    
    // Add a grid with labels and inputs.
    let r = settingsWindow.contentRect(forFrameRect: settingsWindow.frame)
    let grid = NSGridView(frame: NSRect(x: 10, y: 10, width: r.width - 20, height: r.height - 20))
    grid.addRow(with: [NSTextField(labelWithString: "Smoothing"), smoothingSlider])
    grid.addRow(with: [NSTextField(labelWithString: "Rubber banding"), rubberbandingSlider])
    grid.addRow(with: [showDotCheckbox, autoUpdateCheckbox])
    
    settingsWindow.contentView?.addSubview(grid)
  }
  
  @objc func didChangeSmoothing(sender: NSSlider) {
    defaults.set(sender.doubleValue, forKey: "smoothing")
  }

  @objc func didChangeRubberbanding(sender: NSSlider) {
    defaults.set(sender.doubleValue, forKey: "rubberbanding")
  }

  @objc func didChangeShowDot(sender: NSButton) {
    defaults.set(sender.state == NSControl.StateValue.on, forKey: "showDot")
  }

  @objc func didChangeAutoUpdate(sender: NSButton) {
    defaults.set(sender.state == NSControl.StateValue.on, forKey: "autoUpdate")
  }
  
  let dotSize = CGSize(width: 5, height: 5)
  func setupDotWindow() {
    let dot = NSImage(size: dotSize, flipped: false) {
      (dstRect) -> Bool in
      let ctx = NSGraphicsContext.current!.cgContext
      ctx.setFillColor(NSColor.red.cgColor)
      ctx.fillEllipse(in: dstRect)
      return true
    }
    let imageView = NSImageView(frame: NSRect(origin: .zero, size: dot.size))
    imageView.image = dot
    
    dotWindow = NSWindow(
      contentRect: NSRect(origin: .zero, size: dot.size),
      styleMask: [.borderless],
      backing: .buffered, defer: false)
    dotWindow.isReleasedWhenClosed = false
    dotWindow.isOpaque = false
    dotWindow.isMovableByWindowBackground = false
    dotWindow.backgroundColor = NSColor.clear
    dotWindow.level = .popUpMenu
    dotWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
    dotWindow.ignoresMouseEvents = true
    dotWindow.titleVisibility = .hidden
    dotWindow.titlebarAppearsTransparent = true
    dotWindow.styleMask.insert(.fullSizeContentView)
    
    dotWindow.contentView = NSView(frame: dotWindow.contentRect(forFrameRect: dotWindow.frame))
    dotWindow.contentView?.addSubview(imageView)
    dotWindow.contentView?.wantsLayer = true
    dotWindow.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    dotWindow.makeKeyAndOrderFront(self)

    moveDotWindowToCGPoint(NSEvent.mouseLocation)
  }


  var notificationWindow: NSWindow!
  var notificationWindowLabel: NSTextField!
  func setupNotificationWindow() {
    // Setup a borderless, titleless window that has a single label.
    notificationWindow = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 450, height: 60),
      styleMask: [.borderless],
      backing: .buffered, defer: false)
    notificationWindow.isReleasedWhenClosed = false
    notificationWindow.isOpaque = false
    notificationWindow.isMovableByWindowBackground = false
    notificationWindow.backgroundColor = NSColor.clear
    notificationWindow.level = .popUpMenu
    notificationWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
    notificationWindow.ignoresMouseEvents = true
    notificationWindow.titleVisibility = .hidden
    notificationWindow.titlebarAppearsTransparent = true
    notificationWindow.styleMask.insert(.fullSizeContentView)
    notificationWindow.center()
    notificationWindow.contentView?.wantsLayer = true
    notificationWindow.contentView?.layer?.opacity = 0

    let blurView = NSVisualEffectView(frame: notificationWindow.contentView!.bounds)
    blurView.blendingMode = .behindWindow
    blurView.material = .fullScreenUI
    blurView.state = .active
    notificationWindow.contentView?.addSubview(blurView)

    // A grey transparent rounded rectangle as background of the window.
    let bg = NSImage(size: notificationWindow.frame.size, flipped: false) {
      (dstRect) -> Bool in
      let ctx = NSGraphicsContext.current!.cgContext
      ctx.setFillColor(NSColor.black.withAlphaComponent(0.3).cgColor)
      // The rounded rectangle is drawn with a radius of 10.0 using CGMutablePath
      let path = CGMutablePath()
      path.addRoundedRect(in: dstRect, cornerWidth: 10.0, cornerHeight: 10.0)
      ctx.addPath(path)
      ctx.fillPath()
      return true
    }
    let imageView = NSImageView(frame: NSRect(origin: .zero, size: bg.size))
    imageView.image = bg
    notificationWindow.contentView?.addSubview(imageView)
    notificationWindow.contentView?.wantsLayer = true
    notificationWindow.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

    notificationWindowLabel = NSTextField(labelWithString: "")
    notificationWindowLabel.frame = NSRect(x: 0, y: 0, width: bg.size.width,
      height: bg.size.height - 10)
    notificationWindowLabel.isBezeled = false
    notificationWindowLabel.drawsBackground = false
    notificationWindowLabel.isEditable = false
    notificationWindowLabel.isSelectable = false
    notificationWindowLabel.alignment = .center
    notificationWindowLabel.font = NSFont.systemFont(ofSize: 35)
    notificationWindowLabel.textColor = NSColor.white.withAlphaComponent(0.99)
    notificationWindowLabel.cell?.usesSingleLineMode = false
    notificationWindowLabel.cell?.alignment = .center

    // Add label to window.
    notificationWindow.contentView?.addSubview(notificationWindowLabel)
  }


  func showNotificationWindow(withText text: String) {
    notificationWindowLabel.stringValue = text
    notificationWindow.contentView?.layer?.opacity = 0
    notificationWindow.contentView?.layer?.removeAllAnimations()
    notificationWindow.makeKeyAndOrderFront(self)

    let duration = 2.0
    let anim = CAKeyframeAnimation(keyPath: "opacity")
    anim.values = [0.0, 1.0, 1.0, 0.0]
    anim.keyTimes = [0.0, 0.2, 0.7, 1.0]
    anim.duration = duration
    anim.isRemovedOnCompletion = true
    notificationWindow.contentView?.layer?.add(anim, forKey: "opacity")
    
    // Hide the window when the animation is done.
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
      // Make sure no other animation was added in the meantime.
      if self.notificationWindow.contentView?.layer?.animationKeys()?.count ?? 0 == 0 {
        self.notificationWindow.orderOut(self)
      }
    }
  }


  func moveDotWindowToCGPoint(_ point: CGPoint) {
    // Convert the point to the screen coordinate system
    let screen = NSScreen.main!
    var point = flippedMouseLocation(point)
    point = NSPoint(x: point.x - screen.frame.origin.x - dotSize.width / 2,
      y: point.y - screen.frame.origin.y - dotSize.height / 2)
    dotWindow.setFrameOrigin(point)
  }


  func flippedMouseLocation(_ location: CGPoint) -> CGPoint {
    return CGPoint(x: location.x, y: NSScreen.main!.frame.height - location.y)
  }
  
  
  func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType,
    event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    
    if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
      CGEvent.tapEnable(tap: eventTap, enable: true)
      return Unmanaged.passRetained(event)
    }

    if type == .keyDown {  // F12 key, ignore repeats.
      if event.getIntegerValueField(CGEventField.keyboardEventKeycode) == 111
        && event.getIntegerValueField(CGEventField.keyboardEventAutorepeat) == 0 {

        toggleSmoothing()
        return nil
      }
      return Unmanaged.passRetained(event)
    }

    if !smoothingEnabled {
      return Unmanaged.passRetained(event)
    }

    if type == .mouseMoved
      || type == .leftMouseDragged
      || type == .rightMouseDragged
      || type == .otherMouseDragged {

      let eventTime = event.timestamp
      let eventLocation = event.location
      var deltaX = Double(event.getIntegerValueField(
        CGEventField.mouseEventDeltaX))
      var deltaY = Double(event.getIntegerValueField(
        CGEventField.mouseEventDeltaY))
      
      var corrDeltaX = 0.0;
      var corrDeltaY = 0.0;
      for warpRecord in warpRecords {
        if warpRecord.timeAfter < eventTime
            || (warpRecord.timeBefore <= eventTime
                && eventLocation.equalTo(warpRecord.to)) {

          deltaX -= warpRecord.dx
          deltaY -= warpRecord.dy
          corrDeltaX += warpRecord.dx
          corrDeltaY += warpRecord.dy
          warpRecords.removeFirst()
        } else {
          break
        }
      }

      // If mouse has not moved briefly, set the synthesized location to the
      // cursor location.  This prevents the mouse from drifting away after the
      // synthesized cursor has been moved far away.
      if machAbsoluteToSeconds(eventTime - lastMovementTime) > 0.2 {
        synthesizedLocation = eventLocation
      }
      
      synthesizedLocation.x += deltaX
      synthesizedLocation.y += deltaY

      // Clip with screen bounds (TODO: support multiple screens)
      synthesizedLocation.x = min(max(synthesizedLocation.x, -100),
        NSScreen.main!.frame.width + 100)
      synthesizedLocation.y = min(max(synthesizedLocation.y, -100),
        NSScreen.main!.frame.height + 100)

      // Filter the synthesized location.
      let a = defaults.double(forKey: "smoothing")
      // Compute mixing weight with high resolution near 1.0.
      var w = 1 - pow(1 - a, 3)

      // Attenuate proportial to distance between filtered and synthesized.
      let r = 2000 - defaults.double(forKey: "rubberbanding")
      let d = filteredLocation.distanceTo(synthesizedLocation)
      w *= 1 - 0.1 * exp(-1 / pow(d / r, 2))
      
      let filteredLocationBefore = filteredLocation
      filteredLocation.x = w * filteredLocation.x + (1 - w) * synthesizedLocation.x
      filteredLocation.y = w * filteredLocation.y + (1 - w) * synthesizedLocation.y

      let filteredDeltaX = filteredLocation.x - filteredLocationBefore.x
      let filteredDeltaY = filteredLocation.y - filteredLocationBefore.y

      // TODO: check if deltas have changed at all
      event.setDoubleValueField(CGEventField.mouseEventDeltaX,
        value: filteredDeltaX)
      event.setDoubleValueField(CGEventField.mouseEventDeltaY,
        value: filteredDeltaY)
    
      if !eventLocation.equalTo(filteredLocation) {
        let timeBefore = { mach_absolute_time() }()
        CGWarpMouseCursorPosition(filteredLocation)
        let timeAfter = { mach_absolute_time() }()

        warpRecords.append(WarpRecord(
          timeBefore: timeBefore,
          timeAfter: timeAfter,
          from: eventLocation,
          to: filteredLocation,
          dx: filteredDeltaX,
          dy: filteredDeltaY))

        event.location = filteredLocation
      }

      lastMovementTime = eventTime

      // Move dot to the synthesized location if enabled.
      let showDot = defaults.bool(forKey: "showDot")
      if showDot {
        if !dotWindow.occlusionState.contains(.visible) {
          dotWindow.makeKeyAndOrderFront(self)
        }
        moveDotWindowToCGPoint(synthesizedLocation)
        
        // Hide the dot 0.2 seconds after the last movement using hideTimer.
        if hideTimer != nil {
          hideTimer!.invalidate()
        }
        hideTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self,
          selector: #selector(hideDotWindow), userInfo: nil, repeats: false)
      } else if dotWindow.occlusionState.contains(.visible) {
        hideDotWindow()
      }
    }
  
    return Unmanaged.passRetained(event)
  }
  
  @objc func hideDotWindow() {
    dotWindow.orderOut(self)
  }


  func relaunch(withPath path: String? = nil) {
    let path = path ?? Bundle.main.bundleURL.path
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = [path, "--args", "--show"]
    task.launch()
    NSApplication.shared.terminate(self)
  }


  func runBash(_ source: String, elevated: Bool = false) -> String? {
    let source = source.replacingOccurrences(of: "\"", with: "\\\"")
    guard let script = NSAppleScript(source: "do shell script \"\(source)\" "
      + (elevated ? " with administrator privileges" : "")) else { return nil }
    var error: NSDictionary?
    let result = script.executeAndReturnError(&error)
    switch (error?[NSAppleScript.errorNumber] as? Int16) ?? 0 {
    case -128:
      NSLog("User cancelled password prompt.")
      return nil
    case 0:
      return result.stringValue!
    default:
      let errorMsg = error![NSAppleScript.errorMessage] as! String
      NSLog("AppleScript error: \(errorMsg)")
      return nil
    }
  }


  func installAppAndRelaunch(withPath path: String) {
    NSLog("Installing from \(path)")
    let to = "/Applications/MouseFilter.app"
    let from = path.replacingOccurrences(of: "'", with: "\\'")
    let pid = NSRunningApplication.current.processIdentifier
    guard runBash(
      "(ps -ax | grep MouseFilter | grep -v grep | awk '{print $1}' | "
      + "grep -vx \(pid) | xargs kill -9 || true) && rm -rf '\(to)' && "
      + "cp -pR '\(from)' '\(to)' && (rm -rf '\(from)' || true) && "
      + "xattr -d -r com.apple.quarantine '\(to)'", elevated: true) != nil
      else {
      NSApplication.shared.terminate(self)
      return
    }
    relaunch(withPath: to)
  }


  @objc func uninstall() {
    let response = runModal(message: "Are you sure you want to uninstall MouseFilter?",
      information: "This will remove all of your settings and uninstall the app.",
      alertStyle: .informational, defaultButton: "Uninstall", alternateButton: "Cancel")
    if response == .alertSecondButtonReturn { return }
    guard runBash(
      "rm -f ~/Library/Preferences/\(Bundle.main.bundleIdentifier!).plist && "
      + "rm -rf /Applications/MouseFilter.app", elevated: true) != nil else { return }
    registerLaunchDaemon(unregister: true)
    NSApplication.shared.terminate(self)
  }


  func getCodeSigningId(bundle: Bundle) -> String? {
    // View cert: openssl x509 -inform DER -in codesign0 -text 
    guard let codeSigningId = runBash(
      "cd /tmp && codesign --verify --deep '\(bundle.bundlePath)' && "
      + "codesign -dvvvv --extract-certificates '\(bundle.bundlePath)' && "
      + "shasum -a 256 codesign0 && rm -f codesign0") else { return nil }
    return codeSigningId
  }


  @objc func checkForUpdates(_ sender: AnyObject? = nil) {
    NSLog("Checking for update...")
    var url = URL(string: "https://github.com/\(GITHUB_REPO)/releases/latest")!
    guard let version = runBash("curl -s -L -I -o /dev/null -w '%{url_effective}' "
     + "\(url) | xargs basename | sed -e 's/[^0-9.]//g'")
     else {
      if let _ = sender as? NSMenuItem {
        let _ = runModal(message: "Could not check for updates.",
          information: "Please check your internet connection.",
          alertStyle: .informational, defaultButton: "OK", alternateButton: nil)
      }
      return
    }
    if version.components(separatedBy: ".").count != 3 { return }
    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
      as! String
    if version != currentVersion {
      let r1 = runModal(message: "A new version of MouseFilter is available.",
        information: "You have version \(currentVersion) and the new version "
          + "is \(version).",
        alertStyle: .informational, defaultButton: "Update",
        alternateButton: "Cancel")
      if r1 == .alertSecondButtonReturn { return }

      url = url.appendingPathComponent("/download/MouseFilter.zip")
      let r2 = runBash("rm -rf /tmp/MouseFilter.app && "  
        + "curl -s -L -o /tmp/MouseFilter.zip \"\(url)\" && "
        + "unzip -o /tmp/MouseFilter.zip -d /tmp/ && rm /tmp/MouseFilter.zip")
      if r2 == nil { return }

      // Check whether the code signature matches the current one and is valid.
      NSLog("Checking code signature...")
      guard let newBundle = Bundle(path: "/tmp/MouseFilter.app") else { return }
      let c1 = getCodeSigningId(bundle: Bundle.main)
      let c2 = getCodeSigningId(bundle: newBundle)
      print("Signatures: \(c1 ?? ""), \(c2 ?? "")")
      if c1 == nil || c2 == nil || c1 == "" || c2 == "" { return }
      if c1 != c2 {
        let r = runModal(message: "The code signature of the new version does "
            + "not match the current one.",
          information: "Please visit the developer page to obtain a new "
            + "version of MouseFilter.",
          alertStyle: .informational, defaultButton: "Open developer page",
          alternateButton: "Cancel")
        if r == .alertSecondButtonReturn { return }
        openDeveloperPage()
        return
      }

      installAppAndRelaunch(withPath: "/tmp/MouseFilter.app")
    } else if let sender = sender as? NSMenuItem {
      let _ = runModal(message: "MouseFilter is up to date.",
        information: "You have version \(currentVersion).",
        alertStyle: .informational, defaultButton: "OK",
        alternateButton: nil)
    }
  }


  func registerLaunchDaemon(unregister: Bool = false) {
    let plist = NSDictionary(dictionary: [
      "Label": Bundle.main.bundleIdentifier!,
      "ProgramArguments": ["/usr/bin/open", "-n", "-a", "MouseFilter"],
      "RunAtLoad": true,
      "StartInterval": 1.0
    ])
    let plistPath = NSHomeDirectory()
      + "/Library/LaunchDaemons/\(Bundle.main.bundleIdentifier!).plist"
    if !FileManager.default.fileExists(atPath: plistPath) {
      if runBash("mkdir -p ~/Library/LaunchDaemons") == nil { return }
      plist.write(toFile: plistPath, atomically: true)
    } else if unregister {
      try! FileManager.default.removeItem(atPath: plistPath)
    }
    let _ = runBash("launchctl \(unregister ? "bootout" : "bootstrap") "
      + "gui/$(id -u) \(plistPath)")
  }


  @objc func pollTrust() {
    if (AXIsProcessTrusted()) {
      relaunch()
    }
  }

  @objc func checkTrust() {
    if (!AXIsProcessTrusted()) {
      NSApplication.shared.terminate(self)
    }
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    NSLog("Launching...")

    // Initialize timebase info
    mach_timebase_info(&timebaseInfo)

    // Fix lack of focus after security warning.
    if !NSApp.isActive {
      NSApp.activate(ignoringOtherApps: true)
    }
    
    NSLog("Checking if the app runs in a sandbox...")
    let environment = ProcessInfo.processInfo.environment
    if environment["APP_SANDBOX_CONTAINER_ID"] != nil {
      let r = runModal(message: "This app is running in a sandbox.",
        information: "This app does not work running in a sandbox.",
        alertStyle: .warning, defaultButton: "Quit",
        alternateButton: "Start anyway")
      if r == .alertFirstButtonReturn {
        NSApplication.shared.terminate(self)
      }
    }

#if !DEBUG
    let path = Bundle.main.bundleURL.path
    NSLog("Checking installation path: \(path)")
    if !path.starts(with: "/Applications/") {
      NSLog("Copying app to Applications folder...")
      let response = runModal(
        message: "This app needs to be moved to the Applications folder.",
        information: "Please click OK and then enter your password.",
        alertStyle: .warning, defaultButton: "OK", alternateButton: "Cancel")
      if response == .alertSecondButtonReturn {
        NSApplication.shared.terminate(self)
      }
      installAppAndRelaunch(withPath: path)
    }

    if defaults.bool(forKey: "checkForUpdates") {
      checkForUpdates()
    }
    registerLaunchDaemon()
#endif

    // Prompt user to trust the app.
    let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
      as NSString
    if (!AXIsProcessTrustedWithOptions([checkOptPrompt: true] as CFDictionary?)) {
      NSLog("Not trusted. Prompting user...")
      let timer = Timer.scheduledTimer(timeInterval: 1.0, target: self,
        selector: #selector(pollTrust), userInfo: nil, repeats: true)
      RunLoop.current.add(timer, forMode: .common)
      let response = runModal(
        message: "MouseFilter needs to be trusted.",
        information: "Please click \"Open System Preferences\" in the window "
          + "to the left, then click the lock icon, enter your password, and "
          + "then checkmark the MouseFilter app.  If that doesn't work, please "
          + "click \"Reset permissions\" and restart your Mac.",
        alertStyle: .warning, defaultButton: "I've done that",
          alternateButton: "Cancel", thirdButton: "Reset permissions",
          offcenter: true)
      if (response == .alertThirdButtonReturn) {
        let _ = runBash(
          "sudo tccutil reset Accessibility \(Bundle.main.bundleIdentifier!)",
          elevated: true)
      }
      NSApplication.shared.terminate(self)
    }
    
    // Periodically check if app is still trusted.
    let timer = Timer.scheduledTimer(timeInterval: 10.0, target: self,
      selector: #selector(checkTrust), userInfo: nil, repeats: true)
    RunLoop.current.add(timer, forMode: .common)

    NSLog("Checking if the app runs as root...")
    if ProcessInfo.processInfo.environment["_"] == "/usr/bin/sudo" {
      let _ = runModal(message: "This app is running as root.",
        information: "This app does not work running as root.",
        alertStyle: .warning, defaultButton: "Quit")
      NSApplication.shared.terminate(self)
    }

    // The application does not appear in the Dock and does not have a menu bar.
    // NSApp.setActivationPolicy(.accessory)
    
    // Hide application
    // NSApp.hide(self)

    setupNotificationWindow()
    setupSettingsWindow()
    setupDotWindow()
    setupMenu()

    // Setup event tap.
    let eventTypes = [
      CGEventType.leftMouseDown,
      CGEventType.leftMouseUp,
      CGEventType.rightMouseDown,
      CGEventType.rightMouseUp,
      CGEventType.mouseMoved,
      CGEventType.leftMouseDragged,
      CGEventType.rightMouseDragged,
      CGEventType.otherMouseDown,
      CGEventType.otherMouseUp,
      CGEventType.otherMouseDragged,
      CGEventType.scrollWheel,
      CGEventType.keyDown,
      CGEventType.keyUp
    ]
    let eventMask: CGEventMask = eventTypes.reduce(0) { $0 | 1 << $1.rawValue }

    // See: https://stackoverflow.com/questions/33260808/
    selfPtr = Unmanaged.passRetained(self)
    eventTap = CGEvent.tapCreate(
      tap: CGEventTapLocation.cghidEventTap,
      // TODO: use kCGAnnotatedSessionEventTap to be able to tell which process
      // the event is meant for (for blacklisting).
      place: CGEventTapPlacement.headInsertEventTap,
      options: CGEventTapOptions.defaultTap,
      eventsOfInterest: eventMask,
      callback: { proxy, type, event, refcon in
        let mySelf = Unmanaged<AppDelegate>.fromOpaque(refcon!)
          .takeUnretainedValue()
        return mySelf.eventTapCallback(proxy: proxy, type: type, event: event,
          refcon: refcon)
      },
      userInfo: selfPtr.toOpaque())!
    
    if (eventTap == nil) {
      print("Failed to create event tap.")
      NSApplication.shared.terminate(self)
    }

    filteredLocation = NSEvent.mouseLocation
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    CGAssociateMouseAndMouseCursorPosition(0)
    CFRunLoopRun()
  }
}
