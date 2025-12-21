//
//  AddTransactionView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddTransactionView: View {
    // 1. 数据库与环境
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    @Query var cards: [CreditCard]
    
    // 2. 回调与编辑对象
    var onSaved: (() -> Void)? = nil
    var transactionToEdit: Transaction?
    
    // --- 表单的状态变量 ---
    @State private var merchant: String
    @State private var amount: String
    @State private var selectedCategory: Category
    @State private var date: Date
    @State private var selectedCardIndex: Int
    @State private var location: Region
    @State private var spendingCurrency: Region // 消费币种（独立于地区）
    @State private var billingAmountStr: String
    @State private var receiptImage: UIImage?
    
    // --- 新增：交易补充字段 ---
    @State private var paymentMethod: String
    @State private var isOnlineShopping: Bool
    @State private var isCBFApplied: Bool
    
    // --- 返现规则选择 ---
    @State private var selectedCashbackRuleIndex: Int?
    @State private var cashbackCalculationDetails: CashbackService.CashbackCalculationResult?
    
    // --- AI 分析与图片选择 ---
    @State private var isAnalyzing: Bool
    @EnvironmentObject private var aiAvailability: AppleIntelligenceAvailability
    @State private var showFullImage: Bool
    @State private var selectedPhotoItem: PhotosPickerItem? // 🆕 使用 PhotosPicker
    @State private var billingAmountFromReceipt: Bool
    
    // --- 焦点管理 ---
    @FocusState private var focusedField: Field?
    
    enum Field {
        case merchant, amount, billingAmount
    }
    
    // --- 3. 自定义初始化 ---
    init(transaction: Transaction? = nil, image: UIImage? = nil, onSaved: (() -> Void)? = nil) {
        self.transactionToEdit = transaction
        self.onSaved = onSaved
        
        if let t = transaction {
            // 编辑模式
            _merchant = State(initialValue: t.merchant)
            _amount = State(initialValue: String(t.amount))
            _billingAmountStr = State(initialValue: String(t.billingAmount))
            _selectedCategory = State(initialValue: t.category)
            _date = State(initialValue: t.date)
            _location = State(initialValue: t.location)
            _spendingCurrency = State(initialValue: t.location)
            _selectedCardIndex = State(initialValue: 0)
            
            _paymentMethod = State(initialValue: t.paymentMethod)
            _isOnlineShopping = State(initialValue: t.isOnlineShopping)
            _isCBFApplied = State(initialValue: t.isCBFApplied)
            
            _selectedCashbackRuleIndex = State(initialValue: nil)
            _cashbackCalculationDetails = State(initialValue: nil)
            _isAnalyzing = State(initialValue: false)
            _showFullImage = State(initialValue: false)
            _billingAmountFromReceipt = State(initialValue: false)
            
            if let data = t.receiptData {
                _receiptImage = State(initialValue: UIImage(data: data))
            } else {
                _receiptImage = State(initialValue: nil)
            }
        } else {
            // 新建模式
            _merchant = State(initialValue: "")
            _amount = State(initialValue: "")
            _billingAmountStr = State(initialValue: "")
            _selectedCategory = State(initialValue: .dining)
            _date = State(initialValue: Date())
            _location = State(initialValue: .cn)
            _spendingCurrency = State(initialValue: .cn)
            _selectedCardIndex = State(initialValue: 0)
            
            _paymentMethod = State(initialValue: "")
            _isOnlineShopping = State(initialValue: false)
            _isCBFApplied = State(initialValue: false)
            
            _selectedCashbackRuleIndex = State(initialValue: nil)
            _cashbackCalculationDetails = State(initialValue: nil)
            _isAnalyzing = State(initialValue: false)
            _showFullImage = State(initialValue: false)
            _billingAmountFromReceipt = State(initialValue: false)
            
            _receiptImage = State(initialValue: image)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. 消费详情
                ConsumptionDetailsSection(
                    merchant: $merchant,
                    amount: $amount,
                    selectedCategory: $selectedCategory,
                    location: $location,
                    spendingCurrency: $spendingCurrency,
                    focusedField: $focusedField
                )
                
                // 2. 交易属性
                TransactionAttributesSection(
                    paymentMethod: $paymentMethod,
                    isOnlineShopping: $isOnlineShopping,
                    isCBFApplied: $isCBFApplied,
                    aiSupported: aiAvailability.isSupported
                )
                
                // 3. 收据凭证
                ReceiptSection(
                    receiptImage: $receiptImage,
                    selectedPhotoItem: $selectedPhotoItem,
                    isAnalyzing: isAnalyzing,
                    showFullImage: $showFullImage,
                    onClearData: clearAIRecognizedData
                )
                
                // 4. 支付方式与入账
                PaymentCardSection(
                    cards: cards,
                    selectedCardIndex: $selectedCardIndex,
                    billingAmountStr: $billingAmountStr,
                    date: $date,
                    spendingCurrency: spendingCurrency,
                    billingAmountFromReceipt: $billingAmountFromReceipt,
                    focusedField: $focusedField
                )
                
                // 5. 返现规则与计算
                if cards.indices.contains(selectedCardIndex) {
                    CashbackSection(
                        card: cards[selectedCardIndex],
                        amount: amount,
                        billingAmountStr: billingAmountStr,
                        spendingCurrency: spendingCurrency,
                        paymentMethod: paymentMethod,
                        isOnlineShopping: isOnlineShopping,
                        isCBFApplied: isCBFApplied,
                        category: selectedCategory,
                        location: location,
                        date: date,
                        transactionToEdit: transactionToEdit,
                        selectedRuleIndex: $selectedCashbackRuleIndex,
                        calculationDetails: $cashbackCalculationDetails
                    )
                }
            }
            .navigationTitle(transactionToEdit == nil ? AppConstants.Transaction.addTransactionTitle : AppConstants.Transaction.editTransactionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppConstants.General.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppConstants.General.save) { saveTransaction() }
                        .disabled(merchant.isEmpty || amount.isEmpty || cards.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(AppConstants.General.done) { focusedField = nil }
                }
            }
            .onAppear(perform: handleOnAppear)
            .onChange(of: selectedPhotoItem) { loadPhoto() }
            .onChange(of: receiptImage) { handleReceiptImageChange() }
            .onChange(of: amount) { updateBillingAmount() }
            .onChange(of: spendingCurrency) { updateBillingAmount() }
            .onChange(of: selectedCardIndex) {
                updateBillingAmount()
                selectedCashbackRuleIndex = nil
            }
            .onChange(of: paymentMethod) { _, newValue in
                if newValue == AppConstants.Transaction.onlineShoppingLabel { isOnlineShopping = true }
            }
            .sheet(isPresented: $showFullImage) {
                if let image = receiptImage {
                    NavigationStack {
                        VStack {
                            Image(uiImage: image)
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
    
    // MARK: - Logic Methods
    
    private func handleOnAppear() {
        if let t = transactionToEdit, let card = t.card,
           let index = cards.firstIndex(of: card) {
            selectedCardIndex = index
        } else if transactionToEdit == nil && receiptImage != nil && merchant.isEmpty && amount.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                analyzeReceipt()
            }
        }
    }
    
    private func loadPhoto() {
        guard let item = selectedPhotoItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    self.receiptImage = image
                    // 清除旧的 AI 数据 (如果是重新上传)
                    if transactionToEdit == nil {
                         // onChange of receiptImage will trigger analysis
                    }
                }
            }
        }
    }
    
    private func handleReceiptImageChange() {
        if receiptImage != nil && transactionToEdit == nil {
            print(AppConstants.Transaction.aiNewPhotoDetected)
            analyzeReceipt()
        }
    }
    
    private func analyzeReceipt() {
        guard let image = receiptImage, aiAvailability.isSupported else { return }
        print(AppConstants.Transaction.aiAnalyzingReceipt)
        isAnalyzing = true
        
        Task {
            let metadata = await OCRService.analyzeImage(image)
            await MainActor.run {
                isAnalyzing = false
                guard let data = metadata else { return }
                
                if let amt = data.totalAmount {
                    self.amount = String(format: "%.2f", abs(amt))
                }
                
                if let billingAmt = data.billingAmount {
                    self.billingAmountStr = String(format: "%.2f", abs(billingAmt))
                    self.billingAmountFromReceipt = true
                } else {
                    self.billingAmountFromReceipt = false
                }
                
                if let merch = data.merchant { self.merchant = merch }
                if let dateStr = data.dateString { self.date = dateStr.toDate() }
                
                if let last4 = data.cardLast4 {
                    if let index = cards.firstIndex(where: { $0.endNum == last4 }) {
                        self.selectedCardIndex = index
                    }
                }
                
                if let cat = data.category { self.selectedCategory = cat }
                if let method = data.paymentMethod { self.paymentMethod = method }
                
                if let currency = data.currency,
                   let matchedRegion = Region.allCases.first(where: { $0.currencyCode == currency }) {
                    self.spendingCurrency = matchedRegion
                }
            }
        }
    }
    
    private func clearAIRecognizedData() {
        merchant = ""
        amount = ""
        billingAmountStr = ""
        selectedCategory = .dining
        date = Date()
        paymentMethod = ""
        isOnlineShopping = false
        isCBFApplied = false
        spendingCurrency = .cn
        billingAmountFromReceipt = false
        selectedCashbackRuleIndex = nil
        cashbackCalculationDetails = nil
    }
    
    private func updateBillingAmount() {
        if billingAmountFromReceipt { return }
        guard let amountDouble = Double(amount) else { return }
        guard cards.indices.contains(selectedCardIndex) else {
            billingAmountStr = amount
            return
        }
        
        let card = cards[selectedCardIndex]
        let sourceCurrency = spendingCurrency.currencyCode
        
        Task {
                let billing = await CashbackService.calculateBillingAmount(card: card, amount: amountDouble, sourceCurrency: sourceCurrency)
                await MainActor.run {
                    self.billingAmountStr = String(format: "%.2f", billing)
                }
            }
    }
    
    private func saveTransaction() {
        guard let amountDouble = Double(amount) else { return }
        let billingDouble = Double(billingAmountStr) ?? amountDouble
        
        if cards.indices.contains(selectedCardIndex) {
            let card = cards[selectedCardIndex]
            let imageData = receiptImage?.jpegData(compressionQuality: 0.5)
            
            let isNonCashbackTransaction = [AppConstants.Transaction.refund, AppConstants.Transaction.repayment, AppConstants.OCR.instalment].contains(paymentMethod)
            var finalCashback: Double
            var nominalRate: Double
            
            if isNonCashbackTransaction {
                finalCashback = 0.0
                nominalRate = 0.0
            } else if let details = cashbackCalculationDetails {
                finalCashback = details.finalCashback
                nominalRate = details.rate
            } else {
                finalCashback = CashbackService.calculateCappedCashback(
                    card: card,
                    amount: billingDouble,
                    category: selectedCategory,
                    location: location,
                    date: date,
                    transactionToExclude: transactionToEdit
                )
                nominalRate = card.getRate(for: selectedCategory, location: location)
            }
            
            if let t = transactionToEdit {
                t.merchant = merchant
                t.amount = amountDouble
                t.location = location
                t.date = date
                t.paymentMethod = paymentMethod
                t.isOnlineShopping = isOnlineShopping
                t.isCBFApplied = isCBFApplied
                
                if t.card != card || t.billingAmount != billingDouble || t.category != selectedCategory || t.date != date {
                    t.card = card
                    t.billingAmount = billingDouble
                    t.category = selectedCategory
                    t.rate = nominalRate
                    t.cashbackamount = finalCashback
                    t.cbfAmount = cashbackCalculationDetails?.cbfAmount ?? 0.0
                }
                
                if let img = imageData { t.receiptData = img }
            } else {
                let newTransaction = Transaction(
                    merchant: merchant,
                    category: selectedCategory,
                    location: location,
                    amount: amountDouble,
                    date: date,
                    card: card,
                    paymentMethod: paymentMethod,
                    isOnlineShopping: isOnlineShopping,
                    isCBFApplied: isCBFApplied,
                    receiptData: imageData,
                    billingAmount: billingDouble,
                    cashbackAmount: finalCashback,
                    cbfAmount: cashbackCalculationDetails?.cbfAmount ?? 0.0
                )
                context.insert(newTransaction)
            }
            dismiss()
            onSaved?()
        }
    }
}

