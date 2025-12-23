//
//  CSVService.swift
//  CashbackCounter
//
//  Created by Assistant on 12/21/25.
//

import Foundation
import SwiftUI
import SwiftData
import OSLog
import UniformTypeIdentifiers

/// 统一管理 CSV 导入导出的服务
struct CSVService {
    
    private static let logger = Logger.category("CSVService")
    
    // MARK: - Transaction Operations
    
    struct Transactions {
        
        static func parse(content: String, context: ModelContext, allCards: [CreditCard]) throws {
            let rows = content.components(separatedBy: .newlines)
            logger.info("开始解析交易 CSV，共 \(rows.count) 行")
            
            // 预先准备反查字典，提高匹配效率
            let categoryMap: [String: Category] = Dictionary(uniqueKeysWithValues: Category.allCases.map { ($0.displayName, $0) })
            let regionMap: [String: Region] = Dictionary(uniqueKeysWithValues: Region.allCases.map { ($0.rawValue, $0) })
            
            var successCount = 0
            var failCount = 0
            
            for (index, row) in rows.enumerated() {
                // 跳过表头(第0行)和空行
                if index == 0 || row.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                
                let columns = CSVParser.splitCSVLine(row)
                
                // 确保列数足够 (标准 15 列)
                guard columns.count >= 15 else {
                    logger.warning("行 \(index) 列数不足 (\(columns.count)/15)，跳过: \(row)")
                    failCount += 1
                    continue
                }
                
                // 1. 解析字段
                let dateStr = columns[0]
                let merchant = CSVParser.cleanField(columns[1])
                let categoryName = columns[2]
                let spendingAmount = Double(columns[3]) ?? 0.0
                let billingAmount = Double(columns[4]) ?? 0.0
                let cashback = Double(columns[5]) ?? 0.0
                // let ratePercent = Double(columns[6]) ?? 0.0 // 不需要
                let cardNameRaw = CSVParser.cleanField(columns[7])
                let cardEndNum = columns[8]
                let regionName = columns[9].trimmingCharacters(in: .whitespacesAndNewlines)
                let paymentMethod = columns[10] == AppConstants.Transaction.otherPaymentMethod ? "" : columns[10]
                let isOnline = columns[11].trimmingCharacters(in: .whitespaces) == AppConstants.CSV.yes
                let hasCBF = columns[12].trimmingCharacters(in: .whitespaces) == AppConstants.CSV.yes
                let cbfAmount = Double(columns[13]) ?? 0.0
                let isCreditTransaction = columns[14].trimmingCharacters(in: .whitespacesAndNewlines) == AppConstants.CSV.yes
                
                // 2. 类型转换
                guard let date = dateStr.toOptionalDate() else {
                    logger.warning("行 \(index) 日期格式错误: \(dateStr)")
                    failCount += 1
                    continue
                }
                
                let category = categoryMap[categoryName] ?? .other
                let region = regionMap[regionName] ?? .cn
                
                // 3. 找回对应的信用卡
                var matchedCard: CreditCard? = nil
                
                if cardEndNum != AppConstants.Transaction.noCard && cardNameRaw != AppConstants.Transaction.deletedCard {
                    matchedCard = allCards.first { card in
                        let dbCardName = "\(card.bankName)"
                        return card.endNum == cardEndNum && dbCardName == cardNameRaw
                    }
                    if matchedCard == nil {
                        matchedCard = allCards.first { $0.endNum == cardEndNum }
                    }
                }
                
                // 4. 创建并插入
                let newTransaction = Transaction(
                    merchant: merchant,
                    category: category,
                    location: region,
                    spendingAmount: spendingAmount,
                    date: date,
                    card: matchedCard,
                    paymentMethod: paymentMethod,
                    isOnlineShopping: isOnline,
                    isCBFApplied: hasCBF,
                    isCreditTransaction: isCreditTransaction,
                    billingAmount: billingAmount,
                    cashbackAmount: cashback,
                    cbfAmount: cbfAmount
                )
                
                context.insert(newTransaction)
                successCount += 1
            }
            
            logger.info("CSV 解析完成: 成功 \(successCount) 条, 失败 \(failCount) 条")
        }
        
