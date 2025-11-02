//
//  ScreenshotManager.swift
//  SimpleShot
//
//  Created by momei on 2025/11/2.
//

import Foundation
import AppKit
import SwiftUI
import ScreenCaptureKit
import Combine

class ScreenshotManager: ObservableObject {
    @Published var screenshots: [ScreenshotItem] = []
    @Published var isCapturing = false
    
    static let shared = ScreenshotManager()
    
    // 截图完成后的回调
    var onScreenshotCaptured: (() -> Void)?
    
    private init() {}
    
    // MARK: - 全屏截图
    func captureFullScreen() {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                guard let display = content.displays.first else {
                    print("无法获取主屏幕")
                    return
                }
                
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                
                // 获取屏幕的实际像素分辨率（考虑 Retina 屏幕的缩放因子）
                let screen = NSScreen.main
                let backingScaleFactor = screen?.backingScaleFactor ?? 2.0
                config.width = Int(CGFloat(display.width) * backingScaleFactor)
                config.height = Int(CGFloat(display.height) * backingScaleFactor)
                
                // 禁用缩放以保持原生分辨率
                config.scalesToFit = false
                
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                let nsImage = NSImage(cgImage: image, size: NSSize(width: display.width, height: display.height))
                
                await MainActor.run {
                    saveScreenshot(nsImage, type: .fullScreen)
                }
            } catch {
                print("截图失败: \(error)")
            }
        }
    }
    
    // MARK: - 区域截图
    func captureArea(rect: CGRect) {
        print("📍 收到截图请求 - rect: \(rect)")
        
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                guard let display = content.displays.first else {
                    print("❌ 无法获取主屏幕")
                    return
                }
                
                guard let screen = NSScreen.main else {
                    print("❌ 无法获取屏幕信息")
                    return
                }
                
                print("📺 Display info - width: \(display.width), height: \(display.height)")
                print("📺 Screen info - frame: \(screen.frame), scale: \(screen.backingScaleFactor)")
                
                // 获取全屏截图 - 使用高分辨率（考虑 Retina 屏幕）
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                let backingScaleFactor = screen.backingScaleFactor
                config.width = Int(CGFloat(display.width) * backingScaleFactor)
                config.height = Int(CGFloat(display.height) * backingScaleFactor)
                config.scalesToFit = false
                
                print("⏳ 开始截图... (分辨率: \(config.width) x \(config.height))")
                let fullImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                print("✅ 全屏截图完成 - 尺寸: \(fullImage.width) x \(fullImage.height)")
                
                // 需要按照高分辨率调整裁剪区域坐标
                let scaledRect = CGRect(
                    x: rect.origin.x * backingScaleFactor,
                    y: rect.origin.y * backingScaleFactor,
                    width: rect.width * backingScaleFactor,
                    height: rect.height * backingScaleFactor
                )
                
                print("📐 裁剪区域计算:")
                print("   输入 rect: \(rect)")
                print("   缩放后 rect: \(scaledRect)")
                print("   图片总尺寸: \(fullImage.width) x \(fullImage.height)")
                
                // 验证坐标是否在范围内
                if scaledRect.maxX > CGFloat(fullImage.width) || scaledRect.maxY > CGFloat(fullImage.height) {
                    print("⚠️  警告：裁剪区域超出图片范围！")
                    print("   scaledRect: \(scaledRect)")
                    print("   图片尺寸: \(fullImage.width) x \(fullImage.height)")
                }
                
                guard let croppedImage = fullImage.cropping(to: scaledRect) else {
                    print("❌ 区域裁剪失败 - scaledRect: \(scaledRect)")
                    return
                }
                
                print("✅ 裁剪成功 - 结果尺寸: \(croppedImage.width) x \(croppedImage.height)")
                
                let nsImage = NSImage(cgImage: croppedImage, size: rect.size)
                
                await MainActor.run {
                    saveScreenshot(nsImage, type: .area)
                }
            } catch {
                print("❌ 区域截图失败: \(error)")
            }
        }
    }
    
    // MARK: - 保存截图
    func saveScreenshot(_ image: NSImage, type: ScreenshotType) {
        let item = ScreenshotItem(image: image, type: type)
        
        // 确保在主线程执行
        if Thread.isMainThread {
            executeOnMainThread(image: image, item: item)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.executeOnMainThread(image: image, item: item)
            }
        }
        
        // 异步保存到文件
        Task {
            saveToFile(image, item: item)
        }
    }
    
    private func executeOnMainThread(image: NSImage, item: ScreenshotItem) {
        // 添加到列表
        self.screenshots.insert(item, at: 0)
        
        // 复制到剪贴板（最后执行，确保它是最后的操作）
        copyToClipboard(image)
        
        // 延迟触发回调，给剪贴板足够时间稳定
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.onScreenshotCaptured?()
        }
    }
    
    // MARK: - 保存到文件
    private func saveToFile(_ image: NSImage, item: ScreenshotItem) {
        let fileManager = FileManager.default
        let picturesURL = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let screenshotsFolder = picturesURL.appendingPathComponent("SimpleShot")
        
        // 创建文件夹
        if !fileManager.fileExists(atPath: screenshotsFolder.path) {
            try? fileManager.createDirectory(at: screenshotsFolder, withIntermediateDirectories: true)
        }
        
        // 生成文件名
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "Screenshot_\(dateFormatter.string(from: item.timestamp)).png"
        let fileURL = screenshotsFolder.appendingPathComponent(filename)
        
        // 转换为 PNG 数据 - 使用最高质量
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData) {
            // PNG 保存属性：不压缩（最高质量）
            let pngProperties: [NSBitmapImageRep.PropertyKey: Any] = [
                .compressionFactor: 1.0  // 无损压缩（范围 0.0-1.0，1.0 为最高质量）
            ]
            if let pngData = bitmapImage.representation(using: .png, properties: pngProperties) {
                try? pngData.write(to: fileURL)
                
                DispatchQueue.main.async {
                    if let index = self.screenshots.firstIndex(where: { $0.id == item.id }) {
                        self.screenshots[index].fileURL = fileURL
                    }
                }
                
                print("截图已保存至: \(fileURL.path)")
            }
        }
    }
    
    // MARK: - 复制到剪贴板
    private func copyToClipboard(_ image: NSImage) {
        print("🔍 开始复制到剪贴板")
        
        let pasteboard = NSPasteboard.general
        
        // 声明类型，使用 self 作为 owner 保持所有权
        pasteboard.declareTypes([.tiff, .png], owner: self)
        
        // 立即写入 TIFF 数据
        if let tiffData = image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
            print("✅ TIFF 数据已写入 (\(tiffData.count) bytes)")
        } else {
            print("⚠️  无法获取 TIFF 数据")
        }
        
        // 立即写入 PNG 数据
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            pasteboard.setData(pngData, forType: .png)
            print("✅ PNG 数据已写入 (\(pngData.count) bytes)")
        } else {
            print("⚠️  无法写入 PNG 数据")
        }
        
        print("✅ 截图已复制到剪贴板")
    }
    
    // MARK: - 删除截图
    func deleteScreenshot(_ item: ScreenshotItem) {
        if let fileURL = item.fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        screenshots.removeAll { $0.id == item.id }
    }
    
    // MARK: - 保存标注后的图像
    func saveAnnotatedImage(_ annotatedImage: NSImage, for itemID: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let index = self.screenshots.firstIndex(where: { $0.id == itemID }) else { return }
            
            let item = self.screenshots[index]
            self.screenshots[index].annotatedImage = annotatedImage
            
            // 异步保存标注后的图像到文件
            Task {
                self.saveAnnotatedToFile(annotatedImage, item: item)
            }
        }
    }
    
    private func saveAnnotatedToFile(_ image: NSImage, item: ScreenshotItem) {
        let fileManager = FileManager.default
        let picturesURL = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let screenshotsFolder = picturesURL.appendingPathComponent("SimpleShot")
        let annotatedFolder = screenshotsFolder.appendingPathComponent("Annotated")
        
        // 创建文件夹
        if !fileManager.fileExists(atPath: annotatedFolder.path) {
            try? fileManager.createDirectory(at: annotatedFolder, withIntermediateDirectories: true)
        }
        
        // 生成文件名（使用原始截图的时间戳）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "Screenshot_\(dateFormatter.string(from: item.timestamp))_annotated.png"
        let fileURL = annotatedFolder.appendingPathComponent(filename)
        
        // 转换为 PNG 数据 - 使用最高质量
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData) {
            // PNG 保存属性：最高质量
            let pngProperties: [NSBitmapImageRep.PropertyKey: Any] = [
                .compressionFactor: 1.0  // 无损压缩（最高质量）
            ]
            if let pngData = bitmapImage.representation(using: .png, properties: pngProperties) {
                try? pngData.write(to: fileURL)
                print("✅ 标注图像已保存至: \(fileURL.path)")
                
                // 同时复制到剪切板
                copyToClipboard(image)
            }
        }
    }
    
    // MARK: - 清除所有截图
    func clearAll() {
        for item in screenshots {
            if let fileURL = item.fileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        screenshots.removeAll()
    }
}

// MARK: - 截图类型
enum ScreenshotType {
    case fullScreen
    case area
    case window
}

// MARK: - 截图项
struct ScreenshotItem: Identifiable {
    let id = UUID()
    var image: NSImage
    let type: ScreenshotType
    let timestamp: Date
    var fileURL: URL?
    var annotatedImage: NSImage?  // 标注后的图片
    
    init(image: NSImage, type: ScreenshotType) {
        self.image = image
        self.type = type
        self.timestamp = Date()
    }
}
