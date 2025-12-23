//
//  StatementAnalyzer.swift
//  CashbackCounter
//
//  Created by Assistant on 12/19/25.
//

import UIKit
import Vision
import Foundation
import OSLog
import RegexBuilder

/// 📊 账单分析结果
struct StatementAnalysisResult {
    var cardName: String = ""
    var cardLastFour: String = ""
    var statementDate: Date?
    var transactions: [ParsedTransaction] = []
    var rawText: String = "" // 原始识别文本
    
    struct ParsedTransaction {
        var postDate: Date?      // 记账日
        var transDate: Date?     // 交易日
        var description: String  // 交易描述
        var billingAmount: Double       // 金额（入账金额，本币 HKD）
        var billingCurrency: String = AppConstants.Currency.hkd // 入账币种
        var paymentMethod: String? = nil // 支付方式（自动检测）
        
        // 🆕 外币交易信息（用于判断返现规则）
        var isForeignCurrency: Bool = false  // 是否为外币交易（决定使用哪套返现规则）
        var spendingCurrency: String?         // 外币币种（如 USD, JPY）
        var spendingAmount: Double?           // 外币消费金额
        
        // 🆕 返现计算标记
        var isRefundOrPayment: Bool = false  // 是否为退款/还款（不计算返现，但显示在列表中）
        // CBF
        var cbfFee: Double? = nil
        
        /// 🔑 用于返现计算的币种（如果是外币交易，使用外币币种；否则使用入账币种）
        var cashbackCurrency: String {
            return isForeignCurrency ? (spendingCurrency ?? billingCurrency) : billingCurrency
        }
    }
}

/// 🔍 账单分析器（使用 Vision OCR + 表格结构识别）
final class StatementAnalyzer {
    
    private let logger = Logger.category("StatementAnalyzer")
    
    // MARK: - 正则表达式定义 (Swift RegexBuilder)
    
    // 匹配金额：支持千分位，小数点，CR后缀，星号
    // e.g. "1,234.56", "123.45CR", "500*"
    
    // 1,234 (with optional fraction)
    private static let integerWithCommas = Regex {
        OneOrMore(.digit)
        ZeroOrMore {
            ","
            Repeat(count: 3) { .digit }
        }
    }
    
    // 1234 (must have fraction to avoid matching years easily, but context matters)
    private static let simpleInteger = OneOrMore(.digit)
    
    private static let fractionalPart = Regex {
        "."
        Repeat(1...2) { .digit }
    }
    
    private let amountRegex = Regex {
        Capture {
            ChoiceOf {
                Regex {
                    StatementAnalyzer.integerWithCommas
                    Optionally { StatementAnalyzer.fractionalPart }
                }
                Regex {
                    StatementAnalyzer.simpleInteger
                    StatementAnalyzer.fractionalPart
                }
            }
        }
        // CR 后缀 (Credit)
        Optionally {
            Capture { "CR" }
        }
        // 星号后缀
        Optionally { "*" }
    }
    
    // 匹配 "ddMMM" 格式 (e.g., 25DEC)
    private let shortDateRegex = Regex {
        Capture {
            Repeat(1...2) { .digit }
            Repeat(count: 3) { .word } // MMM
        }
    }
    
    // 匹配日期前缀 (e.g., "25DEC ")
    private let datePrefixRegex = Regex {
        Anchor.startOfLine
        Repeat(1...2) { .digit }
        Repeat(count: 3) { .word }
        ZeroOrMore(.whitespace)
    }

    // MARK: - 公共接口
    
    /// 分析账单图片
    func analyze(image: UIImage) async throws -> StatementAnalysisResult {
        logger.info("开始分析账单图片")
        
        // 1. 执行 OCR（获取结构化行数据）
        let observations = try await OCRService.recognizeObservations(from: image, languages: AppConstants.OCR.supportedLanguages)
        
        // 2. 重建表格行
        let recognizedRows = OCRService.reconstructRows(from: observations)
        logger.info("OCR 完成，识别到 \(recognizedRows.count) 行")
        
        // 3. 解析表格结构
        let result = parseStatementTable(rows: recognizedRows)
        logger.info("表格解析完成，提取到 \(result.transactions.count) 笔交易")
        
        return result
    }
    
