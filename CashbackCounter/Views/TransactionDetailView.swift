//
//  TransactionDetailView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) var dismiss
    @State private var showFullImage = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // 1. 顶部大图标和商家
                    HeaderView(transaction: transaction)
                    
                    // 2. 金额显示
                    AmountDisplayView(transaction: transaction)
                    
                    // 3. 详细信息列表
            DetailListView(transaction: transaction)
            
            // 4. 返现高亮区域
            if transaction.cashbackamount > 0 {
                CashbackHighlightView(transaction: transaction)
            }
            
            // 5. 实际成本显示（如果有 CBF）
            if transaction.isCBFApplied && transaction.cbfAmount > 0 {
                TotalCostView(transaction: transaction)
            }
            
            // 6. 电子收据区域
            if let data = transaction.receiptData, let uiImage = UIImage(data: data) {
                ReceiptView(image: uiImage, showFullImage: $showFullImage)
            }
        }
        .padding(.vertical)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .confirmationAction) {
            Button(AppConstants.General.confirm) { dismiss() }
        }
    }
    // 全屏图片预览 Sheet
    .sheet(isPresented: $showFullImage) {
        if let data = transaction.receiptData, let uiImage = UIImage(data: data) {
            NavigationStack {
                VStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppConstants.General.close) { showFullImage = false }
                    }
                }
            }
        }
    }
        }
    }
}

// MARK: - Subviews

private struct HeaderView: View {
    let transaction: Transaction
    
    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(transaction.category.color.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: transaction.category.iconName)
                    .font(.system(size: 35))
                    .foregroundColor(transaction.category.color)
            }
            .accessibilityHidden(true)
            
            Text(transaction.merchant)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
}

private struct AmountDisplayView: View {
    let transaction: Transaction
    
    var body: some View {
        // 建议：直接从 Transaction 获取货币符号，或统一使用 Region 的符号
        let currency = transaction.location.currencySymbol
        let amountStr = String(format: "%.2f", transaction.amount)
        
        Text("- \(currency)\(amountStr)")
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .monospacedDigit()
            .accessibilityLabel("消费金额 \(currency) \(amountStr)")
            .contentTransition(.numericText())
    }
}

private struct DetailListView: View {
    let transaction: Transaction
    
    // 简化：直接访问属性，减少对外部 Service 的依赖
    var cardName: String { transaction.card?.bankName ?? AppConstants.Transaction.unknownBank }
    var cardNumber: String { transaction.card?.endNum ?? AppConstants.Transaction.unknownCard }
    var currency: String { transaction.location.currencySymbol }
    
    var body: some View {
        VStack(spacing: 0) {
            DetailRow(title: AppConstants.Transaction.transactionTime, value: transaction.date.formatted(date: .abbreviated, time: .shortened))
            Divider()
            DetailRow(title: AppConstants.Transaction.paymentCard, value: cardName)
            Divider()
            DetailRow(title: AppConstants.Transaction.cardTailNumber, value: cardNumber)
            Divider()
            DetailRow(title: AppConstants.Transaction.billingAmount, value: "\(currency)\(String(format: "%.2f", transaction.billingAmount))")
            Divider()
            DetailRow(title: AppConstants.Transaction.transactionRegion, value: "\(transaction.location.icon) \(transaction.location.rawValue)")
            Divider()
            DetailRow(title: AppConstants.Transaction.paymentMethodLabel, value: transaction.paymentMethod.isEmpty ? AppConstants.General.notSelected : transaction.paymentMethod)
            Divider()
            DetailRow(title: AppConstants.Transaction.onlineShoppingLabel, value: transaction.isOnlineShopping ? AppConstants.CSV.yes : AppConstants.CSV.no)
            Divider()
            DetailRow(title: AppConstants.Transaction.isAppliedCBF, value: transaction.isCBFApplied ? AppConstants.CSV.yes : AppConstants.CSV.no)
            
            if transaction.isCBFApplied && transaction.cbfAmount > 0 {
                Divider()
                DetailRowHighlight(
                    title: "CBF",
                    value: "-\(currency)\(String(format: "%.2f", transaction.cbfAmount))",
                    color: .orange
                )
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

private struct CashbackHighlightView: View {
    let transaction: Transaction
    
    var body: some View {
        let currency = transaction.location.currencySymbol
        let cashback = transaction.cashbackamount
        let rate = String(format: "%.1f", transaction.rate * 100)
        
        HStack {
            VStack(alignment: .leading) {
                Text(AppConstants.Transaction.currentCashback)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(currency)\(String(format: "%.2f", cashback)) (\(rate)%)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundColor(.green.opacity(0.3))
                .accessibilityHidden(true)
                .symbolEffect(.bounce, value: cashback) // iOS 17 动画
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

private struct TotalCostView: View {
    let transaction: Transaction
    
    var body: some View {
        let currency = transaction.location.currencySymbol
        let total = transaction.billingAmount + transaction.cbfAmount
        
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppConstants.Transaction.actualTotalCost)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Text(AppConstants.Transaction.billing)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(currency)\(String(format: "%.2f", transaction.billingAmount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("+")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("CBF")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(currency)\(String(format: "%.2f", transaction.cbfAmount))")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                Text("\(currency)\(String(format: "%.2f", total))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .monospacedDigit()
            }
            
            Text(AppConstants.Transaction.cbfExclusionNote)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

private struct ReceiptView: View {
    let image: UIImage
    @Binding var showFullImage: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            Divider()
            
            HStack {
                Text(AppConstants.Transaction.electronicReceipt)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .shadow(radius: 5)
                .onTapGesture {
                    showFullImage = true
                }
                .accessibilityLabel(AppConstants.Transaction.electronicReceiptPreview)
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
}

// MARK: - Helper Views

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title).foregroundColor(.gray)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

private struct DetailRowHighlight: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                Text(title)
            }
            .foregroundColor(color)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding()
        .background(color.opacity(0.1))
        .accessibilityElement(children: .combine)
    }
}
