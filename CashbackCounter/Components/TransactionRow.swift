//
//  TransactionRow.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. 左侧类别图标
            iconView
            
            // 2. 中间信息 (商户名 + 卡片名)
            mainInfoView
            
            Spacer(minLength: 8)
            
            // 3. 右侧金额与详情
            amountInfoView
        }
        .padding(12)
        .background(rowBackground)
        .cornerRadius(12)
        // 降低退款/还款记录的视觉权重
        .opacity(transaction.isCreditTransaction ? 0.8 : 1.0)
        // 无障碍支持
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelString)
    }
}

// MARK: - Subviews

private extension TransactionRow {
    
    var iconView: some View {
        ZStack {
            Circle()
                .fill(transaction.category.color.opacity(0.2))
                .frame(width: 44, height: 44)
            
            Image(systemName: transaction.category.iconName)
                .font(.system(size: 20))
                .foregroundColor(transaction.category.color)
        }
        .accessibilityHidden(true) // 图标仅作装饰
    }
    
    var mainInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(transaction.merchant)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                // 🔥 CR 标记（还款/退款）
                if transaction.isCreditTransaction {
                    // 如果是“返现”类型，显示“返现CR”，且颜色不同
                    if transaction.paymentMethod == AppConstants.Transaction.cashbackRebate {
                        Text("返现CR")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.green) // 返现用绿色背景
                            .cornerRadius(3)
                    } else {
                        // 普通 CR (退款/还款)
                        Text(AppConstants.Transaction.creditTransactionLabel)
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange) // 普通CR用橙色
                            .cornerRadius(3)
                    }
                }
            }
            
            if let cardName = cardDisplayName {
                Text(cardName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true) // 允许垂直方向换行
                    .lineLimit(2)
            }
        }
    }
    
    var amountInfoView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // 消费金额（CR 交易显示橙色，返现显示绿色）
            Text(amountString)
                .fontWeight(.bold)
                .foregroundColor(amountColor)
                .monospacedDigit() // 数字等宽显示
            
            // 日期 + 返现信息
            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.dateString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 显示返现
                if shouldShowCashback {
                    Text(cashbackString)
                        .font(.caption2)
                        .foregroundColor(cashbackTextColor)
                        .monospacedDigit()
                }
            }
        }
    }
}

// MARK: - Helpers

private extension TransactionRow {
    
    var isRebate: Bool {
        transaction.paymentMethod == AppConstants.Transaction.cashbackRebate
    }
    
    var rowBackground: Color {
        if isRebate {
            return Color.green.opacity(0.05) // 返现交易用淡绿色背景
        } else if transaction.isCreditTransaction {
            return Color.orange.opacity(0.05) // 其他 CR 交易用淡橙色
        } else {
            return Color(uiColor: .secondarySystemGroupedBackground)
        }
    }
    
    var amountColor: Color {
        if isRebate { return .green }
        if transaction.isCreditTransaction { return .orange }
        return .primary
    }
    
    var cashbackTextColor: Color {
        if isRebate { return .green }
        if transaction.isCreditTransaction { return .orange }
        return .green
    }
    
    var cardDisplayName: String? {
        guard let card = transaction.card else { return nil }
        // 简化卡片显示：只显示银行名称，不显示类型 (例如: "汇丰香港" 而不是 "汇丰香港 Premier Mastercard World")
        return card.bankName
    }
    
    var amountString: String {
        "\(transaction.location.currencySymbol)\(Formatters.currency(transaction.spendingAmount))"
    }
    
    var shouldShowCashback: Bool {
        // 如果是“返现”交易，不显示底部的返现金额行（因为主金额就是返现）
        if isRebate { return false }
        
        return transaction.isCreditTransaction || transaction.cashbackamount > 0
    }
    
    var cashbackString: String {
        let amount = transaction.isCreditTransaction ? 0 : transaction.cashbackamount
        return "\(AppConstants.Transaction.cashbackPrefix) \(transaction.location.currencySymbol)\(Formatters.currency(amount))"
    }
    
    // MARK: - Accessibility
    
    var accessibilityLabelString: String {
        let merchantPart = transaction.merchant
        let amountPart = amountString
        let datePart = transaction.dateString
        
        var label = "\(merchantPart), \(amountPart), \(datePart)"
        
        if let card = cardDisplayName {
            label += ", \(card)"
        }
        
        if transaction.isCreditTransaction {
            label += ", \(AppConstants.Accessibility.creditTransaction)"
        }
        
        if shouldShowCashback {
            label += ", \(AppConstants.Accessibility.cashback) \(cashbackString)"
        }
        
        return label
    }
}
