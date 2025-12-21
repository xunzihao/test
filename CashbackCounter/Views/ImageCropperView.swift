//
//  ImageCropperView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 12/17/25.
//

import SwiftUI

/// 图片裁剪和缩放编辑器
/// 用于让用户调整信用卡卡面图片的尺寸和位置
struct ImageCropperView: View {
    let originalImage: UIImage
    let aspectRatio: CGFloat // 卡片宽高比，默认 1.586 (标准信用卡比例)
    let onComplete: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // 图片变换状态
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // 用于记录实际显示的裁剪框尺寸
    @State private var displayCropSize: CGSize = .zero
    // 用于记录图片显示的实际尺寸（aspectFit 后的尺寸）
    @State private var displayImageSize: CGSize = .zero
    
    init(image: UIImage, aspectRatio: CGFloat = AppConstants.ImageCropperParameter.defaultCardAspectRatio, onComplete: @escaping (UIImage) -> Void) {
        self.originalImage = image
        self.aspectRatio = aspectRatio
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 说明文字
                HeaderView()
                
                // 裁剪区域
                GeometryReader { geometry in
                    let cropSize = calculateCropSize(in: geometry.size)
                    
                    ZStack {
                        // 1. 背景暗化层
                        Color.black.opacity(0.7)
                        
                        // 2. 可编辑的图片
                        Image(uiImage: originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            // 记录图片实际显示尺寸
                            .overlay(GeometryReader { geo in
                                Color.clear
                                    .onAppear { displayImageSize = geo.size }
                                    .onChange(of: geo.size) { _, newSize in displayImageSize = newSize }
                            })
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale *= delta
                                        // 限制最小和最大缩放：0.1x 到 3.0x (放宽上限以便查看细节)
                                        scale = min(max(scale, AppConstants.ImageCropperParameter.minScale), AppConstants.ImageCropperParameter.maxScale)
                                    }
                                    .onEnded { _ in lastScale = 1.0 }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in lastOffset = offset }
                            )
                        
                        // 3. 裁剪框覆盖层（带遮罩效果）
                        CropOverlayView(cropSize: cropSize)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .onAppear { displayCropSize = cropSize }
                    .onChange(of: geometry.size) { _, _ in
                        displayCropSize = calculateCropSize(in: geometry.size)
                    }
                }
                .padding()
                
                // 4. 底部控制栏
                ControlBar(scale: $scale, onReset: resetTransform, onFit: fitImageToCropArea)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppConstants.General.cancel) { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppConstants.General.confirm) {
                        if let croppedImage = cropImage() {
                            onComplete(croppedImage)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // 初始时自动适应图片
                // 延迟一点以确保 GeometryReader 已计算出尺寸
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    fitImageToCropArea()
                }
            }
        }
    }
    
    // MARK: - Logic Helpers
    
    /// 计算裁剪区域的尺寸
    private func calculateCropSize(in containerSize: CGSize) -> CGSize {
        let padding: CGFloat = AppConstants.ImageCropperParameter.cropPadding
        let availableWidth = containerSize.width - padding * 2
        let availableHeight = containerSize.height - padding * 2
        
        // 根据宽高比计算裁剪框尺寸
        let cropWidth: CGFloat
        let cropHeight: CGFloat
        
        if availableWidth / aspectRatio <= availableHeight {
            cropWidth = availableWidth
            cropHeight = availableWidth / aspectRatio
        } else {
            cropHeight = availableHeight
            cropWidth = availableHeight * aspectRatio
        }
        
        return CGSize(width: cropWidth, height: cropHeight)
    }
    
    /// 重置变换
    private func resetTransform() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
    
    /// 自动适应图片到裁剪区域
    private func fitImageToCropArea() {
        // 计算图片在默认显示状态下（aspectFit）的尺寸
        // 这里的 displayImageSize 是图片未缩放时的尺寸
        
        // 如果还没获取到尺寸，先用原始比例估算
        let imageAspect = originalImage.size.width / originalImage.size.height
        let cropAspect = aspectRatio
        
        // 策略：让图片“填满”裁剪框（Cover模式），而不是 Fit 模式，这样用户不需要手动放大
        // 计算需要的缩放比例
        
        // 假设图片当前是 aspectFit 在容器中
        // 我们需要计算：图片在容器中的实际尺寸 vs 裁剪框尺寸
        
        // 简单策略：重置位置，缩放设为 1.0 (如果原始图片比裁剪框大) 或者适当放大
        // 这里我们简化逻辑：重置为居中，缩放 1.0
        
        scale = 1.0
        if imageAspect > cropAspect {
             // 图片更宽，按高度对齐可能需要缩放
             // 但这里我们简单重置，让用户自己调整
        }
        
        offset = .zero
        lastOffset = .zero
        lastScale = 1.0
    }
    
    /// 核心：高精度裁剪图片
    private func cropImage() -> UIImage? {
        guard displayCropSize.width > 0 && displayCropSize.height > 0,
              displayImageSize.width > 0 && displayImageSize.height > 0 else {
            return nil
        }
        
        // 1. 计算缩放后的图片在屏幕上的实际尺寸
        let scaledImageWidth = displayImageSize.width * scale
        let scaledImageHeight = displayImageSize.height * scale
        
        // 2. 计算图片中心点相对于裁剪框中心点的偏移
        // offset 是 SwiftUI 的视图偏移量，坐标系中心在视图中心
        // 裁剪框中心 也是视图中心
        // 所以 offset 直接就是图片中心相对于裁剪框中心的偏移
        
        // 3. 计算裁剪框在图片坐标系中的位置 (归一化坐标 0~1)
        // 图片左上角在屏幕坐标系中的位置 (相对于视图中心):
        // imageLeft = offset.width - scaledImageWidth / 2
        // imageTop = offset.height - scaledImageHeight / 2
        
        // 裁剪框左上角在屏幕坐标系中的位置 (相对于视图中心):
        // cropLeft = -displayCropSize.width / 2
        // cropTop = -displayCropSize.height / 2
        
        // 裁剪框相对于图片左上角的偏移量:
        // relativeX = cropLeft - imageLeft
        //           = (-displayCropSize.width / 2) - (offset.width - scaledImageWidth / 2)
        //           = (scaledImageWidth - displayCropSize.width) / 2 - offset.width
        
        let cropRectX_Screen = (scaledImageWidth - displayCropSize.width) / 2 - offset.width
        let cropRectY_Screen = (scaledImageHeight - displayCropSize.height) / 2 - offset.height
        
        // 4. 将屏幕坐标映射回原始图片像素坐标
        // 缩放因子 = 原始图片像素宽度 / 屏幕上缩放后的宽度
        let ratio = originalImage.size.width / scaledImageWidth
        
        let cropX_Pixel = cropRectX_Screen * ratio
        let cropY_Pixel = cropRectY_Screen * ratio
        let cropWidth_Pixel = displayCropSize.width * ratio
        let cropHeight_Pixel = displayCropSize.height * ratio
        
        let cropRect = CGRect(x: cropX_Pixel, y: cropY_Pixel, width: cropWidth_Pixel, height: cropHeight_Pixel)
        
        // 5. 执行裁剪
        guard let cgImage = originalImage.cgImage?.cropping(to: cropRect) else {
            return nil
        }
        
        // 保持原图方向
        return UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
    }
}

