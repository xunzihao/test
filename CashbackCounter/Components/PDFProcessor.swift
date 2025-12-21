//
//  PDFProcessor.swift
//  CashbackCounter
//
//  Created by Assistant on 12/19/25.
//

import UIKit
import PDFKit
import os

/// PDF 处理工具
enum PDFProcessorError: Error {
    case loadFailed
    case emptyDocument
}

class PDFProcessor {
    
    private static let logger = Logger(subsystem: "CashbackCounter", category: "PDFProcessor")
    
    /// 将 PDF 的每一页转换为 UIImage (异步)
    /// - Parameter url: PDF 文件 URL
    /// - Returns: 图片数组（每页一张）
    static func convertPDFToImages(url: URL) async throws -> [UIImage] {
        guard let document = PDFDocument(url: url) else {
            logger.error("❌ 无法加载 PDF 文件: \(url.path)")
            throw PDFProcessorError.loadFailed
        }
        
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            logger.warning("⚠️ PDF 文件为空")
            throw PDFProcessorError.emptyDocument
        }
        
        logger.info("📄 PDF 共 \(pageCount) 页，开始转换...")
        
        // 耗时操作，放入后台线程执行
        return await Task.detached(priority: .userInitiated) {
            var images: [UIImage] = []
            
            for pageIndex in 0..<pageCount {
                guard let page = document.page(at: pageIndex) else {
                    logger.warning("⚠️ 无法获取第 \(pageIndex + 1) 页")
                    continue
                }
                
                if let image = renderPage(page, pageIndex: pageIndex) {
                    images.append(image)
                }
            }
            
            logger.info("✅ PDF 转换完成，共生成 \(images.count) 张图片")
            return images
        }.value
    }
    
    /// 渲染单个页面为图片
    private static func renderPage(_ page: PDFPage, pageIndex: Int) -> UIImage? {
        // 获取页面的尺寸
        let pageRect = page.bounds(for: .mediaBox)
        
        // 设置渲染比例（2.0x 提高清晰度，用于 OCR）
        let scale: CGFloat = 2.0
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )
        
        // 创建图片上下文
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { context in
            // 1. 填充白色背景（防止透明背景导致 OCR 识别错误）
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            // 2. 坐标系转换：PDF 坐标系原点在左下角，UIKit 在左上角
            // 先下移整个画布
            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            // 再垂直翻转
            context.cgContext.scaleBy(x: scale, y: -scale)
            
            // 3. 绘制页面
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return image
    }
}

