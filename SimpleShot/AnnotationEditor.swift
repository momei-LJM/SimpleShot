//
//  AnnotationEditor.swift
//  SimpleShot
//
//  Created by momei on 2025/11/2.
//

import SwiftUI
import AppKit

// MARK: - 标注工具类型
enum AnnotationTool {
    case rectangle
    case circle
    case line
    case arrow
    case pointer
}

// MARK: - 标注元素数据
struct AnnotationElement: Identifiable {
    let id = UUID()
    var type: AnnotationType
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: NSColor = NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
    var lineWidth: CGFloat = 2.0
    
    enum AnnotationType {
        case rectangle
        case circle
        case line
        case arrow
    }
}

// MARK: - 标注编辑器窗口
class AnnotationEditorWindow: NSWindow {
    static var sharedEditor: AnnotationEditorWindow?
    
    var canvasView: AnnotationCanvasView?
    var onSave: ((NSImage) -> Void)?
    var onCancel: (() -> Void)?
    
    static func show(with image: NSImage, onSave: @escaping (NSImage) -> Void, onCancel: @escaping () -> Void) {
        // 如果已有编辑器打开，关闭它
        if let existing = sharedEditor {
            existing.close()
        }
        
        let window = AnnotationEditorWindow(image: image)
        window.onSave = onSave
        window.onCancel = onCancel
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        sharedEditor = window
    }
    
    init(image: NSImage) {
        let frame = NSRect(x: 0, y: 0, width: 1100, height: 750)
        super.init(contentRect: frame, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        
        self.title = "截图标注编辑器"
        self.isReleasedWhenClosed = true
        self.minSize = NSSize(width: 600, height: 400)
        
        // 创建主容器
        let containerView = NSView(frame: frame)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // 左侧工具栏
        let toolbar = createToolbar()
        containerView.addSubview(toolbar)
        
        // 右侧画布
        let canvas = AnnotationCanvasView(image: image)
        containerView.addSubview(canvas)
        self.canvasView = canvas
        
        // 底部按钮栏
        let buttonBar = createButtonBar()
        containerView.addSubview(buttonBar)
        
        // 布局
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        canvas.translatesAutoresizingMaskIntoConstraints = false
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            toolbar.topAnchor.constraint(equalTo: containerView.topAnchor),
            toolbar.bottomAnchor.constraint(equalTo: buttonBar.topAnchor),
            toolbar.widthAnchor.constraint(equalToConstant: 80),
            
            canvas.leadingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: containerView.topAnchor),
            canvas.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: buttonBar.topAnchor),
            
            buttonBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            buttonBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            buttonBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            buttonBar.heightAnchor.constraint(equalToConstant: 50),
        ])
        
        self.contentView = containerView
        self.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createToolbar() -> NSView {
        let toolbar = NSView()
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0).cgColor
        
        var lastView: NSView?
        let tools: [(String, AnnotationTool)] = [
            ("rectangle.dashed", .rectangle),
            ("circle", .circle),
            ("line.diagonal", .line),
            ("arrow.up.right", .arrow),
            ("arrow.up.left.and.arrow.down.right", .pointer)
        ]
        
        for (icon, tool) in tools {
            let button = createToolButton(icon: icon, tag: tool)
            button.translatesAutoresizingMaskIntoConstraints = false
            toolbar.addSubview(button)
            
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 60),
                button.heightAnchor.constraint(equalToConstant: 50),
                button.centerXAnchor.constraint(equalTo: toolbar.centerXAnchor),
            ])
            
            if let last = lastView {
                button.topAnchor.constraint(equalTo: last.bottomAnchor, constant: 8).isActive = true
            } else {
                button.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 20).isActive = true
            }
            
            lastView = button
        }
        
        return toolbar
    }
    
    private func createToolButton(icon: String, tag: AnnotationTool) -> NSButton {
        let button = NSButton()
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        button.bezelStyle = .texturedRounded
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0).cgColor
        button.contentTintColor = NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
        
        button.target = self
        button.action = #selector(selectTool(_:))
        button.tag = toolToTag(tag)
        
        return button
    }
    
    private func createButtonBar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0).cgColor
        
        // Undo 按钮
        let undoButton = NSButton(title: "撤销", target: self, action: #selector(undoAction))
        undoButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(undoButton)
        
        // Clear 按钮
        let clearButton = NSButton(title: "清除", target: self, action: #selector(clearAction))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(clearButton)
        
        // 取消按钮
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelAction))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(cancelButton)
        
        // 保存按钮
        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveAction))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            undoButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            undoButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            
            clearButton.leadingAnchor.constraint(equalTo: undoButton.trailingAnchor, constant: 8),
            clearButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            
            cancelButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -100),
            cancelButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            
            saveButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            saveButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 80),
        ])
        
        return bar
    }
    
    @objc func selectTool(_ sender: NSButton) {
        let tool = tagToTool(sender.tag)
        canvasView?.setCurrentTool(tool)
    }
    
    @objc func undoAction() {
        canvasView?.undo()
    }
    
    @objc func clearAction() {
        canvasView?.clear()
    }
    
    @objc func cancelAction() {
        onCancel?()
        self.close()
    }
    
    @objc func saveAction() {
        guard let image = canvasView?.getAnnotatedImage() else { return }
        onSave?(image)
        self.close()
    }
    
    private func toolToTag(_ tool: AnnotationTool) -> Int {
        switch tool {
        case .rectangle: return 0
        case .circle: return 1
        case .line: return 2
        case .arrow: return 3
        case .pointer: return 4
        }
    }
    
    private func tagToTool(_ tag: Int) -> AnnotationTool {
        switch tag {
        case 0: return .rectangle
        case 1: return .circle
        case 2: return .line
        case 3: return .arrow
        case 4: return .pointer
        default: return .rectangle
        }
    }
}

// MARK: - 窗口代理
extension AnnotationEditorWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        AnnotationEditorWindow.sharedEditor = nil
    }
}

// MARK: - 标注画布视图
class AnnotationCanvasView: NSView {
    private let image: NSImage
    private var annotations: [AnnotationElement] = []
    private var currentTool: AnnotationTool = .rectangle
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDrawing = false
    
    private let primaryColor = NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
    private var imageDrawRect: CGRect = .zero
    