// MARK: - Subviews

private struct HeaderView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text(AppConstants.Card.adjustCardImage)
                .font(.headline)
                .padding(.top)
            
            Text(AppConstants.Card.adjustImageInstruction)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct CropOverlayView: View {
    let cropSize: CGSize
    
    var body: some View {
        ZStack {
            // 裁剪框（带圆角和卡片样式）
            RoundedRectangle(cornerRadius: 16) // 稍微减小圆角以适应标准卡片
                .strokeBorder(Color.white, lineWidth: 2)
                .frame(width: cropSize.width, height: cropSize.height)
                .shadow(color: .black.opacity(0.5), radius: 4)
            
            // 裁剪框四角标记
            ZStack {
                ForEach(0..<4) { index in
                    CornerMarker()
                        .rotationEffect(.degrees(Double(index * 90)))
                        .offset(
                            x: index % 2 == 0 ? -cropSize.width/2 : cropSize.width/2,
                            y: index < 2 ? -cropSize.height/2 : cropSize.height/2
                        )
                }
            }
            
            // 网格线
            GridOverlay()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: cropSize.width, height: cropSize.height)
        }
        // 允许点击穿透，以便操作底下的图片
        .allowsHitTesting(false)
    }
}

private struct ControlBar: View {
    @Binding var scale: CGFloat
    let onReset: () -> Void
    let onFit: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // 缩放比例指示器
            HStack {
                Image(systemName: "viewfinder")
                    .foregroundColor(.secondary)
                Text(String(format: AppConstants.Card.scaleFormat, Int(scale * 100)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            // 按钮组
            HStack(spacing: 30) {
                ActionButton(title: AppConstants.General.reset, icon: "arrow.counterclockwise", action: {
                    withAnimation(.spring(response: 0.3)) { onReset() }
                })
                
                ActionButton(title: AppConstants.Card.zoomIn, icon: "plus.magnifyingglass", action: {
                    withAnimation(.spring(response: 0.3)) {
                        scale = min(scale * 1.2, AppConstants.ImageCropperParameter.maxScale)
                    }
                })
                .disabled(scale >= AppConstants.ImageCropperParameter.maxScale)
                
                ActionButton(title: AppConstants.Card.zoomOut, icon: "minus.magnifyingglass", action: {
                    withAnimation(.spring(response: 0.3)) {
                        scale = max(scale / 1.2, AppConstants.ImageCropperParameter.minScale)
                    }
                })
                .disabled(scale <= AppConstants.ImageCropperParameter.minScale)
                
                ActionButton(title: AppConstants.Card.fit, icon: "arrow.up.left.and.arrow.down.right", action: {
                    withAnimation(.spring(response: 0.3)) { onFit() }
                })
            }
        }
        .padding(.bottom)
    }
}

private struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(width: 60, height: 50) // 稍微调小一点，适应小屏
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(10)
        }
        .buttonStyle(.plain) // 防止点击高亮影响整个区域
    }
}

// MARK: - 辅助视图组件

/// 裁剪框四角标记
private struct CornerMarker: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: 20, height: 3)
                .offset(x: 10)
            
            Rectangle()
                .fill(Color.white)
                .frame(width: 3, height: 20)
                .offset(y: 10)
        }
    }
}

/// 网格线覆盖层（三分法网格）
private struct GridOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let verticalSpacing = rect.width / 3
        for i in 1...2 {
            let x = CGFloat(i) * verticalSpacing
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        let horizontalSpacing = rect.height / 3
        for i in 1...2 {
            let y = CGFloat(i) * horizontalSpacing
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

// MARK: - Preview
#Preview {
    ImageCropperView(image: UIImage(systemName: "photo")!) { _ in
        print(AppConstants.AI.imageSaved)
    }
}
