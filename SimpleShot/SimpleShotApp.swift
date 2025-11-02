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
        MenuBarExtra("SimpleShot", systemImage: "camera.viewfinder") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    static let shared = AppDelegate()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置应用为菜单栏应用（当最后一个窗口关闭时不退出）
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // 设置快捷键
        HotKeyManager.shared.installEventHandler()
        HotKeyManager.shared.registerHotKeys()
        
        // 请求屏幕录制权限
        requestScreenRecordingPermission()
        
        // 初始化菜单栏
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
        // MenuBarExtra 已处理状态栏设置
        // 这个方法现在可以为空或用于其他初始化
    }
    
    // 隐藏菜单栏窗口
    func hideMenuBarWindow() {
        DispatchQueue.main.async {
            // 再延迟0.1秒确保系统完全接收了剪贴板数据
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 找到 MenuBarExtra 创建的窗口并隐藏
                for window in NSApplication.shared.windows {
                    if window.title == "SimpleShot" {
                        window.orderOut(nil)
                        break
                    }
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
