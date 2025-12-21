//
//  OCRService.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/24/25.
//

import Vision
import UIKit
import FoundationModels // 引入 AI 框架
import ImageIO          // 用于处理图片方向
import OSLog

// MARK: - 公共数据结构

/// 📍 识别的文本元素
struct RecognizedElement {
    let text: String
    let xPosition: CGFloat  // X 坐标（用于排序列顺序）
    let boundingBox: CGRect // 完整边界框
}

/// 📍 识别的表格行
struct RecognizedRow {
    let yPosition: CGFloat  // Y 坐标中心（用于判断是否同一行）
    let elements: [RecognizedElement]  // 该行的所有文本元素（已按 X 排序）
    
    /// 将该行的所有元素合并为一个字符串
    var text: String {
        elements.map { $0.text }.joined(separator: " ")
    }
}

struct OCRService {
    
    @MainActor static let aiParser = ReceiptParser()
    private static let logger = Logger.category("OCRService")

    @MainActor
    static func analyzeImage(_ image: UIImage, region: Region? = nil) async -> ReceiptMetadata? {
        // 1. 第一轮 OCR：使用通用语言列表
        let broadLanguages = [
            AppConstants.Languages.zhHans,
            AppConstants.Languages.zhHant,
            AppConstants.Languages.enUS,
            AppConstants.Languages.jaJP
        ]
        
        let firstPassText = await recognizeText(from: image, languages: broadLanguages)
        logger.debug("📝 第一轮 OCR 结果长度: \(firstPassText.count)")
        
        // 2. ⚡️ 本地快速推断 (不调 AI，只查关键词)
        let detectedRegion = simpleInferRegion(from: firstPassText)
        logger.info("⚡️ 本地推断地区: \(detectedRegion?.rawValue ?? "未知")")

        var finalText = firstPassText
        
        // 3. 决策：需要重扫吗？
        if let targetRegion = detectedRegion {
            let optimizedLanguages = getLanguages(for: targetRegion)
            // 只有当优化后的语言列表跟通用列表不一样时，才值得重扫
            if optimizedLanguages != broadLanguages {
                logger.info("🔄 启动第二轮：针对 \(targetRegion.rawValue) 的精准识别...")
                finalText = await recognizeText(from: image, languages: optimizedLanguages)
            }
        }
        
        // 4. 最终只调用一次 AI
        logger.info("🤖 以此文本请求 AI 分析...")
        let metadata = try? await aiParser.parse(text: finalText)
        
        // 5. 🧮 后处理：如果有汇率，智能计算缺失的金额
        let processedMetadata = processExchangeRate(metadata: metadata)
        
        // 6. 💳 后处理：增强支付方式识别（本地验证）
        return enhancePaymentMethodDetection(metadata: processedMetadata, ocrText: finalText)
    }
    
    // MARK: - Vision Logic (Core)
    
