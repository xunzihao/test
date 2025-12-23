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
        // 🚀 特殊处理：手动返现交易 (Spending=0, Cashback>0)
        // 这种情况下，直接返回存储的返现金额，不再进行重新计算
        if transaction.spendingAmount == 0 && transaction.cashbackamount > 0 {
            return transaction.cashbackamount
        }
        
        guard let card = transaction.card else {
            logger.debug("交易无关联卡片，返回原有返现金额: \(transaction.cashbackamount)")
            return transaction.cashbackamount
        }
        
        return calculateCappedCashback(
            card: card,
            billingAmount: transaction.billingAmount,
            category: transaction.category,
            location: transaction.location,
            date: transaction.date,
            transactionToExclude: transaction
        )
    }
    
    static func calculateCappedCashback(
        card: CreditCard,
        billingAmount: Double,
        category: Category,
        location: Region,
        date: Date,
        transactionToExclude: Transaction? = nil
    ) -> Double {
        
        let baseRate = card.defaultRate
        let potentialBaseReward = billingAmount * baseRate
        
        let bonusRate = card.specialRates[category] ?? 0.0
        let potentialBonusReward = billingAmount * bonusRate
        
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
        spendingAmount: Double,
        spendingCurrencyCode: String,
        paymentMethod: String,
        isOnlineShopping: Bool,
        isCBFApplied: Bool = false,
        category: Category,
        location: Region,
        date: Date,
        selectedConditionIndex: Int? = nil,
        transactionToExclude: Transaction? = nil,
        billingAmount: Double? = nil
    ) async -> CashbackCalculationResult {
        var result = CashbackCalculationResult()
        var steps: [String] = []
        
        // 🖨️ 控制台日志：开始计算
        logger.debug("\n============================================================")
        logger.debug("💰 返现计算开始")
        logger.debug("============================================================")
        logger.debug("📋 输入参数:")
        logger.debug("  • 消费金额: \(spendingAmount) \(spendingCurrencyCode)")
        logger.debug("  • 入账金额: \(billingAmount as NSObject?) \(card.issueRegion.currencyCode)")
        logger.debug("  • 支付方式: \(paymentMethod)")
        logger.debug("  • 是否网购: \(isOnlineShopping ? "是" : "否")")
        logger.debug("  • 是否适用CBF: \(isCBFApplied ? "是" : "否")")
        logger.debug("  • 消费类别: \(category.displayName)")
        logger.debug("  • 消费地区: \(location.rawValue)")
        logger.debug("  • 交易日期: \(date.formatted(date: .long, time: .omitted))")
        if let ruleIndex = selectedConditionIndex {
            logger.debug("  • 选中规则: 规则\(ruleIndex + 1)")
        } else {
            logger.debug("  • 选中规则: 自动匹配")
        }
        
        // 1. 计算入账金额（包含FTF和汇率转换）
        logger.debug("\n------------------------------------------------------------")
        logger.debug("📊 步骤 1: 计算入账金额")
        logger.debug("------------------------------------------------------------")
        
        // 确定实际入账币种
         let billingCurrencyCode = card.issueRegion.currencyCode
        logger.debug("  • 入账币种: \(billingCurrencyCode)")
        logger.debug("  • 交易币种: \(spendingCurrencyCode)")
         var finalBillingAmount: Double
         finalBillingAmount = billingAmount ?? 0.0
        if let finalBillingAmount = billingAmount , finalBillingAmount > 0 {
            steps.append(String(format: AppConstants.CashbackDetail.originalAmount, "\(spendingAmount) \(spendingCurrencyCode)"))
            steps.append(String(format: AppConstants.CashbackDetail.billingAmount, "\(finalBillingAmount) \(billingCurrencyCode)"))

            // if let finalBillingAmount = billingAmount {
            // } else {
            //      steps.append(String(format: AppConstants.CashbackDetail.billingAmount, "0.00 \(billingCurrencyCode)"))
            }
        // } else {
        //     // 没有提供入账金额，需要自动计算
        //     logger.debug("  🧮 未提供入账金额，开始自动计算...")
        //     finalBillingAmount = await calculateBillingAmount(card: card, spendingAmount: spendingAmount, spendingCurrencyCode: spendingCurrencyCode)
        //     logger.debug("  ✅ 计算后的入账金额: \(String(format: "%.2f", finalBillingAmount)) \(billingCurrencyCode)")
        //     steps.append(String(format: AppConstants.CashbackDetail.originalAmount, "\(spendingAmount) \(spendingCurrencyCode)"))
        // }
        // result.calculationAmount = finalBillingAmount
        
        // 2. 选择适用的规则并获取返现率
        logger.debug("\n------------------------------------------------------------")
        logger.debug("📊 步骤 2: 选择返现规则")
        logger.debug("------------------------------------------------------------")
        
        // 🔑 规则匹配应该始终使用原始消费币种
        // 因为返现规则是针对"用什么币种消费"而设定的，而不是"入账多少钱"
        logger.debug("  • 规则匹配使用币种: \(spendingCurrencyCode)")
        
        let baseRate: Double
        
        if let index = selectedConditionIndex {
            baseRate = getCashbackRate(card: card, at: index)
            logger.debug("  ✅ 使用规则: 规则\(index + 1) (手动选择)")
            logger.debug("  • 基础返现率: \(String(format: "%.2f", baseRate * 100))%")
            
            steps.append(String(format: AppConstants.CashbackDetail.usingRuleManual, index + 1))
            let ratePercent = baseRate * 100
            steps.append(String(format: AppConstants.CashbackDetail.baseCashbackRate, String(format: "%.2f", ratePercent)))
        } else {
            logger.debug("  🔍 开始自动匹配规则...")
            
            // 自动匹配：找到第一个匹配的规则
            var matchedIndex: Int?
            if let data = card.baseCashbackConditionsData,
               let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                logger.debug("  • 共有 \(jsonArray.count) 条规则可匹配")
                
                for (index, _) in jsonArray.enumerated() {
                    logger.debug("    - 检查规则\(index + 1)...")
                    
                    // 👇 使用 matchCurrency 进行匹配（可能是原币种或入账币种）
                    if doesRuleMatch(card: card, at: index, spendingCurrencyCode: spendingCurrencyCode, paymentMethod: paymentMethod, isOnlineShopping: isOnlineShopping) {
                        matchedIndex = index
                        logger.debug("✅ 匹配成功")
                        break
                    } else {
                        logger.debug("❌ 不匹配")
                    }
                }
            }
            
            if let index = matchedIndex {
                baseRate = getCashbackRate(card: card, at: index)
                logger.debug("  ✅ 最终匹配: 规则\(index + 1)")
                logger.debug("  • 基础返现率: \(String(format: "%.2f", baseRate * 100))%")
                
                steps.append(String(format: AppConstants.CashbackDetail.usingRuleAuto, index + 1))
                let ratePercent = baseRate * 100
                steps.append(String(format: AppConstants.CashbackDetail.baseCashbackRate, String(format: "%.2f", ratePercent)))
            } else {
                // 👇 未匹配到规则：不进行任何返现计算
                baseRate = 0.0
                logger.debug("  ⚠️ 未匹配到任何返现规则")
                logger.debug("  • 返现金额: 0.00 \(billingCurrencyCode)")
                
                steps.append(AppConstants.CashbackDetail.noRuleMatched)
                steps.append(String(format: AppConstants.CashbackDetail.cashbackAmountZero, billingCurrencyCode))
                
                result.steps = steps
                result.finalCashback = 0.0
                result.rate = 0.0
                result.cbfAmount = 0.0
                result.totalCost = finalBillingAmount
                
                logger.debug("============================================================")
                logger.debug("✅ 返现计算结束 (无匹配规则)")
                logger.debug("============================================================\n")
                
                return result
            }
        }
        
        result.rate = baseRate
        
        // 3. 计算类别加成
        logger.debug("\n------------------------------------------------------------")
        logger.debug("📊 步骤 3: 计算类别加成")
        logger.debug("------------------------------------------------------------")
        
        let bonusRate = card.specialRates[category] ?? 0.0
        let totalRate = baseRate + bonusRate
        
        logger.debug("  • 基础返现率: \(String(format: "%.2f", baseRate * 100))%")
        logger.debug("  • 类别加成率: \(String(format: "%.2f", bonusRate * 100))%")
        logger.debug("  • 总返现率: \(String(format: "%.2f", totalRate * 100))%")
        
        if bonusRate > 0 {
            let bonusPercent = bonusRate * 100
            steps.append("类别加成: \(String(format: "%.2f", bonusPercent))%")
            steps.append("总返现率: \(String(format: "%.2f", baseRate * 100))% + \(String(format: "%.2f", bonusPercent))% = \(String(format: "%.2f", totalRate * 100))%")
        } else {
            steps.append("总返现率: \(String(format: "%.2f", totalRate * 100))%")
        }
        
        // 4. 计算理论返现
        logger.debug("\n------------------------------------------------------------")
        logger.debug("📊 步骤 4: 计算理论返现")
        logger.debug("------------------------------------------------------------")
        
        let theoreticalCashback = finalBillingAmount * totalRate
        logger.debug("  • 入账金额: \(String(format: "%.2f", finalBillingAmount)) \(billingCurrencyCode)")
        logger.debug("  • 总返现率: \(String(format: "%.4f", totalRate))")
        logger.debug("  • 理论返现: \(String(format: "%.2f", finalBillingAmount)) × \(String(format: "%.4f", totalRate)) = \(String(format: "%.2f", theoreticalCashback)) \(billingCurrencyCode)")
        
        steps.append("理论返现: \(finalBillingAmount) × \(String(format: "%.4f", totalRate)) = \(String(format: "%.2f", theoreticalCashback)) \(billingCurrencyCode)")
        
        // 5. 应用上限
        logger.debug("\n------------------------------------------------------------")
        logger.debug("📊 步骤 5: 应用返现上限")
        logger.debug("------------------------------------------------------------")
        
        // 👇 手动计算封顶返现，而不是调用 calculateCappedCashback（它用的是 defaultRate）
        let potentialBaseReward = finalBillingAmount * baseRate
        let potentialBonusReward = finalBillingAmount * bonusRate
        
        logger.debug("  • 潜在基础返现: \(String(format: "%.2f", potentialBaseReward)) \(billingCurrencyCode)")
        logger.debug("  • 潜在类别加成: \(String(format: "%.2f", potentialBonusReward)) \(billingCurrencyCode)")
        
        // 准备上限阈值（nil 或 0 表示无上限）
        let yearlyCapLimit = card.yearlyBaseCap ?? 0
        let categoryCapLimit = card.categoryCaps[category] ?? 0.0
        let hasYearlyCap = yearlyCapLimit > 0
        let hasCategoryCap = categoryCapLimit > 0
        
        logger.debug("  • 年度上限: \(hasYearlyCap ? String(format: "%.2f", Double(yearlyCapLimit)) : "无上限")")
        logger.debug("  • 类别上限: \(hasCategoryCap ? String(format: "%.2f", categoryCapLimit) : "无上限")")
        
        // 统计历史用量
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: date)
        let yearlyTransactions = (card.transactions ?? []).filter {
            let isSameYear = calendar.component(.year, from: $0.date) == currentYear
            let isNotSelf = ($0 != transactionToExclude)
            return isSameYear && isNotSelf
        }
        
        logger.debug("  • 本年度交易数: \(yearlyTransactions.count)")
        
        // 应用年度上限到基础返现
        var actualBaseReward: Double
        if hasYearlyCap {
            // 有年度上限：计算已用和剩余额度
            let usedYearlyReward = yearlyTransactions.reduce(0) { $0 + $1.cashbackamount }
            let remainingYearlyCap = max(0, Double(yearlyCapLimit) - usedYearlyReward)
            
            logger.debug("  • 已用年度返现: \(String(format: "%.2f", usedYearlyReward)) \(billingCurrencyCode)")
            logger.debug("  • 剩余年度额度: \(String(format: "%.2f", remainingYearlyCap)) \(billingCurrencyCode)")
            
            actualBaseReward = min(potentialBaseReward, remainingYearlyCap)
            logger.debug("  • 实际基础返现(受年度上限限制): \(String(format: "%.2f", actualBaseReward)) \(billingCurrencyCode)")
        } else {
            // 无年度上限：直接使用潜在返现
            actualBaseReward = potentialBaseReward
            logger.debug("  • 实际基础返现(无上限): \(String(format: "%.2f", actualBaseReward)) \(billingCurrencyCode)")
        }
        
        var actualBonusReward = potentialBonusReward
        // 如果有类别上限，应用它
        if hasCategoryCap {
            let usedCategoryCap = yearlyTransactions
                .filter { $0.category == category }
                .reduce(0) { sum, transaction in
                    let bRate = (transaction.card?.specialRates[transaction.category] ?? 0.0)
                    return sum + bRate * transaction.billingAmount
                }
            let remainingCategoryCap = max(0, categoryCapLimit - usedCategoryCap)
            actualBonusReward = min(actualBonusReward, remainingCategoryCap)
            
            logger.debug("  • 已用类别加成: \(String(format: "%.2f", usedCategoryCap)) \(billingCurrencyCode)")
            logger.debug("  • 剩余类别额度: \(String(format: "%.2f", remainingCategoryCap)) \(billingCurrencyCode)")
            logger.debug("  • 实际类别加成(受上限限制): \(String(format: "%.2f", actualBonusReward)) \(billingCurrencyCode)")
        } else {
            logger.debug("  • 类别加成: \(String(format: "%.2f", actualBonusReward)) \(billingCurrencyCode) (无上限)")
        }
        
        let finalCashback = actualBaseReward + actualBonusReward
        
        logger.debug("\n  ✅ 最终返现计算:")
        logger.debug("    基础返现: \(String(format: "%.2f", actualBaseReward)) \(billingCurrencyCode)")
        logger.debug("    类别加成: \(String(format: "%.2f", actualBonusReward)) \(billingCurrencyCode)")
        logger.debug("    总返现: \(String(format: "%.2f", finalCashback)) \(billingCurrencyCode)")
        
        if finalCashback < theoreticalCashback - 0.01 {
            let capDifference = theoreticalCashback - finalCashback
            logger.debug("    ⚠️ 受上限影响，减少: \(String(format: "%.2f", capDifference)) \(billingCurrencyCode)")
            steps.append(String(format: AppConstants.CashbackDetail.cappedFinalCashback, "\(String(format: "%.2f", finalCashback)) \(billingCurrencyCode)"))
        } else {
            steps.append(String(format: AppConstants.CashbackDetail.finalCashback, "\(String(format: "%.2f", finalCashback)) \(billingCurrencyCode)"))
        }
        
        // 6. 处理 CBF
        logger.debug("\n------------------------------------------------------------")
        logger.debug("📊 步骤 6: 处理 CBF 费用")
        logger.debug("------------------------------------------------------------")
        
        var cbfAmount: Double = 0.0
        var totalCost = finalBillingAmount
        
        if isCBFApplied {
            cbfAmount = finalBillingAmount * card.cbf
            totalCost = finalBillingAmount + cbfAmount
            let cbfPercent = card.cbf * 100
            
            logger.debug("  ✅ 适用 CBF")
            logger.debug("  • CBF 费率: \(String(format: "%.2f", cbfPercent))%")
            logger.debug("  • 入账金额: \(String(format: "%.2f", finalBillingAmount)) \(billingCurrencyCode)")
            logger.debug("  • CBF 金额: \(String(format: "%.2f", finalBillingAmount)) × \(String(format: "%.2f", cbfPercent))% = \(String(format: "%.2f", cbfAmount)) \(billingCurrencyCode)")
            logger.debug("  • 总成本: \(String(format: "%.2f", finalBillingAmount)) + \(String(format: "%.2f", cbfAmount)) = \(String(format: "%.2f", totalCost)) \(billingCurrencyCode)")
            logger.debug("  ⚠️ 注意: CBF 不参与返现计算")
            
            steps.append("")
            steps.append(AppConstants.CashbackDetail.cbfFeeTitle)
            steps.append(String(format: AppConstants.CashbackDetail.cbfRate, String(format: "%.2f", cbfPercent)))
            steps.append(String(format: AppConstants.CashbackDetail.cbfAmount, String(format: "%.2f", finalBillingAmount), String(format: "%.2f", cbfPercent), "\(String(format: "%.2f", cbfAmount)) \(billingCurrencyCode)"))
            steps.append(AppConstants.CashbackDetail.cbfNote)
            steps.append(String(format: AppConstants.CashbackDetail.totalCost, String(format: "%.2f", finalBillingAmount), String(format: "%.2f", cbfAmount), "\(String(format: "%.2f", totalCost)) \(billingCurrencyCode)"))
        } else {
            logger.debug("  ⊘ 不适用 CBF")
            logger.debug("  • 总成本: \(String(format: "%.2f", totalCost)) \(billingCurrencyCode)")
        }
        
        result.steps = steps
        result.finalCashback = finalCashback
        result.cbfAmount = cbfAmount
        result.totalCost = totalCost
        
        // 🖨️ 控制台日志：计算结束
        logger.debug("\n============================================================")
        logger.debug("✅ 返现计算结束")
        logger.debug("============================================================")
        logger.debug("📈 最终结果:")
        logger.debug("  • 入账金额: \(String(format: "%.2f", finalBillingAmount)) \(billingCurrencyCode)")
        logger.debug("  • 返现金额: \(String(format: "%.2f", finalCashback)) \(billingCurrencyCode)")
        logger.debug("  • 有效返现率: \(String(format: "%.4f", finalBillingAmount > 0 ? finalCashback / finalBillingAmount : 0)) (\(String(format: "%.2f", finalBillingAmount > 0 ? (finalCashback / finalBillingAmount * 100) : 0))%)")
        if isCBFApplied {
            logger.debug("  • CBF 费用: \(String(format: "%.2f", cbfAmount)) \(billingCurrencyCode)")
            logger.debug("  • 总成本: \(String(format: "%.2f", totalCost)) \(billingCurrencyCode)")
            let netBenefit = finalCashback - cbfAmount
            logger.debug("  • 净收益: \(String(format: "%.2f", netBenefit)) \(billingCurrencyCode)")
        }
        logger.debug("============================================================\n")
        
        return result
    }
    
    // MARK: - Helpers
    
    static func calculateBillingAmount(card: CreditCard, spendingAmount: Double, spendingCurrencyCode: String) async -> Double {
//        let isPulseCard = card.bankName.lowercased().contains("pulse")
        let issueRegion = card.issueRegion
        
//        if isPulseCard {
//            if spendingCurrencyCode == AppConstants.Currency.cny { return spendingAmount }
//            else {
        let shouldChargeFTF = !card.ftfExceptCurrencyCodes.contains(spendingCurrencyCode)
        logger.debug("FTF生效中？ \(shouldChargeFTF)")
        let ftfMultiplier = shouldChargeFTF ? (1.0 + card.ftf) : 1.0
        let rates = await CurrencyService.getRates(base: spendingCurrencyCode)
        let exchangeRate = rates[issueRegion.currencyCode] ?? 1.0
        let result = spendingAmount * exchangeRate * ftfMultiplier
        logger.debug("结果=消费金额\(spendingAmount) * 汇率\(exchangeRate) * FTF倍数\(ftfMultiplier) = \(result)")
        return result
//            }
//        } else {
//            let targetCurrency = card.issueRegion.currencyCode
//            if spendingCurrencyCode == targetCurrency { return spendingAmount }
//            let shouldChargeFTF = !card.ftfExceptCurrencyCodes.contains(spendingCurrencyCode)
//            logger.debug("FTF生效中？ \(shouldChargeFTF)")
//            let ftfMultiplier = shouldChargeFTF ? (1.0 + card.ftf) : 1.0
//            let rates = await CurrencyService.getRates(base: spendingCurrencyCode)
//            let exchangeRate = rates[targetCurrency] ?? 1.0
//            let result = spendingAmount * exchangeRate * ftfMultiplier
//            logger.debug("结果=消费金额\(spendingAmount) * 汇率\(exchangeRate) * FTF倍数\(ftfMultiplier) = \(result)")
//            return result
//        }
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
    
    static func doesRuleMatch(card: CreditCard, at index: Int, spendingCurrencyCode: String, paymentMethod: String, isOnlineShopping: Bool) -> Bool {
        guard let data = card.baseCashbackConditionsData,
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              index < jsonArray.count else {
            logger.debug("规则匹配失败: 数据解析错误或索引越界")
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
                else if currencyArray.contains(spendingCurrencyCode) { currencyMatches = true }
                else if (currencyArray.contains(AppConstants.Currency.otherCurrency) || currencyArray.contains(Currency.other.rawValue)) && !commonCurrencies.contains(spendingCurrencyCode) { currencyMatches = true }
            } else if let currencyDict = currenciesData as? [String: Any] {
                let currencyValues = currencyDict.values.compactMap { $0 as? String }
                if currencyValues.contains(AppConstants.Currency.all) || currencyValues.contains(Currency.all.rawValue) { currencyMatches = true }
                else if currencyValues.contains(spendingCurrencyCode) { currencyMatches = true }
                else if (currencyValues.contains(AppConstants.Currency.otherCurrency) || currencyValues.contains(Currency.other.rawValue)) && !commonCurrencies.contains(spendingCurrencyCode) { currencyMatches = true }
            }
            if !currencyMatches {
                logger.debug("规则 #\(index + 1) 币种不匹配: 交易币种=\(spendingCurrencyCode), 规则要求=\(String(describing: currenciesData))")
                return false
            }
        }
        
        // 2. 检查支付方式
        if let paymentMethods = rule["paymentMethods"] as? [String] {
            let paymentMatches = paymentMethods.contains(paymentMethod) || paymentMethods.contains(AppConstants.Transaction.otherPaymentMethod)
            if !paymentMatches {
                logger.debug("规则 #\(index + 1) 支付方式不匹配: 交易方式=\(paymentMethod), 规则要求=\(paymentMethods)")
                return false
            }
        }
        
        // 3. 检查交易类型
        if let transactionType = rule["transactionType"] as? String {
            switch transactionType {
            case AppConstants.Transaction.onlineShopping:
                if !isOnlineShopping {
                    logger.debug("规则 #\(index + 1) 交易类型不匹配: 需要线上交易")
                    return false
                }
            case AppConstants.Transaction.offlineShopping:
                if isOnlineShopping {
                    logger.debug("规则 #\(index + 1) 交易类型不匹配: 需要线下交易")
                    return false
                }
            default: break
            }
        }
        
        logger.debug("规则 #\(index + 1) 完全匹配")
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
