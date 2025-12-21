//
//  PDFPicker.swift
//  CashbackCounter
//
//  Created by Assistant on 12/19/25.
//

import SwiftUI
import UniformTypeIdentifiers
import os

/// 一个用于选择 PDF 文件的系统文档选择器封装
struct PDFPicker: UIViewControllerRepresentable {
    @Binding var selectedPDFURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // 创建文档选择器，指定仅支持 PDF 类型
        // asCopy: true 表示系统会自动将文件复制到 App 的沙盒中，避免权限问题
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: PDFPicker
        private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CashbackCounter", category: "PDFPicker")
        
        init(_ parent: PDFPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                logger.warning("⚠️ 未选择任何文件")
                return
            }
            
            logger.info("📄 已选择 PDF 文件: \(url.lastPathComponent)")
            
            // 回到主线程更新 UI
            DispatchQueue.main.async {
                self.parent.selectedPDFURL = url
                self.parent.dismiss()
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            logger.info("🛑 用户取消了文件选择")
            parent.dismiss()
        }
    }
}
