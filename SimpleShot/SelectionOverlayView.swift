//
//  SelectionOverlayWindow.swift
//  SimpleShot
//
//  Created by momei on 2025/11/2.
//

import SwiftUI
import AppKit
import Combine

// MARK: - 选择窗口
class SelectionOverlayWindow: NSPanel {
    var selectionView: SelectionOverlayNSView?
    
    init() {
        // 确保窗口覆盖整个屏幕
        let screenRect = NSScreen.main?.frame ?? .zero
        
        super.init(
            contentRect: screenRect,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        // 强制设置窗口位置和尺寸为屏幕大小
        self.setFrame(screenRect, display: true)
        
        print("🪟 窗口初始化 - Frame: \(self.frame), Screen: \(screenRect)")
    }
}

// MARK: - NSView 实现的选择视图
class SelectionOverlayNSView: NSView {
    var startPoint: NSPoint?
    var currentPoint: NSPoint?
    var startScreenPoint: NSPoint?  // 屏幕坐标
    var currentScreenPoint: NSPoint?  // 屏幕坐标
    var onCapture: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 半透明背景
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()
        
        // 绘制选择框
        if let start = startPoint, let current = currentPoint {
            let rect = NSRect(
                x: min(start.x, current.x),
                y: min(start.y, current.y),
                width: abs(current.x - start.x),
                height: abs(current.y - start.y)
            )
            
            // 清除选择区域的背景
            NSColor.clear.setFill()
            rect.fill(using: .copy)
            
            // 绘制蓝色边框
            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 2
            path.stroke()
            
            // 绘制尺寸文本
            let sizeText = "\(Int(rect.width)) × \(Int(rect.height))"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.white
            ]
            let textSize = sizeText.size(withAttributes: attributes)
            let textRect = NSRect(
                x: rect.midX - textSize.width / 2,
                y: rect.minY - textSize.height - 10,
                width: textSize.width + 8,
                height: textSize.height + 4
            )
            
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4).fill()
            
            sizeText.draw(at: NSPoint(x: textRect.minX + 4, y: textRect.minY + 2), withAttributes: attributes)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = self.convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        
        // 保存鼠标的屏幕坐标（全局坐标）
        startScreenPoint = NSEvent.mouseLocation
        currentScreenPoint = startScreenPoint
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        currentPoint = self.convert(event.locationInWindow, from: nil)
        currentScreenPoint = NSEvent.mouseLocation
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let startScreen = startScreenPoint, 
              let currentScreen = currentScreenPoint else {
            onCancel?()
            return
        }
        
        // 使用屏幕全局坐标计算矩形
        // NSEvent.mouseLocation 返回的坐标系：左下角为原点，Y轴向上
        let minX = min(startScreen.x, currentScreen.x)
        let minY = min(startScreen.y, currentScreen.y)
        let maxX = max(startScreen.x, currentScreen.x)
        let maxY = max(startScreen.y, currentScreen.y)
        
        let width = maxX - minX
        let height = maxY - minY
        
        if width > 10 && height > 10 {
            // 获取所有屏幕中最大的 Y 值（用于坐标转换）
            var maxScreenY: CGFloat = 0
            for screen in NSScreen.screens {
                let screenMaxY = screen.frame.origin.y + screen.frame.height
                maxScreenY = max(maxScreenY, screenMaxY)
            }
            
            // 转换为屏幕坐标（左上角为原点）
            // NSEvent.mouseLocation 的 Y 坐标需要用整个显示空间的最大高度来翻转
            let screenRect = CGRect(
                x: minX,
                y: maxScreenY - maxY,  // 从全局坐标空间的顶部算起
                width: width,
                height: height
            )
            
            print("🔍 鼠标坐标 - Start: \(startScreen), End: \(currentScreen)")
            print("🔍 矩形范围 - X: [\(minX), \(maxX)], Y: [\(minY), \(maxY)]")
            print("🔍 显示空间最大高度: \(maxScreenY)")
            print("🔍 最终截图坐标 (左上角原点): \(screenRect)")
            
            onCapture?(screenRect)
        } else {
            onCancel?()
        }
        
        // 重置
        startPoint = nil
        currentPoint = nil
        startScreenPoint = nil
        currentScreenPoint = nil
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onCancel?()
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

// MARK: - 选择管理器
class SelectionManager {
    static let shared = SelectionManager()
    private var overlayWindow: SelectionOverlayWindow?
    
    private init() {}
    
    func showSelectionOverlay(onCapture: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 关闭已有窗口
            self.hideSelectionOverlay()
            
            let window = SelectionOverlayWindow()
            let selectionView = SelectionOverlayNSView(frame: window.frame)
            
            selectionView.onCapture = { [weak self] rect in
                self?.hideSelectionOverlay()
                // 短暂延迟确保窗口关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onCapture(rect)
                }
            }
            
            selectionView.onCancel = { [weak self] in
                self?.hideSelectionOverlay()
                onCancel()
            }
            
            window.selectionView = selectionView
            window.contentView = selectionView
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(selectionView)
            
            self.overlayWindow = window
        }
    }
    
    func hideSelectionOverlay() {
        if let window = overlayWindow {
            window.orderOut(nil)
            window.close()
            overlayWindow = nil
        }
    }
}
