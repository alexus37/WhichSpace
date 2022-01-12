//
//  AppDelegate.swift
//  WhichSpace
//
//  Created by George on 27/10/2015.
//  Copyright © 2020 George Christou. All rights reserved.
//

import Cocoa
import Sparkle

@NSApplicationMain
@objc
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, SUUpdaterDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var application: NSApplication!
    @IBOutlet weak var workspace: NSWorkspace!
    @IBOutlet weak var updater: SUUpdater!

    let mainDisplay = "Main"
    let spacesMonitorFile = "~/Library/Preferences/com.apple.spaces.plist"

    let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let conn = _CGSDefaultConnection()

    static var darkModeEnabled = false

    fileprivate func configureApplication() {
        application = NSApplication.shared
        // Specifying `.Accessory` both hides the Dock icon and allows
        // the update dialog to take focus
        application.setActivationPolicy(.accessory)
    }

    fileprivate func configureObservers() {
        workspace = NSWorkspace.shared
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(AppDelegate.updateActiveSpaceNumber),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: workspace
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(updateDarkModeStatus(_:)),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(AppDelegate.updateActiveSpaceNumber),
            name: NSApplication.didUpdateNotification,
            object: nil
        )
    }

    fileprivate func configureMenuBarIcon() {
        updateDarkModeStatus()
        statusBarItem.button?.cell = StatusItemCell()
        statusBarItem.image = NSImage(named: "default") // This icon appears when switching spaces when cell length is variable width.
        statusBarItem.menu = statusMenu
    }

    fileprivate func configureSparkle() {
        updater = SUUpdater.shared()
        updater.delegate = self
        // Silently check for updates on launch
        updater.checkForUpdatesInBackground()
    }

    fileprivate func configureSpaceMonitor() {
        let fullPath = (spacesMonitorFile as NSString).expandingTildeInPath
        let queue = DispatchQueue.global(qos: .default)
        let fildes = open(fullPath.cString(using: String.Encoding.utf8)!, O_EVTONLY)
        if fildes == -1 {
            NSLog("Failed to open file: \(spacesMonitorFile)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fildes, eventMask: DispatchSource.FileSystemEvent.delete, queue: queue)

        source.setEventHandler { () -> Void in
            let flags = source.data.rawValue
            if (flags & DispatchSource.FileSystemEvent.delete.rawValue != 0) {
                source.cancel()
                self.updateActiveSpaceNumber()
                self.configureSpaceMonitor()
            }
        }

        source.setCancelHandler { () -> Void in
            close(fildes)
        }

        source.resume()
    }

    @objc func updateDarkModeStatus(_ sender: AnyObject? = nil) {
        let dictionary = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain);
        if let interfaceStyle = dictionary?["AppleInterfaceStyle"] as? NSString {
            AppDelegate.darkModeEnabled = interfaceStyle.localizedCaseInsensitiveContains("dark")
        } else {
            AppDelegate.darkModeEnabled = false
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        PFMoveToApplicationsFolderIfNecessary()
        configureApplication()
        configureObservers()
        configureMenuBarIcon()
        configureSparkle()
        configureSpaceMonitor()
        updateActiveSpaceNumber()
    }

    @objc func updateActiveSpaceNumber() {
        let displays = CGSCopyManagedDisplaySpaces(conn) as! [NSDictionary]
        let activeDisplay = CGSCopyActiveMenuBarDisplayIdentifier(conn) as! String
        
        var activeSpaceID = -1
        var curVisibleSpaceID = -1
        var prevSpaces = 1
        let sandwichAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12),
            NSAttributedString.Key.baselineOffset: NSNumber(value: 1.0)
        ]
        
        let result = NSMutableAttributedString(string: "", attributes: sandwichAttributes)
        
        for (displayIndex, d) in displays.enumerated() {
            let allSpaces: NSMutableArray = []
            
            guard
                let current = d["Current Space"] as? [String: Any],
                let spaces = d["Spaces"] as? [[String: Any]],
                let dispID = d["Display Identifier"] as? String
                else {
                    continue
            }

            switch dispID {
            case mainDisplay, activeDisplay:
                activeSpaceID = current["ManagedSpaceID"] as! Int
            default:
                break
            }
            
            // gather all spaces on current display
            for s in spaces {
                let isFullscreen = s["TileLayoutManager"] as? [String: Any] != nil
                if isFullscreen {
                    continue
                }
                allSpaces.add(s)
            }
            
            for (index, space) in allSpaces.enumerated() {
                let spaceUUID = (space as! NSDictionary)["uuid"] as! String
                if((current["uuid"] as! String) == spaceUUID) {
                    curVisibleSpaceID = prevSpaces + index
                }
                let spaceID = (space as! NSDictionary)["ManagedSpaceID"] as! Int
                if(activeSpaceID == spaceID) {
                    activeSpaceID = prevSpaces + index
                }
            }
            if(curVisibleSpaceID == -1) {
                result.append(NSMutableAttributedString(string: "fullscreen", attributes: sandwichAttributes))
            } else {
                let lhs = Array(prevSpaces..<curVisibleSpaceID).map { String($0) }.joined(separator: " ")
                        
                let rhs = curVisibleSpaceID != allSpaces.count + prevSpaces - 1
                    ? Array(curVisibleSpaceID + 1...(allSpaces.count + prevSpaces - 1)).map { String($0) }.joined(separator: " ")
                    : ""
                
                let formattedLHS = NSMutableAttributedString(string: lhs, attributes: sandwichAttributes)
                let formattedRHS = NSMutableAttributedString(string: rhs, attributes: sandwichAttributes)

                let boldAttributes = [
                    NSAttributedString.Key.font : NSFont.boldSystemFont(ofSize: 16),
                    NSAttributedString.Key.foregroundColor: curVisibleSpaceID == activeSpaceID ? NSColor.red: NSColor.green,
                ]
                
                let cnt = String(" \(curVisibleSpaceID) ")
                let formattedCNT = NSMutableAttributedString(string: cnt, attributes: boldAttributes)
                
                result.append(formattedLHS)
                result.append(formattedCNT)
                result.append(formattedRHS)
                
                if(displayIndex + 1 < displays.count) {
                    let splitAttributes = [
                        NSAttributedString.Key.font : NSFont.boldSystemFont(ofSize: 16),
                    ]
                    let formattedSplit = NSMutableAttributedString(string: String(" | "), attributes: splitAttributes)
                    result.append(formattedSplit)
                }
                prevSpaces += allSpaces.count
            }
        }

        
        DispatchQueue.main.async {
            self.statusBarItem.button?.attributedTitle = result
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        if let cell = statusBarItem.button?.cell as! StatusItemCell? {
            cell.isMenuVisible = true
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        if let cell = statusBarItem.button?.cell as! StatusItemCell? {
            cell.isMenuVisible = false
        }
    }
    @IBAction func checkForUpdatesClicked(_ sender: NSMenuItem) {
        updater.checkForUpdates(sender)
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
}
