//
//  CameraRecordView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import AVFoundation

struct CameraRecordView: View {
    @StateObject private var cameraService = CameraService()
    
    // UI State
    @State private var showAddSheet = false
    @State private var showPhotoLibrary = false
    @State private var selectedImage: UIImage?
    @State private var isTargeted = false
    @State private var permissionTask: Task<Void, Never>?
    
    // Zoom State
    @State private var baseZoomFactor: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // 1. 相机预览层
            CameraPreview(cameraService: cameraService)
                .ignoresSafeArea()
                .gesture(zoomGesture)
            
            // 2. 拖拽提示层 (当有文件拖入时显示)
            if isTargeted {
                DragDropOverlay()
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
            
            // 3. 顶部控制栏
            VStack {
                CameraControlBar(cameraService: cameraService)
                Spacer()
            }
            
            // 4. 底部操作栏
            CameraBottomBar(
                cameraService: cameraService,
                showPhotoLibrary: $showPhotoLibrary,
                showAddSheet: $showAddSheet,
                selectedImage: $selectedImage
            )
        }
        // 拖拽支持 (iOS 16+)
        .dropDestination(for: Data.self) { items, location in
            handleDroppedImage(items)
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.2)) {
                isTargeted = targeted
            }
        }
        // 生命周期管理
        .task {
            await handleCameraPermission()
        }
        .onDisappear {
            permissionTask?.cancel()
            cameraService.stop()
        }
        // 状态监听
        .onChange(of: cameraService.recentImage) { _, newImage in
            if let image = newImage {
                selectedImage = image
                showAddSheet = true
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            if newImage != nil {
                showAddSheet = true
            }
        }
        // Sheet 弹窗管理
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
                .onDisappear {
                    // 关闭相册后恢复相机
                    if !showAddSheet {
                        cameraService.start()
                    }
                }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionView(image: selectedImage, onSaved: {})
                .onDisappear {
                    selectedImage = nil
                    cameraService.recentImage = nil
                    // 关闭记账页后恢复相机
                    cameraService.start()
                }
        }
        // 自动暂停/恢复相机以节省电量
        .onChange(of: showPhotoLibrary) { _, isShowing in
            if isShowing { cameraService.stop() }
        }
        .onChange(of: showAddSheet) { _, isShowing in
            if isShowing { cameraService.stop() }
        }
    }
    
    // MARK: - Gestures
    
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                // 实时计算变焦倍数
                let delta = value / baseZoomFactor
                let newZoom = baseZoomFactor * delta
                cameraService.setZoom(newZoom)
            }
            .onEnded { value in
                // 手势结束后保存当前的变焦倍数作为下一次的基础
                baseZoomFactor = cameraService.currentZoomFactor
            }
    }
    
    // MARK: - Helpers
    
    private func handleDroppedImage(_ items: [Data]) -> Bool {
        guard let item = items.first,
              let image = UIImage(data: item) else {
            return false
        }
        selectedImage = image
        return true
    }
    
    private func handleCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            cameraService.start()
            
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                // 等待一小段时间确保系统完成授权
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                if !Task.isCancelled {
                    cameraService.start()
                }
            }
            
        case .denied, .restricted:
            // 这里可以添加一个 Alert 提示用户去设置里开启权限
            break
            
        @unknown default:
            break
        }
    }
}

    // MARK: - Subviews
    
    private struct DragDropOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: true) // iOS 17 动画效果
                
                Text(AppConstants.OCR.Camera.dragToImport)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct CameraControlBar: View {
    @ObservedObject var cameraService: CameraService
    
    var body: some View {
        HStack {
            // 切换摄像头
            Button {
                cameraService.switchCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(.leading)
            
            Spacer()
            
            // 变焦指示器
            Text(String(format: "%.1fx", cameraService.currentZoomFactor))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            
            Spacer()
            
            // 镜头切换菜单
            Menu {
                ForEach(cameraService.availableDeviceTypes, id: \.self) { deviceType in
                    Button {
                        cameraService.switchDeviceType(to: deviceType)
                    } label: {
                        HStack {
                            Text(deviceTypeName(deviceType))
                            if cameraService.currentDeviceType == deviceType {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: cameraIconName(cameraService.currentDeviceType))
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .disabled(cameraService.availableDeviceTypes.count <= 1)
            .opacity(cameraService.availableDeviceTypes.count <= 1 ? 0.5 : 1.0)
            .padding(.trailing)
        }
        .padding(.top, 50)
    }
    
    // MARK: - Helpers
    
    private func deviceTypeName(_ type: AVCaptureDevice.DeviceType) -> String {
        switch type {
        case .builtInWideAngleCamera: return AppConstants.OCR.Camera.wideAngle
        case .builtInUltraWideCamera: return AppConstants.OCR.Camera.ultraWide
        case .builtInTelephotoCamera: return AppConstants.OCR.Camera.telephoto
        default: return AppConstants.OCR.Camera.camera
        }
    }
    
    private func cameraIconName(_ type: AVCaptureDevice.DeviceType) -> String {
        switch type {
        case .builtInWideAngleCamera: return "camera"
        case .builtInUltraWideCamera: return "camera.aperture"
        case .builtInTelephotoCamera: return "camera.metering.matrix"
        default: return "camera"
        }
    }
}

private struct CameraBottomBar: View {
    @ObservedObject var cameraService: CameraService
    @Binding var showPhotoLibrary: Bool
    @Binding var showAddSheet: Bool
    @Binding var selectedImage: UIImage?
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                // 相册按钮
                Button {
                    showPhotoLibrary = true
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // 拍照按钮
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    cameraService.takePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        
                        Circle()
                            .fill(.white)
                            .frame(width: 62, height: 62)
                            .scaleEffect(cameraService.recentImage != nil ? 0.9 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: cameraService.recentImage)
                    }
                }
                
                Spacer()
                
                // 纯文本记账按钮
                Button {
                    selectedImage = nil
                    showAddSheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }
}