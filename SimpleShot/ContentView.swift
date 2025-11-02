//
//  ContentView.swift
//  SimpleShot
//
//  Created by momei on 2025/11/2.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var screenshotManager = ScreenshotManager.shared
    @State private var showingHistory = false
    
    var body: some View {
        if showingHistory {
            HistoryView(screenshotManager: screenshotManager) {
                showingHistory = false
            }
        } else {
            MainView(screenshotManager: screenshotManager, showingHistory: $showingHistory)
        }
    }
    
    init() {
        // 设置截图完成回调
        ScreenshotManager.shared.onScreenshotCaptured = {
            // 延迟1秒后隐藏菜单栏窗口，确保剪贴板数据完全稳定
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                    appDelegate.hideMenuBarWindow()
                }
            }
        }
    }
}

// MARK: - 主视图
struct MainView: View {
    @ObservedObject var screenshotManager: ScreenshotManager
    @Binding var showingHistory: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                Text("SimpleShot")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .padding(.top)
            
            Divider()
            
            // 截图按钮
            VStack(spacing: 15) {
                Button(action: {
                    screenshotManager.captureFullScreen()
                }) {
                    HStack {
                        Image(systemName: "rectangle.dashed")
                            .font(.system(size: 20))
                        Text("全屏截图")
                            .font(.system(size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    SelectionManager.shared.showSelectionOverlay(
                        onCapture: { rect in
                            screenshotManager.captureArea(rect: rect)
                        },
                        onCancel: {
                            print("取消区域截图")
                        }
                    )
                }) {
                    HStack {
                        Image(systemName: "rectangle.dashed.and.paperclip")
                            .font(.system(size: 20))
                        Text("区域截图")
                            .font(.system(size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    showingHistory.toggle()
                }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20))
                        Text("截图历史 (\(screenshotManager.screenshots.count))")
                            .font(.system(size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            Divider()
            
            // 快捷键提示
            VStack(alignment: .leading, spacing: 8) {
                Text("快捷键")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                HStack {
                    Text("⌘⇧3")
                        .font(.system(size: 14, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    Text("全屏截图")
                        .font(.system(size: 14))
                    Spacer()
                }
                
                HStack {
                    Text("⌘⇧4")
                        .font(.system(size: 14, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    Text("区域截图")
                        .font(.system(size: 14))
                    Spacer()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            Spacer()
            
            // 保存位置说明
            Text("截图保存在：图片/SimpleShot/")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .frame(width: 400, height: 500)
    }
}

// MARK: - 历史记录视图
struct HistoryView: View {
    @ObservedObject var screenshotManager: ScreenshotManager
    let onClose: () -> Void
    
    let columns = [
        GridItem(.adaptive(minimum: 150))
    ]
    
    var body: some View {
        VStack {
            HStack {
                Text("截图历史")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("清除全部") {
                    screenshotManager.clearAll()
                }
                .foregroundColor(.red)
                Button("返回") {
                    onClose()
                }
            }
            .padding()
            
            if screenshotManager.screenshots.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("暂无截图")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(screenshotManager.screenshots) { item in
                            ScreenshotThumbnail(item: item) {
                                screenshotManager.deleteScreenshot(item)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - 缩略图视图
struct ScreenshotThumbnail: View {
    let item: ScreenshotItem
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack {
            Image(nsImage: item.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 100)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            HStack {
                Text(item.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    ContentView()
}
