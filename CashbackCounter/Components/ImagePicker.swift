//
//  ImagePicker.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/24/25.
//

import SwiftUI
import UIKit
import PhotosUI

/// 一个通用的图片选择器，支持从相册选择（使用 PHPicker）或拍照（使用 UIImagePickerController）
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - UIViewControllerRepresentable
    
    func makeUIViewController(context: Context) -> UIViewController {
        if sourceType == .camera {
            // 相机模式
            let picker = UIImagePickerController()
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                picker.sourceType = .camera
                picker.cameraCaptureMode = .photo
            }
            picker.delegate = context.coordinator
            return picker
        } else {
            // 相册模式 (使用现代的 PHPickerViewController)
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            return picker
        }
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
        
        // MARK: PHPickerViewControllerDelegate (Photo Library)
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // PHPicker 不会自动 dismiss，需要手动调用
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    if let error = error {
                        print("❌ [ImagePicker] 加载图片失败: \(error.localizedDescription)")
                        return
                    }
                    
                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            self?.parent.selectedImage = image
                        }
                    }
                }
            }
        }
    }
}