// MARK: - Subviews

private struct ConsumptionDetailsSection: View {
    @Binding var merchant: String
    @Binding var amount: String
    @Binding var selectedCategory: Category
    @Binding var location: Region
    @Binding var spendingCurrency: Region
    var focusedField: FocusState<AddTransactionView.Field?>.Binding
    
    var body: some View {
        Section(header: Text(AppConstants.Transaction.consumptionDetails)) {
            TextField(AppConstants.Transaction.merchantNamePlaceholder, text: $merchant)
                .focused(focusedField, equals: .merchant)
                .submitLabel(.next)
            
            Picker(AppConstants.Transaction.consumptionCurrency, selection: $spendingCurrency) {
                ForEach(Region.allCases, id: \.self) { r in
                    Text("\(r.icon) \(r.currencyCode)").tag(r)
                }
            }
            
            HStack {
                Text(spendingCurrency.currencySymbol)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                TextField(AppConstants.Transaction.consumptionAmount, text: $amount)
                    .keyboardType(.decimalPad)
                    .focused(focusedField, equals: .amount)
            }
            
            Picker(AppConstants.Transaction.consumptionCategory, selection: $selectedCategory) {
                ForEach(Category.allCases, id: \.self) { c in
                    HStack {
                        Image(systemName: c.iconName).foregroundColor(c.color)
                        Text(c.displayName)
                    }
                    .tag(c)
                }
            }
            
            Picker(AppConstants.Transaction.consumptionRegion, selection: $location) {
                ForEach(Region.allCases, id: \.self) { r in
                    Text("\(r.icon) \(r.rawValue)").tag(r)
                }
            }
            
            if spendingCurrency != location {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(String(format: AppConstants.Transaction.currencyMismatch, spendingCurrency.currencyCode, location.rawValue))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct TransactionAttributesSection: View {
    @Binding var paymentMethod: String
    @Binding var isOnlineShopping: Bool
    @Binding var isCBFApplied: Bool
    var aiSupported: Bool
    
    private static let candidates = [
        AppConstants.OCR.sale,
        AppConstants.Transaction.applePay,
        AppConstants.Transaction.unionPayQR,
        AppConstants.Transaction.offlineShopping,
        AppConstants.Transaction.refund,
        AppConstants.Transaction.repayment,
        AppConstants.OCR.instalment,
        AppConstants.General.other
    ]
    
    var body: some View {
        Section(header: Text(AppConstants.Transaction.transactionAttributes)) {
            Picker(AppConstants.Transaction.paymentMethodLabel, selection: $paymentMethod) {
                Text(AppConstants.General.notSelected).tag("")
                ForEach(Self.candidates, id: \.self) { method in
                    Text(method).tag(method)
                }
            }
            
            Toggle(AppConstants.Transaction.onlineShoppingLabel, isOn: $isOnlineShopping)
            Toggle(AppConstants.Transaction.isCBFAppliedQuestion, isOn: $isCBFApplied)
        }
        .textCase(nil)
        
        if !aiSupported {
            Section {
                Label(AppConstants.AI.compatibilityMessage, systemImage: "info.circle")
            }
        }
    }
}

private struct ReceiptSection: View {
    @Binding var receiptImage: UIImage?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    var isAnalyzing: Bool
    @Binding var showFullImage: Bool
    var onClearData: () -> Void
    
    var body: some View {
        Section(header: Text(AppConstants.Transaction.receiptEvidence)) {
            if let image = receiptImage {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(10)
                        .opacity(isAnalyzing ? 0.5 : 1.0)
                        .onTapGesture { showFullImage = true }
                    
                    if isAnalyzing {
                        ProgressView(AppConstants.Transaction.aiAnalyzing)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                
                Button(role: .destructive) {
                    receiptImage = nil
                    selectedPhotoItem = nil
                    onClearData()
                } label: {
                    Label(AppConstants.Transaction.deleteImage, systemImage: "trash")
                }
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(AppConstants.Transaction.reupload, systemImage: "arrow.triangle.2.circlepath")
                }
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(AppConstants.Transaction.uploadReceiptImage, systemImage: "photo.on.rectangle")
                }
            }
        }
    }
}

private struct PaymentCardSection: View {
    var cards: [CreditCard]
    @Binding var selectedCardIndex: Int
    @Binding var billingAmountStr: String
    @Binding var date: Date
    var spendingCurrency: Region
    @Binding var billingAmountFromReceipt: Bool
    var focusedField: FocusState<AddTransactionView.Field?>.Binding
    
    var body: some View {
        Section(header: Text(AppConstants.Transaction.paymentMethodLabel)) {
            if cards.isEmpty {
                Text(AppConstants.Transaction.pleaseAddCreditCard).foregroundColor(.secondary)
            } else {
                Picker(AppConstants.Transaction.selectCreditCard, selection: $selectedCardIndex) {
                    ForEach(0..<cards.count, id: \.self) { index in
                        Text(cards[index].bankName).tag(index)
                    }
                }
            }
            
            if cards.indices.contains(selectedCardIndex) {
                let card = cards[selectedCardIndex]
                let actualCurrency = getActualBillingCurrency(for: card)
                
                if spendingCurrency.currencySymbol != actualCurrency {
                    HStack {
                        Text(String(format: AppConstants.Transaction.billingAmountWithCurrency, actualCurrency))
                            .font(.caption).foregroundColor(.red)
                        Spacer()
                        TextField(AppConstants.Transaction.actualDeduction, text: $billingAmountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused(focusedField, equals: .billingAmount)
                            .onChange(of: billingAmountStr) { oldValue, newValue in
                                if billingAmountFromReceipt && oldValue != newValue {
                                    billingAmountFromReceipt = false
                                }
                            }
                    }
                }
            }
            DatePicker(AppConstants.Transaction.consumptionDate, selection: $date, in: ...Date(), displayedComponents: .date)
        }
    }
    
    private func getActualBillingCurrency(for card: CreditCard) -> String {
        let isPulse = card.bankName.localizedCaseInsensitiveContains("Pulse")
        let sourceCurrency = spendingCurrency.currencyCode
        
        if isPulse && sourceCurrency == "CNY" {
            return spendingCurrency.currencySymbol
        } else if isPulse {
            return Region.hk.currencySymbol
        } else {
            return card.issueRegion.currencySymbol
        }
    }
}

private struct CashbackSection: View {
    let card: CreditCard
    let amount: String
    let billingAmountStr: String
    let spendingCurrency: Region
    let paymentMethod: String
    let isOnlineShopping: Bool
    let isCBFApplied: Bool
    let category: Category
    let location: Region
    let date: Date
    let transactionToEdit: Transaction?
    
    @Binding var selectedRuleIndex: Int?
    @Binding var calculationDetails: CashbackService.CashbackCalculationResult?
    
    var body: some View {
        let rules = CashbackService.getCashbackRuleSummaries(card: card)
        
        Section(header: Text(AppConstants.Transaction.cashbackRules)) {
            if rules.count > 1 {
                Picker(AppConstants.Transaction.selectCashbackRule, selection: Binding(
                    get: { selectedRuleIndex ?? -1 },
                    set: { selectedRuleIndex = $0 == -1 ? nil : $0 }
                )) {
                    Text(AppConstants.Transaction.autoMatch).tag(-1)
                    ForEach(rules) { rule in
                        Text(rule.displayName).tag(rule.id)
                    }
                }
                
                if selectedRuleIndex == nil,
                   let details = calculationDetails,
                   let step = details.steps.first(where: { $0.contains(AppConstants.Transaction.usingRule) }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(step)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if rules.count == 1 {
                Text(String(format: AppConstants.Transaction.rulePrefix, rules[0].displayName))
                    .foregroundColor(.secondary)
            }
        }
        
        Section(header: Text(AppConstants.Transaction.cashbackCalculation)) {
            if [AppConstants.Transaction.refund, AppConstants.Transaction.repayment, AppConstants.OCR.instalment].contains(paymentMethod) {
                NonCashbackInfoView()
            } else if let amountDouble = Double(amount), amountDouble > 0,
                      let billingDouble = Double(billingAmountStr), billingDouble > 0 {
                
                CashbackCalculationView(
                    card: card,
                    originalAmount: amountDouble,
                    billingAmount: billingDouble,
                    sourceCurrency: spendingCurrency.currencyCode,
                    paymentMethod: paymentMethod.isEmpty ? AppConstants.Transaction.unfillPaymentMethod : paymentMethod,
                    isOnlineShopping: isOnlineShopping,
                    isCBFApplied: isCBFApplied,
                    category: category,
                    location: location,
                    date: date,
                    selectedRuleIndex: selectedRuleIndex,
                    transactionToExclude: transactionToEdit,
                    onResult: { calculationDetails = $0 }
                )
                
                if let details = calculationDetails {
                    CalculationResultView(details: details)
                }
            } else {
                Text(AppConstants.Transaction.enterConsumptionAmount).foregroundColor(.secondary).font(.caption)
            }
        }
    }
}

private struct NonCashbackInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill").foregroundColor(.blue).font(.caption)
                Text(AppConstants.Transaction.noCashbackForThisTransaction).font(.caption).foregroundColor(.secondary)
            }
            HStack {
                Text(AppConstants.Transaction.finalCashback).fontWeight(.bold)
                Spacer()
                Text("¥0.00").fontWeight(.bold).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CalculationResultView: View {
    let details: CashbackService.CashbackCalculationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(details.steps.enumerated()), id: \.offset) { _, step in
                Text(step).font(.caption).foregroundColor(.secondary)
            }
            Divider()
            HStack {
                Text(AppConstants.Transaction.finalCashback).fontWeight(.bold)
                Spacer()
                Text("\(details.finalCashback >= 0 ? "+" : "")\(String(format: "%.2f", details.finalCashback))")
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            if details.cbfAmount > 0 {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(AppConstants.Transaction.cbfFeeNotCounted)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("-\(String(format: "%.2f", details.cbfAmount))")
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    HStack {
                        Text(AppConstants.Transaction.actualCost).font(.caption2).foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.2f", details.totalCost))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helper Views

/// 返现计算视图（异步计算）
struct CashbackCalculationView: View {
    let card: CreditCard
    let originalAmount: Double
    let billingAmount: Double
    let sourceCurrency: String
    let paymentMethod: String
    let isOnlineShopping: Bool
    let isCBFApplied: Bool
    let category: Category
    let location: Region
    let date: Date
    let selectedRuleIndex: Int?
    let transactionToExclude: Transaction?
    let onResult: (CashbackService.CashbackCalculationResult) -> Void
    
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                HStack {
                    ProgressView()
                    Text(AppConstants.Transaction.calculatingCashback).foregroundColor(.secondary)
                }
            } else {
                EmptyView()
            }
        }
        .task(id: combineHashValues) {
            await calculate()
        }
    }
    
    private var combineHashValues: Int {
        var hasher = Hasher()
        hasher.combine(card.id)
        hasher.combine(originalAmount)
        hasher.combine(billingAmount)
        hasher.combine(selectedRuleIndex)
        hasher.combine(paymentMethod)
        hasher.combine(isOnlineShopping)
        hasher.combine(isCBFApplied)
        hasher.combine(category)
        return hasher.finalize()
    }
    
    private func calculate() async {
        isLoading = true
        let calculationResult = await CashbackService.calculateCashbackWithDetails(
            card: card,
            originalAmount: originalAmount,
            sourceCurrency: sourceCurrency,
            paymentMethod: paymentMethod,
            isOnlineShopping: isOnlineShopping,
            isCBFApplied: isCBFApplied,
            category: category,
            location: location,
            date: date,
            selectedConditionIndex: selectedRuleIndex,
            transactionToExclude: transactionToExclude,
            providedBillingAmount: billingAmount
        )
        await MainActor.run {
            onResult(calculationResult)
            isLoading = false
        }
    }
}


