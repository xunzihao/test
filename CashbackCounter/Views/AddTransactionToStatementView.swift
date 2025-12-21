//
//  AddTransactionToStatementView.swift
//  CashbackCounter
//
//  Created by Assistant on 12/20/25.
//

import SwiftUI

/// 添加交易到结单分析结果（复用编辑界面的 UI）
struct AddTransactionToStatementView: View {
    // 回调
    let onAdd: (StatementAnalysisResult.ParsedTransaction) -> Void
    let onCancel: () -> Void
    
    // 表单状态
    @State private var merchantName: String = ""
    @State private var amount: Double = 0.0
    @State private var cbfFee: Double? = nil
    @State private var postDate: Date = Date()
    @State private var transDate: Date = Date()
    @State private var paymentMethod: String = AppConstants.OCR.sale
    @State private var showCBFInput: Bool = false
    
    // 焦点管理
    @FocusState private var focusedField: Field?
    
    enum Field {
        case merchant, amount, cbf
    }
    
    var body: some View {
        NavigationStack {
            Form {
                MerchantSection(name: $merchantName, focusedField: $focusedField)
                
                AmountSection(
                    amount: $amount,
                    cbfFee: $cbfFee,
                    showCBFInput: $showCBFInput,
                    focusedField: $focusedField
                )
                
                DateSection(postDate: $postDate, transDate: $transDate)
                
                PaymentMethodSection(paymentMethod: $paymentMethod)
                
                InfoSection()
            }
            .navigationTitle(AppConstants.Transaction.addTransactionAction)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppConstants.General.cancel, action: onCancel)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppConstants.Transaction.add, action: addTransaction)
                        .disabled(merchantName.isEmpty || amount <= 0)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(AppConstants.General.done) { focusedField = nil }
                }
            }
        }
    }
    
    /// 创建并添加交易
    private func addTransaction() {
        // 判断是否为不计返现的交易
        let isNonCashback = [
            AppConstants.Transaction.refund,
            AppConstants.Transaction.repayment,
            AppConstants.OCR.autoRepayment,
            AppConstants.OCR.instalment,
            AppConstants.Transaction.cbf
        ].contains(paymentMethod)
        
        let transaction = StatementAnalysisResult.ParsedTransaction(
            postDate: postDate,
            transDate: transDate,
            description: merchantName,
            amount: amount,
            currency: AppConstants.Currency.hkd,
            paymentMethod: paymentMethod,
            isForeignCurrency: false,
            foreignCurrency: nil,
            foreignAmount: nil,
            isRefundOrPayment: isNonCashback,
            cbfFee: cbfFee
        )
        
        onAdd(transaction)
    }
}

// MARK: - Subviews

private struct MerchantSection: View {
    @Binding var name: String
    var focusedField: FocusState<AddTransactionToStatementView.Field?>.Binding
    
    var body: some View {
        Section(AppConstants.StatementAnalysis.merchantInfoSection) {
            TextField(AppConstants.StatementAnalysis.merchantNameField, text: $name)
                .focused(focusedField, equals: .merchant)
                .submitLabel(.next)
        }
    }
}

private struct AmountSection: View {
    @Binding var amount: Double
    @Binding var cbfFee: Double?
    @Binding var showCBFInput: Bool
    var focusedField: FocusState<AddTransactionToStatementView.Field?>.Binding
    
    var body: some View {
        Section(AppConstants.StatementAnalysis.transactionAmountSection) {
            HStack {
                Text(AppConstants.StatementAnalysis.currencyHKD)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                TextField(AppConstants.StatementAnalysis.amountField, value: $amount, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused(focusedField, equals: .amount)
            }
            
            // CBF 费用
            if showCBFInput {
                HStack {
                    Text(AppConstants.StatementAnalysis.cbfFeeLabel)
                        .foregroundColor(.orange)
                    TextField(AppConstants.StatementAnalysis.cbfField, value: Binding(
                        get: { cbfFee ?? 0 },
                        set: { cbfFee = $0 > 0 ? $0 : nil }
                    ), format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused(focusedField, equals: .cbf)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                
                Button(role: .destructive) {
                    withAnimation {
                        cbfFee = nil
                        showCBFInput = false
                    }
                } label: {
                    Label(AppConstants.Transaction.removeCBFFee, systemImage: "minus.circle")
                }
            } else {
                Button {
                    withAnimation {
                        showCBFInput = true
                        cbfFee = 0.0
                    }
                } label: {
                    Label(AppConstants.StatementAnalysis.addCbfFeeAction, systemImage: "plus.circle")
                }
            }
        }
    }
}

private struct DateSection: View {
    @Binding var postDate: Date
    @Binding var transDate: Date
    
    var body: some View {
        Section(AppConstants.StatementAnalysis.transactionDateField) {
            DatePicker(AppConstants.StatementAnalysis.postingDateField, selection: $postDate, displayedComponents: .date)
            DatePicker(AppConstants.StatementAnalysis.transactionDateField, selection: $transDate, displayedComponents: .date)
        }
    }
}

private struct PaymentMethodSection: View {
    @Binding var paymentMethod: String
    
    private let methods = [
        AppConstants.OCR.sale,
        AppConstants.Transaction.applePay,
        AppConstants.Transaction.unionPayQR,
        AppConstants.Transaction.refund,
        AppConstants.Transaction.repayment,
        AppConstants.OCR.autoRepayment,
        AppConstants.OCR.instalment,
        AppConstants.Transaction.cbf
    ]
    
    var body: some View {
        Section(AppConstants.StatementAnalysis.paymentMethodField) {
            Picker(AppConstants.StatementAnalysis.paymentMethodField, selection: $paymentMethod) {
                ForEach(methods, id: \.self) { method in
                    Text(method).tag(method)
                }
            }
        }
    }
}

private struct InfoSection: View {
    var body: some View {
        Section {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text(AppConstants.Transaction.transactionParticipatesCashback)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    AddTransactionToStatementView(
        onAdd: { _ in },
        onCancel: { }
    )
}