    init(image: NSImage) {
        self.image = image
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.white.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setCurrentTool(_ tool: AnnotationTool) {
        currentTool = tool
    }
    
    func undo() {
        if !annotations.isEmpty {
            annotations.removeLast()
            needsDisplay = true
        }
    }
    
    func clear() {
        annotations.removeAll()
        needsDisplay = true
    }
    
    func getAnnotatedImage() -> NSImage {
        let size = image.size
        let resultImage = NSImage(size: size)
        
        resultImage.lockFocus()
        
        // 绘制原始图片
        image.draw(at: NSPoint.zero, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1.0)
        
        // 绘制所有标注
        for annotation in annotations {
            drawAnnotationOnImage(annotation)
        }
        
        resultImage.unlockFocus()
        
        return resultImage
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 绘制图片
        let imageSize = image.size
        let viewSize = self.bounds.size
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        imageDrawRect = CGRect(
            x: (viewSize.width - scaledSize.width) / 2,
            y: (viewSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        image.draw(in: imageDrawRect)
        
        // 绘制所有标注
        for annotation in annotations {
            drawAnnotationInView(annotation, scale: scale)
        }
        
        // 绘制当前正在绘制的标注
        if let start = startPoint, let current = currentPoint {
            drawCurrentAnnotationInView(start: start, end: current, scale: scale)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = self.convert(event.locationInWindow, from: nil)
        isDrawing = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        currentPoint = self.convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let start = startPoint, let current = currentPoint else {
            isDrawing = false
            return
        }
        
        // 转换坐标到图像坐标系
        let imageSize = image.size
        let viewSize = self.bounds.size
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        
        let startImagePoint = CGPoint(
            x: (start.x - imageDrawRect.origin.x) / scale,
            y: imageSize.height - (start.y - imageDrawRect.origin.y) / scale
        )
        let endImagePoint = CGPoint(
            x: (current.x - imageDrawRect.origin.x) / scale,
            y: imageSize.height - (current.y - imageDrawRect.origin.y) / scale
        )
        
        let element = AnnotationElement(
            type: toolTypeToElementType(currentTool),
            startPoint: startImagePoint,
            endPoint: endImagePoint,
            color: primaryColor
        )
        annotations.append(element)
        
        startPoint = nil
        currentPoint = nil
        isDrawing = false
        needsDisplay = true
    }
    
    private func drawAnnotationInView(_ annotation: AnnotationElement, scale: CGFloat) {
        let imageSize = image.size
        
        let startViewPoint = CGPoint(
            x: imageDrawRect.origin.x + annotation.startPoint.x * scale,
            y: imageDrawRect.origin.y + (imageSize.height - annotation.startPoint.y) * scale
        )
        let endViewPoint = CGPoint(
            x: imageDrawRect.origin.x + annotation.endPoint.x * scale,
            y: imageDrawRect.origin.y + (imageSize.height - annotation.endPoint.y) * scale
        )
        
        drawShape(start: startViewPoint, end: endViewPoint, annotation: annotation)
    }
    
    private func drawAnnotationOnImage(_ annotation: AnnotationElement) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.setLineWidth(annotation.lineWidth)
        context.setStrokeColor(annotation.color.cgColor)
        
        let rect = CGRect(
            x: min(annotation.startPoint.x, annotation.endPoint.x),
            y: min(annotation.startPoint.y, annotation.endPoint.y),
            width: abs(annotation.endPoint.x - annotation.startPoint.x),
            height: abs(annotation.endPoint.y - annotation.startPoint.y)
        )
        
        switch annotation.type {
        case .rectangle:
            context.stroke(rect)
        case .circle:
            context.strokeEllipse(in: rect)
        case .line, .arrow:
            context.move(to: annotation.startPoint)
            context.addLine(to: annotation.endPoint)
            context.strokePath()
        }
    }
    
    private func drawCurrentAnnotationInView(start: CGPoint, end: CGPoint, scale: CGFloat) {
        drawShape(start: start, end: end, annotation: nil)
    }
    
    private func drawShape(start: CGPoint, end: CGPoint, annotation: AnnotationElement?) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let tool = annotation?.type ?? toolTypeToElementType(currentTool)
        let color = annotation?.color ?? primaryColor
        let lineWidth = annotation?.lineWidth ?? 2.0
        
        context.setLineWidth(lineWidth)
        context.setStrokeColor(color.cgColor)
        context.setAlpha(annotation == nil ? 0.7 : 0.8)
        
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        switch tool {
        case .rectangle:
            context.stroke(rect)
        case .circle:
            context.strokeEllipse(in: rect)
        case .line:
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
        case .arrow:
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            drawArrowhead(from: start, to: end, context: context, color: color)
        }
    }
    
    private func drawArrowhead(from start: CGPoint, to end: CGPoint, context: CGContext, color: NSColor) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowSize: CGFloat = 15
        
        let p1 = CGPoint(
            x: end.x - arrowSize * cos(angle - .pi / 6),
            y: end.y - arrowSize * sin(angle - .pi / 6)
        )
        let p2 = CGPoint(
            x: end.x - arrowSize * cos(angle + .pi / 6),
            y: end.y - arrowSize * sin(angle + .pi / 6)
        )
        
        context.setFillColor(color.cgColor)
        context.move(to: end)
        context.addLine(to: p1)
        context.addLine(to: p2)
        context.closePath()
        context.fillPath()
    }
    
    private func toolTypeToElementType(_ tool: AnnotationTool) -> AnnotationElement.AnnotationType {
        switch tool {
        case .rectangle: return .rectangle
        case .circle: return .circle
        case .line: return .line
        case .arrow: return .arrow
        case .pointer: return .rectangle
        }
    }
}