    /// 核心方法：执行 Vision 请求并返回原始 Observations
    static func recognizeObservations(from image: UIImage, languages: [String]) async throws -> [VNRecognizedTextObservation] {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "OCRService", code: -1, userInfo: [NSLocalizedDescriptionKey: AppConstants.ErrorMessages.cgImageError])
        }
        
        let orientation = cgImageOrientation(from: image.imageOrientation)
        
        return try await withCheckedThrowingContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    logger.error("Vision 请求内部错误: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    logger.warning("未识别到任何文本 Observation")
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: observations)
            }
            
            // 🆕 Use latest revision for better accuracy (iOS 16+)
            if #available(iOS 16.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                logger.error("Vision Handler 执行失败: \(error.localizedDescription)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - 结构化数据重建 (核心抽象)
    
    /// 🔨 通用方法：将离散的 OCR 结果重建为结构化的行
    /// 适用于账单、小票等任何基于行布局的文档
    static func reconstructRows(from observations: [VNRecognizedTextObservation]) -> [RecognizedRow] {
        // 1. 提取所有识别的文本及其位置
        let elements = observations.compactMap { observation -> RecognizedElement? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let box = observation.boundingBox
            return RecognizedElement(
                text: text,
                xPosition: box.midX,
                boundingBox: box
            )
        }
        
        guard !elements.isEmpty else { return [] }
        
        // 2. 按 Y 坐标排序（Vision 坐标系：Y 轴向上，所以从大到小是从上到下）
        let sortedByY = elements.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        
        // 3. 计算行分组容差
        let avgHeight = elements.map { $0.boundingBox.height }.reduce(0, +) / CGFloat(elements.count)
        let rowThreshold = avgHeight * 0.6  // 容差：60% 行高视为同一行
        
        var rows: [[RecognizedElement]] = []
        var currentRow: [RecognizedElement] = []
        var lastY: CGFloat = -1
        
        for element in sortedByY {
            let y = element.boundingBox.midY
            
            if lastY == -1 || abs(y - lastY) < rowThreshold {
                // 属于当前行
                currentRow.append(element)
            } else {
                // 新的一行
                if !currentRow.isEmpty {
                    // 按 X 坐标排序（从左到右）
                    let sortedRow = currentRow.sorted { $0.xPosition < $1.xPosition }
                    rows.append(sortedRow)
                }
                currentRow = [element]
            }
            lastY = y
        }
        
        // 添加最后一行
        if !currentRow.isEmpty {
            let sortedRow = currentRow.sorted { $0.xPosition < $1.xPosition }
            rows.append(sortedRow)
        }
        
        // 4. 转换为 RecognizedRow
        return rows.map { elements in
            let avgY = elements.map { $0.boundingBox.midY }.reduce(0, +) / CGFloat(elements.count)
            return RecognizedRow(yPosition: avgY, elements: elements)
        }
    }
    
    /// 便捷方法：直接返回合并后的字符串
    /// ✨ 优化：现在使用 reconstructRows 来确保返回的文本是按视觉行组织的
    static func recognizeText(from image: UIImage, languages: [String]) async -> String {
        do {
            let observations = try await recognizeObservations(from: image, languages: languages)
            // 使用行重建逻辑，确保多列布局（如小票上的品名和价格）能保持在同一行
            let rows = reconstructRows(from: observations)
            return rows.map { $0.text }.joined(separator: "\n")
        } catch {
            logger.error("\(String(format: AppConstants.ErrorMessages.ocrError, error.localizedDescription))")
            return ""
        }
    }
    
    static func cgImageOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    // MARK: - 🧮 Post-Processing: Exchange Rate
    
    // 当小票上有汇率时，根据已有信息计算缺失的金额
    private static func processExchangeRate(metadata: ReceiptMetadata?) -> ReceiptMetadata? {
        guard var result = metadata else { return nil }
        guard let rate = result.exchangeRate, rate > 0 else { return result }
        
        logger.info("💱 检测到汇率: \(rate)")
        
        // 场景 A：有外币 + 汇率，但没有记账金额 → 计算记账金额
        if let foreign = result.totalAmount, foreign > 0, result.billingAmount == nil {
            let calculated = foreign * rate
            result.billingAmount = calculated
            logger.info("✅ 根据汇率计算记账金额: \(foreign) × \(rate) = \(calculated)")
        }
        // 场景 B：有记账金额 + 汇率，但没有外币 → 反向计算外币
        else if let billing = result.billingAmount, billing > 0, result.totalAmount == nil {
            let calculated = billing / rate
            result.totalAmount = calculated
            logger.info("✅ 根据汇率反向计算外币金额: \(billing) ÷ \(rate) = \(calculated)")
        }
        // 场景 C：三者都有 → 验证一致性
        else if let foreign = result.totalAmount, let billing = result.billingAmount {
            let expectedBilling = foreign * rate
            let tolerance = 0.02 // 允许 2 分钱误差（汇率四舍五入）
            if abs(billing - expectedBilling) > tolerance {
                logger.warning("⚠️ 汇率不匹配：外币 \(foreign) × 汇率 \(rate) = \(expectedBilling)，但记账金额为 \(billing)")
                logger.warning("📋 以小票实际显示为准")
            }
        }
        
        return result
    }
    
    // MARK: - 💳 Post-Processing: Payment Method
    
    // 辅助检查函数 (Public static for sharing)
    static func containsAny(_ keywords: [String], in text: String) -> Bool {
        let upperText = text.uppercased()
        return keywords.contains { upperText.contains($0.uppercased()) || text.contains($0) }
    }
    
    // 基于 OCR 原始文本进行本地关键词匹配，增强 AI 的识别准确度
    private static func enhancePaymentMethodDetection(metadata: ReceiptMetadata?, ocrText: String) -> ReceiptMetadata? {
        guard var result = metadata else { return nil }
        
        let upperText = ocrText.uppercased()
        let originalText = ocrText
        
        // 如果 AI 已经识别出支付方式，且置信度高，则优先使用 AI 的结果
        if let aiMethod = result.paymentMethod, !aiMethod.isEmpty {
            logger.info("💳 AI 已识别支付方式: \(aiMethod)")
            // 但仍然进行本地验证，如果有更强的特征，可以覆盖
        }
        
        // 本地规则优先级（从高到低）
        
        // 1. 最高优先级：Apple Pay（特征明显）
        if containsAny(AppConstants.OCR.PaymentDetection.applePay, in: ocrText) {
            result.paymentMethod = AppConstants.Transaction.applePay
            logger.info("💳 本地识别: Apple Pay（关键词匹配）")
            return result
        }
        
        // 2. 次高优先级：银联二维码（多个关键词组合）
        if containsAny(AppConstants.OCR.PaymentDetection.unionPayQR, in: ocrText) {
            result.paymentMethod = AppConstants.Transaction.unionPayQR
            logger.info("💳 本地识别: 银联二维码")
            return result
        }
        
        // 3. 中等优先级：网购（电商平台特征）
        if containsAny(AppConstants.OCR.PaymentDetection.online, in: ocrText) {
            result.paymentMethod = AppConstants.Transaction.onlineShopping
            logger.info("💳 本地识别: 网购")
            return result
        }
        
        // 4. 默认规则：如果 AI 没有识别出支付方式，且没有特殊关键词
        // 判断为普通线下购物（纸质小票的默认场景）
        if result.paymentMethod == nil || result.paymentMethod?.isEmpty == true {
            // 检查是否有明显的实体店特征
            if containsAny(AppConstants.OCR.PaymentDetection.physicalStore, in: ocrText) {
                result.paymentMethod = AppConstants.Transaction.offlineShopping
                logger.info("💳 本地识别: 线下购物（实体店特征）")
                return result
            }
            
            // 如果什么特征都没有，保持 nil（让用户手动选择）
            logger.info("💳 无法自动识别支付方式，保持为 nil")
        }
        
        return result
    }
    
    // MARK: - 🕵️‍♂️ Region Detection
    
    // 这是一个纯字符串匹配方法，速度极快
    static func simpleInferRegion(from text: String) -> Region? {
        let upperText = text.uppercased()
        
        // 1. 强特征：直接看货币代码 (ISO Code)
        if containsAny(AppConstants.OCR.RegionDetection.jpCurrency, in: text) { return .jp }
        if containsAny(AppConstants.OCR.RegionDetection.hkCurrency, in: text) { return .hk }
        if containsAny(AppConstants.OCR.RegionDetection.twCurrency, in: text) { return .tw }
        if containsAny(AppConstants.OCR.RegionDetection.nzCurrency, in: text) { return .nz }
        if containsAny(AppConstants.OCR.RegionDetection.cnCurrency, in: text) { return .cn }
        if containsAny(AppConstants.OCR.RegionDetection.usCurrency, in: text) { return .us }
        
        // 2. 弱特征：看地名或特殊符号 (如果货币没找到)
        if containsAny(AppConstants.OCR.RegionDetection.jpKeywords, in: text) { return .jp }
        if containsAny(AppConstants.OCR.RegionDetection.hkKeywords, in: text) { return .hk }
        if containsAny(AppConstants.OCR.RegionDetection.twKeywords, in: text) { return .tw }
        if containsAny(AppConstants.OCR.RegionDetection.usKeywords, in: text) { return .us }
        
        // 3. 符号特征 (¥ 比较难办，中日都用，默认不处理或按概率给一个)
        if containsAny(AppConstants.OCR.RegionDetection.cnKeywords, in: text) { return .cn }
        
        return nil
    }
    
    // 获取各地区的最佳语言优先级
    static func getLanguages(for region: Region) -> [String] {
        let zhHans = AppConstants.Languages.zhHans
        let enUS = AppConstants.Languages.enUS
        let jaJP = AppConstants.Languages.jaJP
        let zhHant = AppConstants.Languages.zhHant
        
        switch region {
        case .jp: return [jaJP, enUS, zhHans] // 日本：必须把 ja-JP 放第一
        case .cn: return [zhHans, enUS, jaJP] // 简中区
        case .hk, .tw: return [zhHant, enUS, jaJP] // 繁中区
        case .us, .nz, .other: return [enUS, zhHans, jaJP] // 英语区
        }
    }
}