        static func generate(from transactions: [Transaction]) -> String {
            var csvString = AppConstants.CSV.header
            
            for t in transactions {
                let date = t.dateString
                let safeMerchant = CSVParser.escapeField(t.merchant)
                let category = t.category.displayName
                let spendingAmount = String(format: "%.2f", t.spendingAmount)
                let billingAmount = String(format: "%.2f", t.billingAmount)
                let cashback = String(format: "%.2f", t.cashbackamount)
                let ratePercent = String(format: "%.2f", t.rate * 100)
                
                let cardNumber = t.card?.endNum ?? AppConstants.Transaction.noCard
                let cardName: String = t.card.map { CSVParser.escapeField($0.bankName) } ?? (t.paymentMethod == "手动返现" ? "奖赏钱账户" : AppConstants.Transaction.deletedCard)
                
                let region = t.location.rawValue
                let payment = t.paymentMethod.isEmpty ? AppConstants.Transaction.otherPaymentMethod : t.paymentMethod
                
                let isOnline = t.isOnlineShopping ? AppConstants.CSV.yes : AppConstants.CSV.no
                let hasCBF = t.isCBFApplied ? AppConstants.CSV.yes : AppConstants.CSV.no
                let cbfAmount = String(format: "%.2f", t.cbfAmount)
                let isCredit = t.isCreditTransaction ? AppConstants.CSV.yes : AppConstants.CSV.no
                
                let row = "\(date),\(safeMerchant),\(category),\(spendingAmount),\(billingAmount),\(cashback),\(ratePercent),\(cardName),\(cardNumber),\(region),\(payment),\(isOnline),\(hasCBF),\(cbfAmount),\(isCredit)\n"
                csvString.append(row)
            }
            return csvString
        }
    }
    
    // MARK: - Card Operations
    
    struct Cards {
        
        static func parse(content: String, into context: ModelContext) throws {
            let rows = content.components(separatedBy: .newlines)
            logger.info("开始解析卡片 CSV，共 \(rows.count) 行")
            
            var successCount = 0
            var failCount = 0
            
            for (index, row) in rows.enumerated() {
                if index == 0 || row.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                
                let columns = CSVParser.splitCSVLine(row)
                if columns.count < 19 {
                    logger.warning("行 \(index) 列数不足 (\(columns.count)/19)，跳过")
                    failCount += 1
                    continue
                }
                
                let bankName = CSVParser.cleanField(columns[0])
                let cardOrgRaw = columns[1]
                let cardLvlRaw = columns[2]
                let endNum = columns[3]
                let regionRaw = columns[4]
                let region = Region.allCases.first(where: { $0.rawValue == regionRaw }) ?? .cn
                
                let defRate = (Double(columns[5]) ?? 0) / 100.0
                
                let monthlyCap = Double(columns[6])
                let yearlyCap = Double(columns[7])
                
                var specialRates: [Category: Double] = [:]
                if let r = Double(columns[8]), r > 0 { specialRates[.dining] = r / 100.0 }
                if let r = Double(columns[9]), r > 0 { specialRates[.grocery] = r / 100.0 }
                if let r = Double(columns[10]), r > 0 { specialRates[.travel] = r / 100.0 }
                if let r = Double(columns[11]), r > 0 { specialRates[.digital] = r / 100.0 }
                if let r = Double(columns[12]), r > 0 { specialRates[.other] = r / 100.0 }
                
                var categoryCaps: [Category: Double] = [:]
                if let c = Double(columns[13]), c > 0 { categoryCaps[.dining] = c }
                if let c = Double(columns[14]), c > 0 { categoryCaps[.grocery] = c }
                if let c = Double(columns[15]), c > 0 { categoryCaps[.travel] = c }
                if let c = Double(columns[16]), c > 0 { categoryCaps[.digital] = c }
                if let c = Double(columns[17]), c > 0 { categoryCaps[.other] = c }
                
                let rDay = Int(columns[18]) ?? 0
                
                let cardOrg = CardOrganization(rawValue: cardOrgRaw) ?? .unionPay
                let cardLvl = CardLevel(rawValue: cardLvlRaw) ?? .unionPayStandard
                
                let newCard = CreditCard(
                    bankName: bankName,
                    cardOrganization: cardOrg,
                    cardLevel: cardLvl,
                    endNum: endNum,
                    defaultRate: defRate,
                    specialRates: specialRates,
                    issueRegion: region,
                    monthlyBaseCap: monthlyCap,
                    yearlyBaseCap: yearlyCap,
                    categoryCaps: categoryCaps,
                    repaymentDay: rDay
                )
                context.insert(newCard)
                successCount += 1
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationManager.shared.scheduleNotification(for: newCard)
                }
            }
            logger.info("卡片解析完成: 成功 \(successCount) 条, 失败 \(failCount) 条")
        }
        
