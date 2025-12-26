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
    
    // 编辑模式参数
    var transactionToEdit: StatementAnalysisResult.ParsedTransaction?
    
    // 表单状态
    @State private var merchantName: String = ""
    @State private var amount: Double = 0.0
    @State private var cbfFee: Double? = nil
    @State private var postDate: Date = Date()
    @State private var transDate: Date = Date()
    @State private var paymentMethod: String = AppConstants.OCR.sale
    @State private var showCBFInput: Bool = false
    @State private var currency: String = AppConstants.Currency.hkd
    
    // 焦点管理
    @FocusState private var focusedField: Field?
    
    enum Field {
        case merchant, amount, cbf
    }
    
    init(transactionToEdit: StatementAnalysisResult.ParsedTransaction? = nil, onAdd: @escaping (StatementAnalysisResult.ParsedTransaction) -> Void, onCancel: @escaping () -> Void) {
        self.transactionToEdit = transactionToEdit
        self.onAdd = onAdd
        self.onCancel = onCancel
        
        if let t = transactionToEdit {
            _merchantName = State(initialValue: t.description)
            _amount = State(initialValue: t.billingAmount)
            _cbfFee = State(initialValue: t.cbfFee)
            _postDate = State(initialValue: t.postDate ?? Date())
            _transDate = State(initialValue: t.transDate ?? Date())
            _paymentMethod = State(initialValue: t.paymentMethod ?? AppConstants.OCR.sale)
            _showCBFInput = State(initialValue: t.cbfFee != nil && t.cbfFee! > 0)
            _currency = State(initialValue: t.billingCurrency)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                MerchantSection(name: $merchantName, focusedField: $focusedField)
                
                AmountSection(
                    amount: $amount,
                    cbfFee: $cbfFee,
                    showCBFInput: $showCBFInput,
                    focusedField: $focusedField,
                    currency: $currency
                )
                
                DateSection(postDate: $postDate, transDate: $transDate)
                
                PaymentMethodSection(paymentMethod: $paymentMethod)
                
                InfoSection()
            }
            .navigationTitle(transactionToEdit == nil ? AppConstants.Transaction.addTransactionAction : AppConstants.Transaction.editTransaction)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppConstants.General.cancel, action: onCancel)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(transactionToEdit == nil ? AppConstants.Transaction.add : AppConstants.General.save, action: addTransaction)
                        .disabled(merchantName.isEmpty || amount == 0) // 允许负数，只要不是 0 即可
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
            billingAmount: amount,
            billingCurrency: currency,
            paymentMethod: paymentMethod,
            isForeignCurrency: false,
            spendingCurrency: nil,
            spendingAmount: nil,
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
    @Binding var currency: String
    
    var body: some View {
        Section(AppConstants.StatementAnalysis.transactionAmountSection) {
            HStack {
                Text(currency)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                TextField(AppConstants.StatementAnalysis.amountField, value: $amount, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.numbersAndPunctuation) // 允许输入负号
                    .multilineTextAlignment(.trailing)
                    .focused(focusedField, equals: .amount)
            }
            
            // CBF 费用
            // 使用 ZStack 确保布局稳定，不会因为 showCBFInput 切换而跳动
            // 或者始终渲染结构，只是用 opacity 或 hidden 控制
            
            Group {
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
    
    private var filterOptions: [String] {
        var options = [AppConstants.OCR.sale] // 默认 SALE 放第一位
        options.append(contentsOf: AppConstants.OCR.PaymentDetection.candidates)
        print("options👂",options)
        return options
    }
    
    var body: some View {
        Section(AppConstants.StatementAnalysis.paymentMethodField) {
            Picker(AppConstants.StatementAnalysis.paymentMethodField, selection: $paymentMethod) {
                ForEach(filterOptions, id: \.self) { method in
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
