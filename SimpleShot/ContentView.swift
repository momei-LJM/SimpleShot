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
    
    // 统一的主题色
    private let primaryColor = Color(red: 0.2, green: 0.5, blue: 1.0)
    private let secondaryColor = Color(red: 0.4, green: 0.6, blue: 1.0)
    private let accentColor = Color(red: 0.15, green: 0.45, blue: 0.95)
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题区域
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("SimpleShot")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // 截图按钮
            VStack(spacing: 10) {
                // 全屏截图按钮
                Button(action: {
                    screenshotManager.captureFullScreen()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.dashed")
                            .font(.system(size: 15, weight: .medium))
                        Text("全屏截图")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .shadow(color: primaryColor.opacity(0.3), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                
                // 区域截图按钮
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
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.dashed.and.paperclip")
                            .font(.system(size: 15, weight: .medium))
                        Text("区域截图")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [accentColor, primaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .shadow(color: accentColor.opacity(0.3), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                
                // 历史记录按钮
                Button(action: {
                    showingHistory.toggle()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 15, weight: .medium))
                        Text("截图历史")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        if screenshotManager.screenshots.count > 0 {
                            Text("\(screenshotManager.screenshots.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(primaryColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(primaryColor.opacity(0.15))
                                .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(primaryColor.opacity(0.2), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // 快捷键提示 - 精简版
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("⌘⇧3")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(primaryColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(primaryColor.opacity(0.1))
                        .cornerRadius(4)
                    Text("全屏")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    Text("⌘⇧4")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(primaryColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(primaryColor.opacity(0.1))
                        .cornerRadius(4)
                    Text("区域")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 12)
            
            Spacer()
            
            // 保存位置说明
            HStack(spacing: 4) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.8))
                Text("图片/SimpleShot/")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.bottom, 12)
        }
        .frame(width: 360, height: 360)
    }
}

// MARK: - 历史记录视图
struct HistoryView: View {
    @ObservedObject var screenshotManager: ScreenshotManager
    let onClose: () -> Void
    
    private let primaryColor = Color(red: 0.2, green: 0.5, blue: 1.0)
    
    let columns = [
        GridItem(.adaptive(minimum: 150))
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(primaryColor)
                    Text("截图历史")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                }
                Spacer()
                
                if !screenshotManager.screenshots.isEmpty {
                    Button("清除全部") {
                        screenshotManager.clearAll()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red.opacity(0.8))
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
                
                Button(action: onClose) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 13, weight: .medium))
                        Text("返回")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(primaryColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(primaryColor.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
            
            if screenshotManager.screenshots.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 56, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [primaryColor.opacity(0.4), primaryColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("暂无截图")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(screenshotManager.screenshots) { item in
                            ScreenshotThumbnail(item: item) {
                                screenshotManager.deleteScreenshot(item)
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - 缩略图视图
struct ScreenshotThumbnail: View {
    @State var item: ScreenshotItem
    let onDelete: () -> Void
    @State private var isHovered = false
    @State private var showAnnotationEditor = false
    
    private let primaryColor = Color(red: 0.2, green: 0.5, blue: 1.0)
    
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: item.annotatedImage ?? item.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150, height: 110)
                .background(Color(.controlBackgroundColor).opacity(0.3))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isHovered ? primaryColor.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: isHovered ? 2 : 1)
                )
                .shadow(color: isHovered ? primaryColor.opacity(0.2) : Color.black.opacity(0.1), radius: isHovered ? 8 : 4, x: 0, y: 2)
                .onTapGesture {
                    if isHovered {
                        showAnnotationEditor = true
                    }
                }
            
            HStack(spacing: 8) {
                Text(item.timestamp, style: .time)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                
                // 标注按钮
                Button(action: { showAnnotationEditor = true }) {
                    Image(systemName: "pencil.tip.crop.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(primaryColor)
                        .padding(6)
                        .background(primaryColor.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0.7)
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0.7)
            }
            .padding(.horizontal, 8)
        }
        .padding(10)
        .background(isHovered ? Color(.controlBackgroundColor).opacity(0.5) : Color.clear)
        .cornerRadius(12)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onChange(of: showAnnotationEditor) { newValue in
            if newValue {
                openAnnotationEditor(item: &item, isPresented: &showAnnotationEditor)
            }
        }
    }
    
    private func openAnnotationEditor(item: inout ScreenshotItem, isPresented: inout Bool) {
        let image = item.annotatedImage ?? item.image
        AnnotationEditorWindow.show(with: image) { annotatedImage in
            item.annotatedImage = annotatedImage
            isPresented = false
        } onCancel: {
            isPresented = false
        }
    }
}

#Preview {
    ContentView()
}