    // MARK: - 表格解析逻辑
    
    /// 解析账单表格（基于结构化行数据）
    private func parseStatementTable(rows: [RecognizedRow]) -> StatementAnalysisResult {
        var result = StatementAnalysisResult()
        
        // 保存原始文本（用于调试）
        result.rawText = rows.map { $0.text }.joined(separator: "\n")
        
        // 1. 提取卡片信息
        extractCardInfo(from: rows, into: &result)
        
        // 2. 提取结单日期
        extractStatementDate(from: rows, into: &result)
        
        // 3. 提取交易记录
        extractTransactionsFromTable(rows: rows, into: &result, statementDate: result.statementDate)
        
        return result
    }
    
    // MARK: - 信息提取子任务
    
    private func extractCardInfo(from rows: [RecognizedRow], into result: inout StatementAnalysisResult) {
        for row in rows {
            let text = row.text
            let uppercasedText = text.uppercased()
            
            // 查找卡类型 (PULSE)
            if uppercasedText.contains(AppConstants.OCR.pulse) {
                // 简单的正则匹配 "PULSE" 后的内容
                let pulseRegex = Regex {
                    AppConstants.OCR.pulse
                    OneOrMore {
                        ChoiceOf {
                            CharacterClass.whitespace
                            ("A"..."Z")
                        }
                    }
                }
                if let match = try? pulseRegex.firstMatch(in: text) {
                    result.cardName = String(match.0).trimmingCharacters(in: .whitespaces)
                }
            }
            
            // 查找卡号后四位 (xxxx xxxx xxxx 1234)
            let cardNumRegex = Regex {
                Repeat(count: 4) { .digit }
                OneOrMore(.whitespace)
                Repeat(count: 4) { .digit }
                OneOrMore(.whitespace)
                Repeat(count: 4) { .digit }
                OneOrMore(.whitespace)
                Capture { Repeat(count: 4) { .digit } }
            }
            
            if let match = try? cardNumRegex.firstMatch(in: text) {
                result.cardLastFour = String(match.1)
            }
        }
    }
    
    private func extractStatementDate(from rows: [RecognizedRow], into result: inout StatementAnalysisResult) {
        for (index, row) in rows.enumerated() {
            let text = row.text
            let uppercasedText = text.uppercased()
            
            // 查找 "Statement Date" 或 "结单日"
            if uppercasedText.contains(AppConstants.OCR.statementDate) || 
               text.contains(AppConstants.OCR.statementDateCN) ||
               text.contains("結單日") {
                // 1. 尝试在当前行找
                if let date = extractDate(from: text, formats: ["dd MMM yyyy", "yyyy-MM-dd", "dd/MM/yyyy"]) {
                    result.statementDate = date
                    logger.info("Found statement date in header row: \(date)")
                    break
                }
                
                // 2. 尝试在下一行找
                if index + 1 < rows.count {
                    let nextRow = rows[index + 1]
                    // 检查下一行是否只是一个日期，或者包含日期
                    if let date = extractDate(from: nextRow.text, formats: ["dd MMM yyyy", "yyyy-MM-dd", "dd/MM/yyyy"]) {
                        result.statementDate = date
                        logger.info("Found statement date in next row: \(date)")
                        break
                    }
                }
            }
        }
    }
    
