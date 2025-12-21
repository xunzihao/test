//
//  CashbackService.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import Foundation
import OSLog
import SwiftData

struct CashbackService {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CashbackCounter", category: "CashbackService")
    
    // MARK: - Core Calculation (Moved from CreditCard)
    
    static func calculateCashback(for transaction: Transaction) -> Double {
        guard let card = transaction.card else {
            logger.debug("交易无关联卡片，返回原有返现金额: \(transaction.cashbackamount)")
            return transaction.cashbackamount
        }
        
        return calculateCappedCashback(
            card: card,
            amount: transaction.billingAmount,
            category: transaction.category,
            location: transaction.location,
            date: transaction.date,
            transactionToExclude: transaction
        )
    }
    
    static func calculateCappedCashback(
        card: CreditCard,
        amount: Double,
        category: Category,
        location: Region,
        date: Date,
        transactionToExclude: Transaction? = nil
    ) -> Double {
        
        let baseRate = card.defaultRate
        let potentialBaseReward = amount * baseRate
        
        let bonusRate = card.specialRates[category] ?? 0.0
        let potentialBonusReward = amount * bonusRate
        
        // 准备上限阈值
        let monthlyCapLimit = card.monthlyBaseCap ?? 0
        let yearlyCapLimit = card.yearlyBaseCap ?? 0
        let categoryCapLimit = card.categoryCaps[category] ?? 0.0
        
        // 统计历史用量
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: date)
        
        // 筛选时排除掉“正在编辑的这一笔”
        let yearlyTransactions = (card.transactions ?? []).filter {
            let isSameYear = calendar.component(.year, from: $0.date) == currentYear
            let isNotSelf = ($0 != transactionToExclude) // 排除自己
            return isSameYear && isNotSelf
        }
        
        // A. 计算已用基础返现（一次遍历完成月度+年度统计）
        var usedBaseMonthly: Double = 0
        var usedBaseYearly: Double = 0
        
        for t in yearlyTransactions {
            let isMonthly = calendar.isDate(t.date, equalTo: date, toGranularity: .month)
            let baseReward = t.billingAmount * card.defaultRate
            usedBaseYearly += baseReward
            if isMonthly {
                usedBaseMonthly += baseReward
            }
        }
        
        // B. 计算已用加成返现 (估算值)
        var usedBonus: Double = 0
        if categoryCapLimit > 0 {
            usedBonus = yearlyTransactions
                .filter { $0.category == category }
                .reduce(0) { sum, t in
                    let tBonusRate = card.specialRates[t.category] ?? 0.0
                    return sum + (t.billingAmount * tBonusRate)
                }
        }
        
        // --- 第四步：结算 (Reward Cap 逻辑) ---
        
        // 1. 结算基础返现（考虑月度和年度双重限制）
        var finalBase = potentialBaseReward
        
        // 先检查月度上限
        if monthlyCapLimit > 0 {
            let monthlyRemaining = max(0, monthlyCapLimit - usedBaseMonthly)
            finalBase = min(finalBase, monthlyRemaining)
        }
        
        // 再检查年度上限（取更严格的）
        if yearlyCapLimit > 0 {
            let yearlyRemaining = max(0, yearlyCapLimit - usedBaseYearly)
            finalBase = min(finalBase, yearlyRemaining)
        }
        
        // 2. 结算类别加成返现
        var finalBonus = potentialBonusReward
        if categoryCapLimit > 0 {
            let remaining = max(0, categoryCapLimit - usedBonus)
            finalBonus = min(potentialBonusReward, remaining)
        }
        
