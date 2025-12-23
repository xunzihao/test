//
//  AddCashbackView.swift
//  CashbackCounter
//
//  Created by Assistant on 12/23/25.
//

import SwiftUI
import SwiftData

struct AddCashbackView: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    @Query var cards: [CreditCard]
    
    @State private var amount: String = ""
    @State private var selectedCard: CreditCard?
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var isRewardCashAccount: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("返现详情")) {
                    HStack {
                        Text("金额")
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }
                
                Section(header: Text("归属账户")) {
                    Toggle("属于奖赏钱账户 (不关联特定卡片)", isOn: $isRewardCashAccount)
                        .onChange(of: isRewardCashAccount) { _, newValue in
                            if newValue {
                                selectedCard = nil
                            } else if selectedCard == nil && !cards.isEmpty {
                                selectedCard = cards.first
                            }
                        }
                    
                    if !isRewardCashAccount {
                        if cards.isEmpty {
                            Text("暂无信用卡，请先添加").foregroundStyle(.secondary)
                        } else {
                            Picker("选择卡片", selection: $selectedCard) {
                                Text("请选择").tag(nil as CreditCard?)
                                ForEach(cards) { card in
                                    Text("\(card.bankName) (\(card.endNum))").tag(card as CreditCard?)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("备注")) {
                    TextField("可选 (例如: 活动奖励)", text: $note)
                }
            }
            .navigationTitle("添加返现")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(amount.isEmpty || (!isRewardCashAccount && selectedCard == nil))
                }
            }
            .onAppear {
                if !cards.isEmpty {
                    selectedCard = cards.first
                } else {
                    isRewardCashAccount = true
                }
            }
        }
    }
    
    private func save() {
        guard let cashbackAmount = Double(amount) else { return }
        
        let merchantName = note.isEmpty ? "手动返现" : note
        
        let transaction = Transaction(
            merchant: merchantName,
            category: .other,
            location: .cn, // 默认为 CN，不影响返现统计
            spendingAmount: 0,
            date: date,
            card: isRewardCashAccount ? nil : selectedCard,
            paymentMethod: "手动返现",
            isOnlineShopping: false,
            isCBFApplied: false,
            isCreditTransaction: false,
            receiptData: nil,
            billingAmount: 0,
            cashbackAmount: cashbackAmount,
            cbfAmount: 0
        )
        
        context.insert(transaction)
        dismiss()
    }
}
