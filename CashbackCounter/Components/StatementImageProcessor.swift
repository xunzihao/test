//
//  StatementImageProcessor.swift
//  CashbackCounter
//
//  Created by Assistant on 12/20/25.
//

import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// 负责处理账单图片的工具类（裁剪、边缘检测、OCR定位）
struct StatementImageProcessor {
    
    /// 🔪 裁剪交易表格区域（基于边缘检测和 OCR 定位）
    static func cropTransactionTable(from image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        // 基于 OCR 关键字定位
        if let ocrBasedRect = detectTableByOCR(in: image) {
            if let croppedCGImage = cgImage.cropping(to: ocrBasedRect) {
                print("✅ 通过 OCR 定位表格: \(ocrBasedRect)")
                return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
            }
        }
        
        // 如果都失败，返回原图
        print("⚠️ 未能检测到表格边框，使用原图")
        return image
    }
    
    /// 🔍 基于 OCR 关键字定位表格
    static func detectTableByOCR(in image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }
        
        let semaphore = DispatchSemaphore(value: 0)
        var detectedRect: CGRect?
        
        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            // 查找表格的关键标记
            var headerY: CGFloat?
            var footerY: CGFloat?
            var minX: CGFloat = 1.0
            var maxX: CGFloat = 0.0
            
            print("🔍 开始 OCR 定位，共 \(observations.count) 个文本块")
            
            for observation in observations {
                guard let text = observation.topCandidates(1).first?.string else { continue }
                let textUpper = text.uppercased()
                let box = observation.boundingBox
                
                // 🆕 查找表头（更宽松的匹配）
                if (textUpper.contains(AppConstants.OCR.headerKeywords[0]) && textUpper.contains(AppConstants.OCR.headerKeywords[2])) ||
                   (textUpper.contains(AppConstants.OCR.headerKeywords[1]) && textUpper.contains(AppConstants.OCR.headerKeywords[2])) ||
                   textUpper.contains(AppConstants.OCR.headerKeywords[3]) {
                    print("✅ 找到表头: '\(text)' at Y=\(box.minY)")
                    if headerY == nil || box.minY < headerY! {
                        headerY = box.minY  // 使用最上面的表头
                    }
                }
                
                // 🆕 查找 "Note" 或 "REWARDCASH" 作为表尾
                if (textUpper.contains(AppConstants.OCR.footerKeywords[0]) && textUpper.contains(AppConstants.OCR.footerKeywords[1])) ||
                   textUpper.contains(AppConstants.OCR.footerKeywords[2]) {
                    print("✅ 找到表尾标记: '\(text)' at Y=\(box.maxY)")
                    if footerY == nil || box.maxY < footerY! {
                        footerY = box.maxY
                    }
                }
                
                // 记录所有文本的边界（排除明显的标题）
                if !textUpper.contains(AppConstants.OCR.ignoreKeywords[0]) &&
                   !textUpper.contains(AppConstants.OCR.ignoreKeywords[1]) &&
                   !textUpper.contains(AppConstants.OCR.ignoreKeywords[2]) {
                    minX = min(minX, box.minX)
                    maxX = max(maxX, box.maxX)
                }
            }
            
            print("📊 检测结果: headerY=\(headerY ?? -1), footerY=\(footerY ?? -1)")
            
            // 如果找到了表头，构建矩形
            if let header = headerY {
                let width = CGFloat(cgImage.width)
                let height = CGFloat(cgImage.height)
                
                // 转换为 CGImage 坐标系（原点在左上角）
                let top = height * (1 - header) - 20  // 🆕 稍微向上扩展 20px，确保包含表头
                
                // 🆕 表尾处理
                let bottom: CGFloat
                if let footer = footerY {
                    bottom = height * (1 - footer) + 20  // 向下扩展 20px
                    print("✅ 使用检测到的表尾")
                } else {
                    bottom = height * 0.98  // 🆕 改为 98%，几乎到底部
                    print("⚠️ 未检测到表尾，使用图片底部")
                }
                
                let left = width * max(0, minX - 0.05)   // 🆕 增加左边距到 5%
                let right = width * min(1, maxX + 0.05)  // 🆕 增加右边距到 5%
                
                let rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
                print("✅ OCR 定位成功: \(rect)")
                detectedRect = rect
            } else {
                print("❌ 未找到表头，OCR 定位失败")
            }
        }
        
        request.recognitionLanguages = AppConstants.OCR.supportedLanguages
        request.recognitionLevel = .fast  // 使用快速模式，只需要定位
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            semaphore.wait()  // 等待 OCR 完成
        } catch {
            print("❌ OCR 定位失败: \(error)")
        }
        
        return detectedRect
    }
    
    // ⚠️ detectTableBorder 和 findLargestRectangle 暂时不需要暴露，
    // 因为目前 cropTransactionTable 只使用了 OCR 方法。
    // 如果将来需要混合使用，可以将它们作为私有方法移入此处。
}