        return finalBase + finalBonus
    }
    
    // MARK: - Detailed Calculation
    
    /// 返现计算过程和结果
    struct CashbackCalculationResult {
        /// 计算步骤详情
        var steps: [String] = []
        /// 最终返现金额
        var finalCashback: Double = 0.0
        /// 使用的返现率
        var rate: Double = 0.0
        /// 计算用的金额（已转换并加FTF，但不含CBF）
        var calculationAmount: Double = 0.0
        /// CBF 费用（如果适用）
        var cbfAmount: Double = 0.0
        /// 总成本（入账金额 + CBF）
        var totalCost: Double = 0.0
    }
    
    /// 计算返现（考虑FTF、汇率、规则匹配等）
    static func calculateCashbackWithDetails(
        card: CreditCard,
        originalAmount: Double,
        sourceCurrency: String,
        paymentMethod: String,
        isOnlineShopping: Bool,
        isCBFApplied: Bool = false,
        category: Category,
        location: Region,
        date: Date,
        selectedConditionIndex: Int? = nil,
        transactionToExclude: Transaction? = nil,
        providedBillingAmount: Double? = nil
    ) async -> CashbackCalculationResult {
        var result = CashbackCalculationResult()
        var steps: [String] = []
        
        // 1. 计算入账金额（包含FTF和汇率转换）
        let billingAmount: Double
        if let provided = providedBillingAmount {
            billingAmount = provided
        } else {
            billingAmount = await calculateBillingAmount(card: card, amount: originalAmount, sourceCurrency: sourceCurrency)
        }
        result.calculationAmount = billingAmount
        
        // 判断是否是Pulse卡
        let isPulseCard = card.bankName.lowercased().contains(AppConstants.Card.pulseKeyword)
        
        // 确定实际入账币种
        let billingCurrency: String
        if isPulseCard && sourceCurrency == AppConstants.Currency.cny {
            billingCurrency = AppConstants.Currency.cny
        } else if isPulseCard {
            billingCurrency = AppConstants.Currency.hkd
        } else {
            billingCurrency = card.issueRegion.currencyCode
        }
        
        steps.append(String(format: AppConstants.CashbackDetail.originalAmount, "\(originalAmount) \(sourceCurrency)"))
        
        // 如果进行了币种转换，显示转换过程
        if sourceCurrency != billingCurrency {
            let rates = await CurrencyService.getRates(base: sourceCurrency)
            let exchangeRate = rates[billingCurrency] ?? 1.0
            
            let shouldChargeFTF = !card.ftfExceptCurrencyCodes.contains(sourceCurrency)
            
            if shouldChargeFTF {
                let ftfPercent = card.ftf * 100
                steps.append(String(format: AppConstants.CashbackDetail.exchangeRateConversion, "\(originalAmount)", String(format: "%.4f", exchangeRate), "\(originalAmount * exchangeRate) \(billingCurrency)"))
                steps.append(String(format: AppConstants.CashbackDetail.ftfFee, "\(originalAmount * exchangeRate)", String(format: "%.2f", ftfPercent), "\(originalAmount * exchangeRate * card.ftf) \(billingCurrency)"))
                steps.append(String(format: AppConstants.CashbackDetail.billingAmount, "\(originalAmount * exchangeRate)", String(format: "%.2f", ftfPercent), "\(billingAmount) \(billingCurrency)"))
            } else {
                steps.append(String(format: AppConstants.CashbackDetail.exchangeRateConversionNoFTF, "\(originalAmount)", String(format: "%.4f", exchangeRate), "\(billingAmount) \(billingCurrency)"))
            }
        } else {
            steps.append(String(format: AppConstants.CashbackDetail.billingAmountNoConversion, "\(billingAmount) \(billingCurrency)"))
        }
        
        // 2. 选择适用的规则并获取返现率
        let matchCurrency = (sourceCurrency == AppConstants.Currency.otherCurrency) ? billingCurrency : sourceCurrency
        
        let baseRate: Double
        
        if let index = selectedConditionIndex {
            baseRate = getCashbackRate(card: card, at: index)
            steps.append(String(format: AppConstants.CashbackDetail.usingRuleManual, index + 1))
            let ratePercent = baseRate * 100
            steps.append(String(format: AppConstants.CashbackDetail.baseCashbackRate, String(format: "%.2f", ratePercent)))
        } else {
            // 自动匹配
            var matchedIndex: Int?
            if let data = card.baseCashbackConditionsData,
               let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for (index, _) in jsonArray.enumerated() {
                    if doesRuleMatch(card: card, at: index, sourceCurrency: matchCurrency, paymentMethod: paymentMethod, isOnlineShopping: isOnlineShopping) {
                        matchedIndex = index
                        break
                    }
                }
            }
            
            if let index = matchedIndex {
                baseRate = getCashbackRate(card: card, at: index)
                steps.append(String(format: AppConstants.CashbackDetail.usingRuleAuto, index + 1, matchCurrency))
                let ratePercent = baseRate * 100
                steps.append(String(format: AppConstants.CashbackDetail.baseCashbackRate, String(format: "%.2f", ratePercent)))
            } else {
                // 未匹配到规则
                baseRate = 0.0
                steps.append(AppConstants.CashbackDetail.noRuleMatched)
                steps.append(String(format: AppConstants.CashbackDetail.cashbackAmountZero, billingCurrency))
                
                result.steps = steps
                result.finalCashback = 0.0
                result.rate = 0.0
                result.cbfAmount = 0.0
                result.totalCost = billingAmount
                return result
            }
        }
        
        result.rate = baseRate
        
        // 3. 计算类别加成
        let bonusRate = card.specialRates[category] ?? 0.0
        let totalRate = baseRate + bonusRate
        
        if bonusRate > 0 {
            let bonusPercent = bonusRate * 100
            steps.append("类别加成: \(String(format: "%.2f", bonusPercent))%")
            steps.append("总返现率: \(String(format: "%.2f", baseRate * 100))% + \(String(format: "%.2f", bonusPercent))% = \(String(format: "%.2f", totalRate * 100))%")
        } else {
            steps.append("总返现率: \(String(format: "%.2f", totalRate * 100))%")
        }
        
        // 4. 计算理论返现
        let theoreticalCashback = billingAmount * totalRate
        steps.append("理论返现: \(billingAmount) × \(String(format: "%.4f", totalRate)) = \(String(format: "%.2f", theoreticalCashback)) \(billingCurrency)")
        
        // 5. 应用上限
        let potentialBaseReward = billingAmount * baseRate
        let potentialBonusReward = billingAmount * bonusRate
        
        let yearlyCapLimit = card.yearlyBaseCap ?? 0
        let categoryCapLimit = card.categoryCaps[category] ?? 0.0
        let hasYearlyCap = yearlyCapLimit > 0
        let hasCategoryCap = categoryCapLimit > 0
        
        // 统计历史用量
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: date)
        let yearlyTransactions = (card.transactions ?? []).filter {
            let isSameYear = calendar.component(.year, from: $0.date) == currentYear
            let isNotSelf = ($0 != transactionToExclude)
            return isSameYear && isNotSelf
        }
        
        var actualBaseReward: Double
        if hasYearlyCap {
            let usedYearlyReward = yearlyTransactions.reduce(0) { $0 + $1.cashbackamount }
            let remainingYearlyCap = max(0, Double(yearlyCapLimit) - usedYearlyReward)
            actualBaseReward = min(potentialBaseReward, remainingYearlyCap)
        } else {
            actualBaseReward = potentialBaseReward
        }
        
        var actualBonusReward = potentialBonusReward
        if hasCategoryCap {
            let usedCategoryCap = yearlyTransactions
                .filter { $0.category == category }
                .reduce(0) { sum, transaction in
                    let bRate = (transaction.card?.specialRates[transaction.category] ?? 0.0)
                    return sum + bRate * transaction.billingAmount
                }
            let remainingCategoryCap = max(0, categoryCapLimit - usedCategoryCap)
            actualBonusReward = min(actualBonusReward, remainingCategoryCap)
        }
        
        let finalCashback = actualBaseReward + actualBonusReward
        
        if finalCashback < theoreticalCashback - 0.01 {
            steps.append(String(format: AppConstants.CashbackDetail.cappedFinalCashback, "\(String(format: "%.2f", finalCashback)) \(billingCurrency)"))
        } else {
            steps.append(String(format: AppConstants.CashbackDetail.finalCashback, "\(String(format: "%.2f", finalCashback)) \(billingCurrency)"))
        }
        
        // 6. 处理 CBF
        var cbfAmount: Double = 0.0
        var totalCost = billingAmount
        
        if isCBFApplied {
            cbfAmount = billingAmount * card.cbf
            totalCost = billingAmount + cbfAmount
            let cbfPercent = card.cbf * 100
            
            steps.append("")
            steps.append(AppConstants.CashbackDetail.cbfFeeTitle)
            steps.append(String(format: AppConstants.CashbackDetail.cbfRate, String(format: "%.2f", cbfPercent)))
            steps.append(String(format: AppConstants.CashbackDetail.cbfAmount, String(format: "%.2f", billingAmount), String(format: "%.2f", cbfPercent), "\(String(format: "%.2f", cbfAmount)) \(billingCurrency)"))
            steps.append(AppConstants.CashbackDetail.cbfNote)
            steps.append(String(format: AppConstants.CashbackDetail.totalCost, String(format: "%.2f", billingAmount), String(format: "%.2f", cbfAmount), "\(String(format: "%.2f", totalCost)) \(billingCurrency)"))
        }
        
        result.steps = steps
        result.finalCashback = finalCashback
        result.cbfAmount = cbfAmount
        result.totalCost = totalCost
        
        return result
    }
    
    // MARK: - Helpers
    
    static func calculateBillingAmount(card: CreditCard, amount: Double, sourceCurrency: String) async -> Double {
        let isPulseCard = card.bankName.lowercased().contains("pulse")
        
        if isPulseCard {
            if sourceCurrency == AppConstants.Currency.cny { return amount }
            else {
                let shouldChargeFTF = !card.ftfExceptCurrencyCodes.contains(sourceCurrency)
                let ftfMultiplier = shouldChargeFTF ? (1.0 + card.ftf) : 1.0
                let rates = await CurrencyService.getRates(base: sourceCurrency)
                let exchangeRate = rates[AppConstants.Currency.hkd] ?? 1.0
                return amount * exchangeRate * ftfMultiplier
            }
        } else {
            let targetCurrency = card.issueRegion.currencyCode
            if sourceCurrency == targetCurrency { return amount }
            
            let shouldChargeFTF = !card.ftfExceptCurrencyCodes.contains(sourceCurrency)
            let ftfMultiplier = shouldChargeFTF ? (1.0 + card.ftf) : 1.0
            let rates = await CurrencyService.getRates(base: sourceCurrency)
            let exchangeRate = rates[targetCurrency] ?? 1.0
            return amount * exchangeRate * ftfMultiplier
        }
    }
    
    // MARK: - Rule Matching
    
    /// 返现规则摘要（用于UI显示和选择）
    struct CashbackRuleSummary: Identifiable {
        let id: Int
        let displayName: String
        let rate: Double
    }
    
    static func getCashbackRuleSummaries(card: CreditCard) -> [CashbackRuleSummary] {
        guard let data = card.baseCashbackConditionsData,
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return [CashbackRuleSummary(id: 0, displayName: "\(AppConstants.CashbackDetail.defaultRule) (\(String(format: "%.2f", card.defaultRate * 100))%)", rate: card.defaultRate)]
        }
        
        var summaries: [CashbackRuleSummary] = []
        for (index, json) in jsonArray.enumerated() {
            let rateInt = json["rate"] as? Int ?? Int(card.defaultRate * 10000)
            let rate = Double(rateInt) / 10000.0
            let paymentMethods = json["paymentMethods"] as? [String] ?? []
            let paymentMethodStr = paymentMethods.isEmpty ? AppConstants.CashbackDetail.unlimited : paymentMethods.joined(separator: "/")
            let displayName = String(format: AppConstants.CashbackDetail.ruleFormat, index + 1, paymentMethodStr, String(format: "%.2f", rate * 100))
            summaries.append(CashbackRuleSummary(id: index, displayName: displayName, rate: rate))
        }
        
        if summaries.isEmpty {
            summaries.append(CashbackRuleSummary(id: 0, displayName: "\(AppConstants.CashbackDetail.defaultRule) (\(String(format: "%.2f", card.defaultRate * 100))%)", rate: card.defaultRate))
        }
        return summaries
    }
    
    static func getCashbackRate(card: CreditCard, at index: Int) -> Double {
        guard let data = card.baseCashbackConditionsData,
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              index < jsonArray.count else {
            return card.defaultRate
        }
        let json = jsonArray[index]
        let rateInt = json["rate"] as? Int ?? Int(card.defaultRate * 10000)
        return Double(rateInt) / 10000.0
    }
    
    static func doesRuleMatch(card: CreditCard, at index: Int, sourceCurrency: String, paymentMethod: String, isOnlineShopping: Bool) -> Bool {
        guard let data = card.baseCashbackConditionsData,
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              index < jsonArray.count else {
            return false
        }
        
        let rule = jsonArray[index]
        
        // 1. 检查币种
        if let currenciesData = rule["currencies"] {
            var currencyMatches = false
            let commonCurrencies = [
                AppConstants.Currency.cny, AppConstants.Currency.hkd, AppConstants.Currency.mop,
                AppConstants.Currency.usd, AppConstants.Currency.jpy, AppConstants.Currency.krw,
                AppConstants.Currency.twd
            ]
            
            if let currencyArray = currenciesData as? [String] {
                if currencyArray.contains(AppConstants.Currency.all) || currencyArray.contains(Currency.all.rawValue) { currencyMatches = true }
                else if currencyArray.contains(sourceCurrency) { currencyMatches = true }
                else if (currencyArray.contains(AppConstants.Currency.otherCurrency) || currencyArray.contains(Currency.other.rawValue)) && !commonCurrencies.contains(sourceCurrency) { currencyMatches = true }
            } else if let currencyDict = currenciesData as? [String: Any] {
                let currencyValues = currencyDict.values.compactMap { $0 as? String }
                if currencyValues.contains(AppConstants.Currency.all) || currencyValues.contains(Currency.all.rawValue) { currencyMatches = true }
                else if currencyValues.contains(sourceCurrency) { currencyMatches = true }
                else if (currencyValues.contains(AppConstants.Currency.otherCurrency) || currencyValues.contains(Currency.other.rawValue)) && !commonCurrencies.contains(sourceCurrency) { currencyMatches = true }
            }
            if !currencyMatches { return false }
        }
        
        // 2. 检查支付方式
        if let paymentMethods = rule["paymentMethods"] as? [String] {
            let paymentMatches = paymentMethods.contains(paymentMethod) || paymentMethods.contains(AppConstants.Transaction.unfillPaymentMethod)
            if !paymentMatches { return false }
        }
        
        // 3. 检查交易类型
        if let transactionType = rule["transactionType"] as? String {
            switch transactionType {
            case AppConstants.Transaction.onlineShopping: if !isOnlineShopping { return false }
            case AppConstants.Transaction.offlineShopping: if isOnlineShopping { return false }
            default: break
            }
        }
        
        return true
    }
    
    // MARK: - Basic Helpers
    
    static func getCardName(for transaction: Transaction) -> String {
        guard let card = transaction.card else { return AppConstants.Transaction.deletedCard }
        return card.bankName
    }
    
    static func getCardNum(for transaction: Transaction) -> String {
        guard let card = transaction.card else { return AppConstants.Transaction.deletedCard }
        return card.endNum
    }
    
    static func getCurrency(for transaction: Transaction) -> String {
        return transaction.location.currencySymbol
    }
    
    static func getRate(for transaction: Transaction) -> Double {
        guard let card = transaction.card else { return 0.0 }
        return card.getRate(for: transaction.category, location: transaction.location)
    }
}