        static func generate(from cards: [CreditCard]) -> String {
            var csvString = AppConstants.CSV.cardHeader + "\n"
            
            for card in cards {
                let bank = card.bankName.replacingOccurrences(of: ",", with: AppConstants.CSV.fullWidthComma)
                let cardOrg = card.cardOrganization.rawValue
                let cardLvl = card.cardLevel.rawValue
                let endNum = card.endNum
                
                let region = card.issueRegion.rawValue
                let defRate = String(format: "%.2f", card.defaultRate * 100)
                let monthlyCap = card.monthlyBaseCap != nil && card.monthlyBaseCap! > 0 ? String(format: "%.0f", card.monthlyBaseCap!) : ""
                let yearlyCap = card.yearlyBaseCap != nil && card.yearlyBaseCap! > 0 ? String(format: "%.0f", card.yearlyBaseCap!) : ""
                
                let diningRate = fmtRate(card.specialRates[.dining])
                let groceryRate = fmtRate(card.specialRates[.grocery])
                let travelRate = fmtRate(card.specialRates[.travel])
                let digitalRate = fmtRate(card.specialRates[.digital])
                let otherRate = fmtRate(card.specialRates[.other])
                
                let diningCap = fmtCap(card.categoryCaps[.dining])
                let groceryCap = fmtCap(card.categoryCaps[.grocery])
                let travelCap = fmtCap(card.categoryCaps[.travel])
                let digitalCap = fmtCap(card.categoryCaps[.digital])
                let otherCap = fmtCap(card.categoryCaps[.other])
                
                let repaymentDay = card.repaymentDay > 0 ? String(card.repaymentDay) : ""
                
                let row = "\(bank),\(cardOrg),\(cardLvl),\(endNum),\(region),\(defRate),\(monthlyCap),\(yearlyCap),\(diningRate),\(groceryRate),\(travelRate),\(digitalRate),\(otherRate),\(diningCap),\(groceryCap),\(travelCap),\(digitalCap),\(otherCap),\(repaymentDay)\n"
                csvString.append(row)
            }
            return csvString
        }
        
        private static func fmtRate(_ val: Double?) -> String {
            guard let v = val else { return "" }
            return Formatters.percentage(v)
        }
        
        private static func fmtCap(_ val: Double?) -> String {
            guard let v = val, v > 0 else { return "" }
            return Formatters.wholeNumber(v)
        }
    }
}

// MARK: - Extensions for Convenience

extension Array where Element == Transaction {
    func generateCSV() -> String {
        return CSVService.Transactions.generate(from: self)
    }
    
    func exportCSVFile() -> URL? {
        let content = self.generateCSV()
        // print("here") // Removed debug print
        return CSVFileManager.saveCSV(content: content, prefix: AppConstants.CSV.transactionFileNamePrefix)
    }
}

extension Array where Element == CreditCard {
    func generateCSV() -> String {
        return CSVService.Cards.generate(from: self)
    }
    
    func exportCSVFile() -> URL? {
        let content = self.generateCSV()
        // print("here") // Removed debug print
        return CSVFileManager.saveCSV(content: content, prefix: AppConstants.CSV.cardFileNamePrefix)
    }
}

// MARK: - Transferable Wrappers

struct TransactionCSV: Transferable {
    let transactions: [Transaction]
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .commaSeparatedText) { container in
            let content = container.transactions.generateCSV()
            if let url = CSVFileManager.saveCSV(content: content, prefix: AppConstants.CSV.transactionFileNamePrefix) {
                return SentTransferredFile(url)
            } else {
                throw CSVExportError.saveFailed
            }
        } importing: { received in
            // Importing is handled via .fileImporter in Views, but this is required by some Transferable implementations
            // Returning a placeholder as we don't use drag-and-drop import for this type yet
            return TransactionCSV(transactions: [])
        }
    }
}

struct CardCSV: Transferable {
    let cards: [CreditCard]
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .commaSeparatedText) { container in
            let content = container.cards.generateCSV()
            if let url = CSVFileManager.saveCSV(content: content, prefix: AppConstants.CSV.cardFileNamePrefix) {
                return SentTransferredFile(url)
            } else {
                throw CSVExportError.saveFailed
            }
        } importing: { received in
            // Importing is handled via .fileImporter in Views
            return CardCSV(cards: [])
        }
    }
}

enum CSVExportError: Error {
    case saveFailed
}
