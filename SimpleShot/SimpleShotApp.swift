//
//  SimpleShotApp.swift
//  SimpleShot
//
//  Created by momei on 2025/11/2.
//

import SwiftUI
import ScreenCaptureKit

@main
struct SimpleShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 防止关闭所有窗口时退出应用
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // 设置快捷键
        HotKeyManager.shared.installEventHandler()
        HotKeyManager.shared.registerHotKeys()
        
        // 请求屏幕录制权限
        requestScreenRecordingPermission()
        
        // 创建菜单栏图标
        setupMenuBar()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 关闭窗口时不退出应用
        return false
    }
    
    func requestScreenRecordingPermission() {
        Task {
            do {
                // 尝试获取屏幕权限
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            } catch {
                // 权限被拒绝
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "需要屏幕录制权限"
                    alert.informativeText = "SimpleShot 需要屏幕录制权限来进行截图。\n\n请在「系统设置 > 隐私与安全性 > 屏幕录制」中授予权限。"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "打开系统设置")
                    alert.addButton(withTitle: "稍后")
                    
                    if alert.runModal() == .alertFirstButtonReturn {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
    }
    
    func setupMenuBar() {
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "SimpleShot")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // 创建弹出窗口
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 500)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if let popover = popover {
                if popover.isShown {
                    popover.performClose(nil)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}
