//
//  HotKeyManager.swift
//  SimpleShot
//
//  Created by momei on 2025/11/2.
//

import Foundation
import Carbon
import AppKit

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeys: [Int32: EventHotKeyRef?] = [:]
    private var handlers: [Int32: () -> Void] = [:]
    
    private init() {}
    
    // MARK: - 注册快捷键
    func registerHotKeys() {
        // Cmd+Shift+3: 全屏截图
        registerHotKey(
            id: 1,
            keyCode: UInt32(kVK_ANSI_3),
            modifiers: UInt32(cmdKey | shiftKey),
            handler: {
                ScreenshotManager.shared.captureFullScreen()
            }
        )
        
        // Cmd+Shift+4: 区域截图
        registerHotKey(
            id: 2,
            keyCode: UInt32(kVK_ANSI_4),
            modifiers: UInt32(cmdKey | shiftKey),
            handler: {
                SelectionManager.shared.showSelectionOverlay(
                    onCapture: { rect in
                        ScreenshotManager.shared.captureArea(rect: rect)
                    },
                    onCancel: {
                        print("取消截图")
                    }
                )
            }
        )
    }
    
    // MARK: - 注册单个快捷键
    private func registerHotKey(id: Int32, keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(id), id: UInt32(id))
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            hotKeys[id] = hotKeyRef
            handlers[id] = handler
            print("快捷键注册成功: ID \(id)")
        } else {
            print("快捷键注册失败: ID \(id), 错误码: \(status)")
        }
    }
    
    // MARK: - 安装事件处理器
    func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (eventHandlerCall, event, userData) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let error = GetEventParameter(
                    event,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if error == noErr {
                    let manager = HotKeyManager.shared
                    if let handler = manager.handlers[Int32(hotKeyID.id)] {
                        DispatchQueue.main.async {
                            handler()
                        }
                    }
                }
                
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }
    
    // MARK: - 注销快捷键
    func unregisterHotKeys() {
        for (_, hotKeyRef) in hotKeys {
            if let ref = hotKeyRef {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeys.removeAll()
        handlers.removeAll()
    }
    
    deinit {
        unregisterHotKeys()
    }
}
