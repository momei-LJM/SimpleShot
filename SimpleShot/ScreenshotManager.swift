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
                config.width = Int(display.width)
                config.height = Int(display.height)
                
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
                
                // 获取全屏截图
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(display.width)
                config.height = Int(display.height)
                
                print("⏳ 开始截图...")
                let fullImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                print("✅ 全屏截图完成 - 尺寸: \(fullImage.width) x \(fullImage.height)")
                
                // 关键发现：Display 的 width/height 是逻辑像素，不是物理像素
                // ScreenCaptureKit 返回的图片尺寸就是逻辑像素尺寸
                // 所以 rect 可以直接用于裁剪，不需要乘以 scale！
                
                let captureRect = CGRect(
                    x: rect.origin.x,
                    y: rect.origin.y,
                    width: rect.width,
                    height: rect.height
                )
                
                print("📐 裁剪区域计算:")
                print("   输入 rect: \(rect)")
                print("   裁剪坐标 (逻辑像素): \(captureRect)")
                print("   图片总尺寸: \(fullImage.width) x \(fullImage.height)")
                
                // 验证坐标是否在范围内
                if captureRect.maxX > CGFloat(fullImage.width) || captureRect.maxY > CGFloat(fullImage.height) {
                    print("⚠️  警告：裁剪区域超出图片范围！")
                    print("   captureRect: \(captureRect)")
                    print("   图片尺寸: \(fullImage.width) x \(fullImage.height)")
                }
                
                guard let croppedImage = fullImage.cropping(to: captureRect) else {
                    print("❌ 区域裁剪失败 - captureRect: \(captureRect)")
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
        
        DispatchQueue.main.async {
            self.screenshots.insert(item, at: 0)
        }
        
        // 保存到文件
        saveToFile(image, item: item)
        
        // 复制到剪贴板
        copyToClipboard(image)
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
        
        // 转换为 PNG 数据
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
            
            DispatchQueue.main.async {
                if let index = self.screenshots.firstIndex(where: { $0.id == item.id }) {
                    self.screenshots[index].fileURL = fileURL
                }
            }
            
            print("截图已保存至: \(fileURL.path)")
        }
    }
    
    // MARK: - 复制到剪贴板
    private func copyToClipboard(_ image: NSImage) {
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            
            // 同时写入 TIFF 和 PNG 格式，提高兼容性
            if let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
                
                // 转换为 PNG
                if let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    pasteboard.setData(pngData, forType: .png)
                }
            }
            
            print("✅ 截图已复制到剪贴板 (尺寸: \(image.size))")
        }
    }
    
    // MARK: - 删除截图
    func deleteScreenshot(_ item: ScreenshotItem) {
        if let fileURL = item.fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        screenshots.removeAll { $0.id == item.id }
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
    let image: NSImage
    let type: ScreenshotType
    let timestamp: Date
    var fileURL: URL?
    
    init(image: NSImage, type: ScreenshotType) {
        self.image = image
        self.type = type
        self.timestamp = Date()
    }
}