    private func extractTransactionsFromTable(rows: [RecognizedRow], into result: inout StatementAnalysisResult, statementDate: Date?) {
        // 1. 找到表头
        guard let headerIndex = rows.firstIndex(where: { row in
            let text = row.text.uppercased()
            return text.contains(AppConstants.OCR.postDate) ||
                   text.contains(AppConstants.OCR.transDate) ||
                   text.contains(AppConstants.OCR.postingDateCN) ||
                   text.contains(AppConstants.OCR.transDateCN)
        }) else {
            logger.warning("未找到交易表头")
            return
        }
        
        // 2. 找到表尾
        let endIndex = rows.firstIndex(where: { row in
            let text = row.text.uppercased()
            return text.contains(AppConstants.OCR.rewardCash) ||
                   text.contains(AppConstants.OCR.summary) ||
                   text.contains(AppConstants.OCR.points) ||
                   text.contains(AppConstants.OCR.rewardCashCN)
        }) ?? rows.count
        
        // 3. 提取有效行
        guard headerIndex + 1 < endIndex else { return }
        let transactionRows = Array(rows[(headerIndex + 1)..<endIndex])
        
        // 4. 遍历解析
        var i = 0
        while i < transactionRows.count {
            let currentRow = transactionRows[i]
            let nextRow = (i + 1 < transactionRows.count) ? transactionRows[i + 1] : nil
            
            if var transaction = parseTableRow(currentRow, nextRow: nextRow, statementDate: statementDate) {
                // 检查后续行是否为 CBF 费用
                var cbfRowOffset = 0
                if let next = nextRow, isPaymentMethodRow(next) {
                    cbfRowOffset = 2
                } else {
                    cbfRowOffset = 1
                }
                
                let potentialCBFRow = (i + cbfRowOffset < transactionRows.count) ? transactionRows[i + cbfRowOffset] : nil
                
                if let cbfRow = potentialCBFRow,
                   let cbfTransaction = parseTableRow(cbfRow, nextRow: nil, statementDate: statementDate),
                   cbfTransaction.paymentMethod == AppConstants.Transaction.cbf {
                    
                    transaction.cbfFee = abs(cbfTransaction.billingAmount)
                    logger.debug("💰 检测到 CBF: \(transaction.cbfFee!) 合并至 \(transaction.description)")
                    i += cbfRowOffset
                }
                
                result.transactions.append(transaction)
                
                // 如果下一行是支付方式行，跳过
                if let next = nextRow, isPaymentMethodRow(next) {
                    i += 1
                }
            }
            i += 1
        }
    }
    
    /// 判断某一行是否为纯支付方式行（无日期和金额）
    private func isPaymentMethodRow(_ row: RecognizedRow) -> Bool {
        let text = row.text.uppercased()
        
        // 使用 AppConstants 中的检测列表
        let applePayKeywords = AppConstants.OCR.PaymentDetection.applePay.map { $0.uppercased() }
        let unionPayKeywords = AppConstants.OCR.PaymentDetection.unionPayQR.map { $0.uppercased() }
        
        let allKeywords = applePayKeywords + unionPayKeywords
        
        for keyword in allKeywords {
            if text.contains(keyword) { return true }
        }
        return false
    }
    
    // MARK: - 单行解析核心逻辑
    
    private func parseTableRow(_ row: RecognizedRow, nextRow: RecognizedRow? = nil, statementDate: Date? = nil) -> StatementAnalysisResult.ParsedTransaction? {
        let elements = row.elements
        guard elements.count >= 2 else { return nil }
        
        var transaction = StatementAnalysisResult.ParsedTransaction(description: "", billingAmount: 0)
        
        // 1. 提取日期
        let dates = extractAllDates(from: row.text, referenceDate: statementDate)
        if dates.count >= 2 {
            transaction.postDate = dates[0]
            transaction.transDate = dates[1]
        } else if dates.count == 1 {
            transaction.postDate = dates[0]
            transaction.transDate = dates[0]
        } else {
            // 没有日期，视为无效交易行（或者是其他描述行）
            return nil
        }
        
        // 2. 检测外币信息
        let foreignCurrencyInfo = extractForeignCurrencyInfo(from: elements)
        if let fcInfo = foreignCurrencyInfo {
            transaction.isForeignCurrency = true
            transaction.spendingCurrency = fcInfo.currency
            transaction.spendingAmount = fcInfo.amount
        }
        
        // 3. 提取金额（从后往前找）
        var amountIndex = -1
        for i in stride(from: elements.count - 1, through: 0, by: -1) {
            if let amount = extractAmountFromText(elements[i].text) {
                transaction.billingAmount = amount
                amountIndex = i
                break
            }
        }
        
        guard amountIndex >= 0 else { return nil }
        
        // 4. 重建描述
        transaction.description = buildDescription(
            from: elements,
            upTo: amountIndex,
            foreignInfo: foreignCurrencyInfo
        )
        
        if transaction.description.isEmpty && amountIndex > 0 {
            transaction.description = elements[amountIndex - 1].text
        }
        
        // 5. 后处理：修正 OCR 错误、检测支付方式
        transaction.description = TextCorrector.correctMerchantName(transaction.description)
        transaction.paymentMethod = detectPaymentMethod(from: transaction.description, amount: transaction.billingAmount)
        
        // 6. 标记特殊类型
        if isRefundOrRepayment(method: transaction.paymentMethod) {
            transaction.isRefundOrPayment = true
        }
        
        // 7. 如果是 SALE 且下一行是支付方式，尝试合并
        if transaction.paymentMethod == AppConstants.OCR.sale,
           let nextRow = nextRow,
           isPaymentMethodRow(nextRow),
           let nextMethod = detectPaymentMethod(from: nextRow.text, amount: abs(transaction.billingAmount)),
           !isRefundOrRepayment(method: nextMethod) && nextMethod != AppConstants.OCR.sale {
            
            transaction.paymentMethod = nextMethod
        }
        
        return transaction
    }
    
