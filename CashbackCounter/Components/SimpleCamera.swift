//
//  SimpleCamera.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/24/25.
//

import SwiftUI
import AVFoundation
import Combine
import os

// MARK: - Camera Service

final class CameraService: NSObject, ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CashbackCounter", category: "CameraService")
    
    // Core
    @Published var session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: AppConstants.Config.cameraSessionQueue)
    
    // State
    @Published var recentImage: UIImage?
    @Published var isFlashOn: Bool = false
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var availableDeviceTypes: [AVCaptureDevice.DeviceType] = []
    
    private var currentDevice: AVCaptureDevice?
    private var currentPosition: AVCaptureDevice.Position = .back
    
    // MARK: - New Public Properties
    var currentDeviceType: AVCaptureDevice.DeviceType {
        currentDevice?.deviceType ?? .builtInWideAngleCamera
    }
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    // MARK: - Public API
    
    func start() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }
    
    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }
    
    func takePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn ? .on : .off
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func switchCamera() {
        currentPosition = (currentPosition == .back) ? .front : .back
        configureSession()
    }
    
    func switchDeviceType(to deviceType: AVCaptureDevice.DeviceType) {
        // 只有在后置摄像头时才支持切换镜头
        guard currentPosition == .back else { return }
        
        // 重新配置 Session，传入指定的 DeviceType
        configureSession(preferredDeviceType: deviceType)
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    func setZoom(_ factor: CGFloat) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.currentZoomFactor = device.videoZoomFactor
            }
        } catch {
            logger.error("Zoom failed: \(error.localizedDescription)")
        }
    }
    
    func focus(at point: CGPoint) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            
            // 1. 设置对焦点
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                // 点击时切换到单次自动对焦
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            }
            
            // 2. 设置曝光点
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
            }
            device.unlockForConfiguration()
        } catch {
            logger.error("Focus failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Configuration
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.configureSession() }
            }
        case .authorized:
            configureSession()
        default:
            logger.warning("Camera permission denied")
        }
    }
    
    private func configureSession(preferredDeviceType: AVCaptureDevice.DeviceType? = nil) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            
            // Auto-select best camera (Triple -> Dual -> Wide)
            let deviceTypes: [AVCaptureDevice.DeviceType]
            if let preferred = preferredDeviceType {
                deviceTypes = [preferred]
            } else {
                deviceTypes = [
                    .builtInTripleCamera,       // 三摄系统
                    .builtInDualWideCamera,     // 双广角系统
                    .builtInDualCamera,         // 旧款双摄
                    .builtInWideAngleCamera     // 单摄
                ]
            }
            
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: self.currentPosition
            )
            
            // 如果指定类型找不到（比如指定了长焦但光线太暗系统不让用），尝试回退到广角
            var finalDevice = discoverySession.devices.first
            if finalDevice == nil && preferredDeviceType != nil {
                 let fallbackSession = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera],
                    mediaType: .video,
                    position: self.currentPosition
                )
                finalDevice = fallbackSession.devices.first
            }
            
            guard let device = finalDevice else {
                self.logger.error("No camera device found")
                self.session.commitConfiguration()
                return
            }
            
            self.currentDevice = device
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                // 开启连续自动对焦和连续自动白平衡
                if let device = self.currentDevice {
                    try? device.lockForConfiguration()
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                        device.whiteBalanceMode = .continuousAutoWhiteBalance
                    }
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    device.unlockForConfiguration()
                }

                // Update capabilities
                // 只有在没有指定 preferredDeviceType 时才更新可用列表（即初始化时）
                if preferredDeviceType == nil {
                     // 简单起见，这里硬编码常见的支持类型，实际应该查询设备能力
                    let available: [AVCaptureDevice.DeviceType] = [
                        .builtInWideAngleCamera,
                        .builtInUltraWideCamera,
                        .builtInTelephotoCamera
                    ].filter { type in
                         AVCaptureDevice.DiscoverySession(
                            deviceTypes: [type],
                            mediaType: .video,
                            position: .back
                        ).devices.first != nil
                    }
                    
                    DispatchQueue.main.async {
                        self.availableDeviceTypes = available
                    }
                }
                
            } catch {
                self.logger.error("Session config failed: \(error.localizedDescription)")
            }
            
            self.session.commitConfiguration()
        }
    }
}

// MARK: - Delegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            logger.error("Capture failed: \(error.localizedDescription)")
            return
        }
        
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        
        DispatchQueue.main.async {
            self.recentImage = image
        }
    }
}

// MARK: - SwiftUI Preview

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraService: CameraService
    var onTap: ((CGPoint) -> Void)?
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.session = cameraService.session
        
        // Setup tap to focus
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        context.coordinator.onTap = onTap
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(service: cameraService)
    }
    
    class Coordinator: NSObject {
        let service: CameraService
        var onTap: ((CGPoint) -> Void)?
        
        init(service: CameraService) {
            self.service = service
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let point = gesture.location(in: view)
            let convertedPoint = CGPoint(x: point.y / view.bounds.height, y: 1.0 - point.x / view.bounds.width)
            service.focus(at: convertedPoint)
            onTap?(point)
        }
    }
}

// Native Preview Layer Wrapper
class CameraPreviewView: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }
        return layer
    }
    
    var session: AVCaptureSession? {
        get { videoPreviewLayer.session }
        set { videoPreviewLayer.session = newValue }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }
}