    // MARK: - 辅助逻辑
    
    private func buildDescription(from elements: [RecognizedElement], upTo index: Int, foreignInfo: (currency: String, amount: Double)?) -> String {
        var parts: [String] = []
        
        for i in 0..<index {
            let text = elements[i].text
            
            // 过滤日期、货币代码、外币金额
            if parseShortDate(text) != nil { continue }
            if isCurrencyCode(text) { continue }
            if foreignInfo != nil && extractAmountFromText(text) != nil { continue }
            
            if let cleaned = removeDatePrefix(from: text), !cleaned.isEmpty {
                parts.append(cleaned)
            } else if removeDatePrefix(from: text) == "" {
                // 纯日期前缀，跳过
            } else {
                parts.append(text)
            }
        }
        
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
    
    private func isRefundOrRepayment(method: String?) -> Bool {
        guard let method = method else { return false }
        return method == AppConstants.Transaction.refund ||
               method == AppConstants.Transaction.repayment ||
               method == AppConstants.OCR.autoRepayment ||
               method == AppConstants.OCR.instalment ||
               method == AppConstants.Transaction.cbf
    }
    
    private func detectPaymentMethod(from description: String, amount: Double) -> String? {
        let desc = description.uppercased()
        let correctedDesc = TextCorrector.correctMerchantName(desc)
        
        if OCRService.containsAny(AppConstants.OCR.PaymentDetection.applePay, in: correctedDesc) { return AppConstants.Transaction.applePay }
        if OCRService.containsAny(AppConstants.OCR.PaymentDetection.unionPayQR, in: correctedDesc) { return AppConstants.Transaction.unionPayQR }
        if OCRService.containsAny(AppConstants.OCR.PaymentDetection.autoRepayment, in: correctedDesc) { return AppConstants.OCR.autoRepayment }
        if OCRService.containsAny(AppConstants.OCR.PaymentDetection.repayment, in: correctedDesc) && amount < 0 { return AppConstants.Transaction.repayment }
        if OCRService.containsAny(AppConstants.OCR.PaymentDetection.instalment, in: correctedDesc) { return AppConstants.OCR.instalment }
        if OCRService.containsAny(AppConstants.OCR.PaymentDetection.cbf, in: correctedDesc) { return AppConstants.Transaction.cbf }
        
        if amount < 0 { return AppConstants.Transaction.refund }
        return AppConstants.OCR.sale
    }
    
    private func extractAllDates(from text: String, referenceDate: Date? = nil) -> [Date] {
        let correctedText = TextCorrector.correctDateText(text.uppercased())
        let matches = text.ranges(of: shortDateRegex)
        
        return matches.compactMap { range in
            let dateStr = String(text[range])
            // 这里我们需要提取捕获组的内容，但 ranges(of:) 返回的是整体范围
            // 对于 RegexBuilder，我们可以直接匹配并获取 Output
            // 简单起见，我们对匹配到的子串再做一次解析
            return parseShortDate(dateStr, referenceDate: referenceDate)
        }
    }
    
    private func removeDatePrefix(from text: String) -> String? {
        let correctedUpper = TextCorrector.correctDateText(text.uppercased())
        
        // 使用 Regex 替换
        let result = correctedUpper.replacing(datePrefixRegex, with: "")
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    private func extractAmountFromText(_ text: String) -> Double? {
        guard let match = try? amountRegex.firstMatch(in: text) else { return nil }
        
        let amountStr = String(match.1).replacingOccurrences(of: ",", with: "")
        guard let amount = Double(amountStr) else { return nil }
        
        // 检查 CR 后缀 (match.2 是 Optional<Substring>)
        let isCR = match.2 != nil
        return isCR ? -amount : amount
    }
    
    private func parseShortDate(_ dateStr: String, referenceDate: Date? = nil) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddMMM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        var cleanedStr = dateStr.replacingOccurrences(of: " ", with: "").uppercased()
        cleanedStr = TextCorrector.correctDateText(cleanedStr)
        
        guard let date = formatter.date(from: cleanedStr) else { return nil }
        
        // 智能年份推断
        var components = Calendar.current.dateComponents([.day, .month], from: date)
        
        if let refDate = referenceDate {
            // 如果有参考日期（结单日），以结单日为基准
            let refYear = Calendar.current.component(.year, from: refDate)
            let refMonth = Calendar.current.component(.month, from: refDate)
            
            components.year = refYear
            
            if let month = components.month {
                // 如果交易月份大于结单月份，说明是上一年的交易
                // 例如：结单日 2025年1月，交易日 12月 -> 2024年
                if month > refMonth {
                    components.year = refYear - 1
                }
            }
        } else {
            // 原有的基于当前日期的推断逻辑
            let currentYear = Calendar.current.component(.year, from: Date())
            let currentMonth = Calendar.current.component(.month, from: Date())
            
            components.year = currentYear
            
            if let month = components.month {
                if month >= 11 && currentMonth <= 2 {
                    components.year = currentYear - 1
                } else if month <= 2 && currentMonth >= 11 {
                    components.year = currentYear + 1
                }
            }
        }
        
        return Calendar.current.date(from: components)
    }
    
    private func extractDate(from text: String, formats: [String]) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        for format in formats {
            formatter.dateFormat = format
            // 这里用 DateFormatter 已经足够，不需要复杂的正则，除非格式很乱
            // 保持原逻辑的简单尝试
            
            // 如果需要提取日期字符串，可以使用 RegexBuilder 构建通用日期匹配器
            // 但考虑到格式多样性，DateFormatter.date(from:) 是最准的，前提是输入字符串比较干净
            // 我们可以尝试从文本中提取像日期的片段
            
            // 简单策略：尝试对整个字符串进行匹配，或者分割后匹配
            // 原有逻辑是用正则辅助提取，我们这里保留 DateFormatter 直接尝试（如果字符串只是日期）
            // 或者用 NSDataDetector (Vision 也可以检测日期，但我们这里是纯文本处理)
            
            // 为了兼容旧逻辑的灵活性，我们用 NSDataDetector
            if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
                let matches = detector.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                if let date = matches.first?.date {
                    return date
                }
            }
        }
        return nil
    }
    
    private func isCurrencyCode(_ text: String) -> Bool {
        let currencyCodes: Set<String> = Set(AppConstants.Currency.all.map { $0.uppercased() })
        return currencyCodes.contains(text.uppercased().trimmingCharacters(in: .whitespaces))
    }
    
    private func extractForeignCurrencyInfo(from elements: [RecognizedElement]) -> (currency: String, amount: Double)? {
        for i in 0..<(elements.count - 1) {
            let currentText = elements[i].text.uppercased().trimmingCharacters(in: .whitespaces)
            let nextText = elements[i + 1].text
            
            if isCurrencyCode(currentText), let amount = extractAmountFromText(nextText) {
                return (currency: currentText, amount: abs(amount))
            }
        }
        return nil
    }
}
