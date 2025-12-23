//
//  AddTransactionView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData
import PhotosUI
import OSLog

// MARK: - Logger
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CashbackCounter", category: "AddTransactionView")

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
    @State private var selectedCategory: Category
    @State private var date: Date
    @State private var selectedCardIndex: Int
    @State private var location: Region
    @State private var spendingAmount: String //消费金额
    @State private var spendingCurrency: Region // 消费币种
    @State private var billingCurrency: Region? // 入账币种
    @State private var billingAmount: String //入账金额
    @State private var billingAmountFromReceipt: Bool //入账金额是否来源于小票识别
    @State private var receiptImage: UIImage?
    
    // --- 新增：交易补充字段 ---
    @State private var paymentMethod: String
    @State private var isOnlineShopping: Bool
    @State private var isCBFApplied: Bool
    @State private var showCBFInput: Bool // 🆕 控制 CBF 输入框显示
    @State private var cbfAmount: Double? // 🆕 存储手动输入的 CBF 金额
    
    // --- 返现规则选择 ---
    @State private var selectedCashbackRuleIndex: Int?
    @State private var cashbackCalculationDetails: CashbackService.CashbackCalculationResult?
    
    // --- AI 分析与图片选择 ---
    @State private var isAnalyzing: Bool
    @EnvironmentObject private var aiAvailability: AppleIntelligenceAvailability
    @State private var showFullImage: Bool
    @State private var selectedPhotoItem: PhotosPickerItem? // 🆕 使用 PhotosPicker
    
    
    // --- 焦点管理 ---
    @FocusState private var focusedField: Field?
    
    enum Field {
        case merchant, spendingAmount, billingAmount
    }
    
    // --- 3. 自定义初始化 ---
    init(transaction: Transaction? = nil, image: UIImage? = nil, onSaved: (() -> Void)? = nil) {
        self.transactionToEdit = transaction
        self.onSaved = onSaved
        
        if let t = transaction {
            // 编辑模式
            _merchant = State(initialValue: t.merchant)
            _spendingAmount = State(initialValue: String(t.spendingAmount))
            _billingAmount = State(initialValue: String(t.billingAmount))
            _selectedCategory = State(initialValue: t.category)
            _date = State(initialValue: t.date)
            _location = State(initialValue: t.location)
            _spendingCurrency = State(initialValue: t.location)
            _billingCurrency = State(initialValue: nil) //
            _selectedCardIndex = State(initialValue: 0)
            
            _paymentMethod = State(initialValue: t.paymentMethod)
            _isOnlineShopping = State(initialValue: t.isOnlineShopping)
            _isCBFApplied = State(initialValue: t.isCBFApplied)
            
            // 初始化 CBF 状态
            _cbfAmount = State(initialValue: t.cbfAmount > 0 ? t.cbfAmount : nil)
            _showCBFInput = State(initialValue: t.cbfAmount > 0)
            
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
            _spendingAmount = State(initialValue: "")
            _billingAmount = State(initialValue: "")
            _selectedCategory = State(initialValue: .dining)
            _date = State(initialValue: Date())
            _location = State(initialValue: .cn)
            _spendingCurrency = State(initialValue: .cn)
            _billingCurrency = State(initialValue: nil) // 🆕 默认自动识别
            _selectedCardIndex = State(initialValue: 0)
            
            _paymentMethod = State(initialValue: "")
            _isOnlineShopping = State(initialValue: false)
            _isCBFApplied = State(initialValue: false)
            
            // 🆕 初始化 CBF 状态
            _cbfAmount = State(initialValue: nil)
            _showCBFInput = State(initialValue: false)
            
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
            applyChangeHandlers(to:
                formContent
                    .navigationTitle(transactionToEdit == nil ? AppConstants.Transaction.addTransactionTitle : AppConstants.Transaction.editTransactionTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(AppConstants.General.cancel) { dismiss() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(AppConstants.General.save) { saveTransaction() }
                                .disabled(merchant.isEmpty || spendingAmount.isEmpty || cards.isEmpty)
                        }
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(AppConstants.General.done) { focusedField = nil }
                        }
                    }
                    .onAppear(perform: handleOnAppear)
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
            )
        }
    }
    
    private func applyChangeHandlers(to content: some View) -> some View {
         content
             .onChange(of: selectedPhotoItem) { loadPhoto() }
             .onChange(of: receiptImage) { handleReceiptImageChange() }
             .onChange(of: spendingAmount) {
                 billingAmountFromReceipt = false // 重置 OCR 锁定状态
                 updateBillingAmount()
                 cashbackCalculationDetails = nil
             }
             .onChange(of: spendingCurrency) {
                 billingAmountFromReceipt = false // 重置 OCR 锁定状态
                 updateBillingAmount()
                 selectedCashbackRuleIndex = nil
                 cashbackCalculationDetails = nil
             }
             .onChange(of: billingCurrency) { // 🆕 监听入账币种变化
                 billingAmountFromReceipt = false
                 updateBillingAmount()
                 cashbackCalculationDetails = nil
             }
            .onChange(of: selectedCardIndex) {
                print("🔄 切换卡片 index: \(selectedCardIndex)")
                billingAmountFromReceipt = false
                updateBillingAmount()
                selectedCashbackRuleIndex = nil
                cashbackCalculationDetails = nil
            }
            .onChange(of: paymentMethod) { _, newValue in
                if newValue == AppConstants.Transaction.onlineShoppingLabel { isOnlineShopping = true }
                selectedCashbackRuleIndex = nil
                cashbackCalculationDetails = nil
            }
            .onChange(of: isOnlineShopping) {
                selectedCashbackRuleIndex = nil
                cashbackCalculationDetails = nil
            }
            .onChange(of: isCBFApplied) { cashbackCalculationDetails = nil }
            .onChange(of: cbfAmount) { cashbackCalculationDetails = nil } // 🆕 监听 CBF 金额变化
            .onChange(of: selectedCategory) { cashbackCalculationDetails = nil }
            .onChange(of: location) { cashbackCalculationDetails = nil }
            .onChange(of: date) { cashbackCalculationDetails = nil }
    }
    
    private var formContent: some View {
        Form {
            // 1. 消费详情
            ConsumptionDetailsSection(
                merchant: $merchant,
                spendingAmount: $spendingAmount,
                selectedCategory: $selectedCategory,
                location: $location,
                spendingCurrency: $spendingCurrency,
                billingCurrency: $billingCurrency,
                billingAmount: $billingAmount,
                billingAmountFromReceipt: $billingAmountFromReceipt,
                cards: cards,
                selectedCardIndex: selectedCardIndex,
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
                onClearData: clearAIRecognizedData,
                onReanalyze: analyzeReceipt
            )
            
            // 4. 支付方式与入账
            PaymentCardSection(
                cards: cards,
                selectedCardIndex: $selectedCardIndex,
                date: $date
            )
            
            // 5. 返现规则与计算
            if cards.indices.contains(selectedCardIndex) {
                CashbackSection(
                    card: cards[selectedCardIndex],
                    spendingAmount: spendingAmount,
                    billingAmount: billingAmount,
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
    }
    
    // MARK: - Logic Methods
    
    private func handleOnAppear() {
        if let t = transactionToEdit, let card = t.card,
           let index = cards.firstIndex(of: card) {
            selectedCardIndex = index
        } else if transactionToEdit == nil && receiptImage != nil && merchant.isEmpty && spendingAmount.isEmpty {
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
                    self.selectedPhotoItem = nil // 释放 PhotoItem，停止系统相机的占用
                    // 清除旧的 AI 数据 (如果是重新上传)
                    if transactionToEdit == nil {
                         // onChange of receiptImage will trigger analysis
                    }
                }
            } else {
                // 如果加载失败（例如用户取消），也要置空以允许再次点击
                await MainActor.run {
                    self.selectedPhotoItem = nil
                }
            }
        }
    }
    
    private func handleReceiptImageChange() {
        if receiptImage != nil && transactionToEdit == nil {
            logger.info("New receipt photo detected, starting AI analysis")
            analyzeReceipt()
        }
    }
    
    private func analyzeReceipt() {
        guard let image = receiptImage, aiAvailability.isSupported else { return }
        print(AppConstants.Transaction.aiAnalyzingReceipt)
        
        // 重置所有状态以确保是全新的分析
        clearAIRecognizedData()
        
        isAnalyzing = true
        
        Task {
            let metadata = await OCRService.analyzeImage(image)
            await MainActor.run {
                isAnalyzing = false
                guard let data = metadata else { return }
                
                if let amt = data.spendingAmount {
                    logger.info("✅ AI 识别消费金额: \(amt)")
                    self.spendingAmount = String(format: "%.2f", abs(amt))
                }
                
                // 🆕 识别消费币种
                if let currency = data.currency,
                   let matchedRegion = Region.allCases.first(where: { $0.currencyCode == currency }) {
                    self.spendingCurrency = matchedRegion
                    logger.info("✅ AI 识别消费币种: \(currency)")
                }
                
                // 🆕 识别入账金额和币种
                if let billingAmt = data.billingAmount {
                    self.billingAmount = String(format: "%.2f", abs(billingAmt))
                    self.billingAmountFromReceipt = true
                    logger.info("✅ AI 识别入账金额: \(billingAmt)")
                    
                    // 如果有入账币种，也设置它
                    if let billingCurr = data.billingCurrency,
                       let matchedBillingRegion = Region.allCases.first(where: { $0.currencyCode == billingCurr }) {
                        self.billingCurrency = matchedBillingRegion
                        logger.info("✅ AI 识别入账币种: \(billingCurr)")
                    }
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
                
                let detectedMethod = data.paymentMethod
                if let method = detectedMethod, !method.isEmpty {
                    self.paymentMethod = method
                } else {
                    self.paymentMethod = AppConstants.OCR.sale
                }
                print("支付方式", self.paymentMethod)
            }
        }
    }
    
    private func clearAIRecognizedData() {
        merchant = ""
        spendingAmount = ""
        billingAmount = ""
        selectedCategory = .dining
        date = Date()
        paymentMethod = ""
        isOnlineShopping = false
        isCBFApplied = false
        spendingCurrency = .cn
        billingCurrency = nil // 🆕 重置入账币种
        billingAmountFromReceipt = false
        selectedCashbackRuleIndex = nil
        cashbackCalculationDetails = nil
    }
    
    private func updateBillingAmount() {
        print("🔄 updateBillingAmount 被调用... 锁定状态: \(billingAmountFromReceipt)")
        if billingAmountFromReceipt { return }
        guard let spendingAmountDouble = Double(spendingAmount) else { return }
        guard cards.indices.contains(selectedCardIndex) else {
            billingAmount = spendingAmount
            return
        }
        
        let card = cards[selectedCardIndex]
        let spendingCurrencyCode = spendingCurrency.currencyCode
        
        Task {
            let billing = await CashbackService.calculateBillingAmount(card: card, spendingAmount: spendingAmountDouble, spendingCurrencyCode: spendingCurrencyCode)
            print("这里的billingamount是啥3",billing)
                await MainActor.run {
                    self.billingAmount = String(format: "%.2f", billing)
                }
            }
    }
    
    private func saveTransaction() {
        guard let spendingAmountDouble = Double(spendingAmount) else { return }
        let billingAmountDouble = Double(billingAmount) ?? spendingAmountDouble
        
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
                    billingAmount: billingAmountDouble,
                    category: selectedCategory,
                    location: location,
                    date: date,
                    transactionToExclude: transactionToEdit
                )
                nominalRate = card.getRate(for: selectedCategory, location: location)
            }
            
            if let t = transactionToEdit {
                t.merchant = merchant
                t.spendingAmount = spendingAmountDouble
                t.location = location
                t.date = date
                t.paymentMethod = paymentMethod
                t.isOnlineShopping = isOnlineShopping
                t.isCBFApplied = isCBFApplied
                
                // 🆕 更新 CBF 金额
                t.cbfAmount = cbfAmount ?? 0.0
                
                if t.card != card || t.billingAmount != billingAmountDouble || t.category != selectedCategory || t.date != date {
                    t.card = card
                    t.billingAmount = billingAmountDouble
                    t.category = selectedCategory
                    t.rate = nominalRate
                    t.cashbackamount = finalCashback
                    // t.cbfAmount = cashbackCalculationDetails?.cbfAmount ?? 0.0 // 旧逻辑
                }
                
                if let img = imageData { t.receiptData = img }
            } else {
                let newTransaction = Transaction(
                    merchant: merchant,
                    category: selectedCategory,
                    location: location,
                    spendingAmount: spendingAmountDouble,
                    date: date,
                    card: card,
                    paymentMethod: paymentMethod,
                    isOnlineShopping: isOnlineShopping,
                    isCBFApplied: isCBFApplied,
                    receiptData: imageData,
                    billingAmount: billingAmountDouble,
                    cashbackAmount: finalCashback,
                    cbfAmount: cbfAmount ?? 0.0 // 🆕 使用手动输入的 CBF
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
    @Binding var spendingAmount: String//消费金额
    @Binding var selectedCategory: Category
    @Binding var location: Region
    @Binding var spendingCurrency: Region//消费币种
    @Binding var billingCurrency: Region? // 🆕 入账币种
    @Binding var billingAmount: String // 🆕 入账金额
    @Binding var billingAmountFromReceipt: Bool // 🆕 是否来自 OCR
    var cards: [CreditCard] // 🆕 需要卡片信息来推断自动币种
    var selectedCardIndex: Int // 🆕 当前选中的卡片
    var focusedField: FocusState<AddTransactionView.Field?>.Binding
    var body: some View {
        Section(header: Text(AppConstants.Transaction.consumptionDetails)) {
            TextField(AppConstants.Transaction.merchantNamePlaceholder, text: $merchant)
                .focused(focusedField, equals: .merchant)
                .submitLabel(.next)
            
            // --- 消费币种 ---
            Picker(AppConstants.Transaction.spendingCurrency, selection: $spendingCurrency) {
                ForEach(Region.allCases, id: \.self) { r in
                    Text("\(r.icon) \(r.currencyCode)").tag(r)
                }
            }
            
            // --- 消费金额 ---
            HStack {
                Text(spendingCurrency.currencySymbol)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                TextField(AppConstants.Transaction.spendingAmount, text: $spendingAmount)
                    .keyboardType(.decimalPad)
                    .focused(focusedField, equals: .spendingAmount)
            }
            
            // --- 入账币种---
            if cards.indices.contains(selectedCardIndex) {
                let card = cards[selectedCardIndex]
                let cardCurrency = card.issueRegion

                // 只有当消费币种和卡片默认币种不同时才显示
                if spendingCurrency.currencyCode != cardCurrency.currencyCode {
                    // 入账金额输入框
                    HStack {
                        Text(cardCurrency.currencySymbol)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        
                        TextField("入账金额", text: $billingAmount)
                            .keyboardType(.decimalPad)
                            .focused(focusedField, equals: .billingAmount)
                            .onChange(of: billingAmount) { oldValue, newValue in
                                if billingAmountFromReceipt && oldValue != newValue {
                                    billingAmountFromReceipt = false
                                }
                            }
                    }
                    
                    // AI 识别标记
                    if billingAmountFromReceipt {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("此金额由 AI 从小票识别")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
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
    
    // 🆕 获取自动识别的入账币种
//    private func getAutoBillingCurrency(for card: CreditCard) -> Region {
//        print("切卡了？",card.bankName)
//        let isPulse = card.bankName.localizedCaseInsensitiveContains("Pulse")
//        let spendingCurrencyCode = spendingCurrency.currencyCode
//        print(spendingCurrencyCode)
//        return card.issueRegion
//    }
}

private struct TransactionAttributesSection: View {
    @Binding var paymentMethod: String
    @Binding var isOnlineShopping: Bool
    @Binding var isCBFApplied: Bool
    var aiSupported: Bool
    
    private var filterOptions: [String] {
        var options = [AppConstants.OCR.sale] // 默认 SALE 放第一位
        options.append(contentsOf: AppConstants.OCR.PaymentDetection.candidates)
        return options
    }
    
    var body: some View {
        Section(header: Text(AppConstants.Transaction.transactionAttributes)) {
            Picker(AppConstants.Transaction.paymentMethodLabel, selection: $paymentMethod) {
                Text(AppConstants.General.notSelected).tag("")
                ForEach(filterOptions, id: \.self) { method in
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
    var onReanalyze: () -> Void
    
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
                
                Button {
                    onReanalyze()
                } label: {
                    Label("重新分析", systemImage: "arrow.triangle.2.circlepath.circle")
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
    @Binding var date: Date
    
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
            
            DatePicker(AppConstants.Transaction.consumptionDate, selection: $date, in: ...Date(), displayedComponents: .date)
        }
    }
}

private struct CashbackSection: View {
    let card: CreditCard
    let spendingAmount: String
    let billingAmount: String
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
            } else if let spendingAmountDouble = Double(spendingAmount),spendingAmountDouble>0,
                      let billingAmountDouble = Double(billingAmount),billingAmountDouble>0 {
                
                CashbackCalculationView(
                    card: card,
                    spendingAmount: spendingAmountDouble,
                    billingAmount: billingAmountDouble,
                    spendingCurrencyCode: spendingCurrency.currencyCode,
                    paymentMethod: paymentMethod.isEmpty ? AppConstants.Transaction.otherPaymentMethod : paymentMethod,
                    isOnlineShopping: isOnlineShopping,
                    isCBFApplied: isCBFApplied,
                    category: category,
                    location: location,
                    date: date,
                    selectedRuleIndex: selectedRuleIndex,
                    transactionToExclude: transactionToEdit,
                    onResult: { calculationDetails = $0 }
                )
                .id(combineHashValues(card: card, spendingAmount: spendingAmountDouble, billingAmount: billingAmountDouble, spendingCurrencyCode: spendingCurrency.currencyCode, method: paymentMethod, online: isOnlineShopping, cbf: isCBFApplied, cat: category, loc: location, date: date, rule: selectedRuleIndex))
                
                if let details = calculationDetails {
                    CalculationResultView(details: details)
                }
            } else {
                Text(AppConstants.Transaction.enterConsumptionAmount).foregroundColor(.secondary).font(.caption)
            }
        }
    }
    private func combineHashValues(card: CreditCard, spendingAmount: Double, billingAmount: Double, spendingCurrencyCode: String, method: String, online: Bool, cbf: Bool, cat: Category, loc: Region, date: Date, rule: Int?) -> Int {
        var hasher = Hasher()
        hasher.combine(card.id)
        hasher.combine(spendingAmount)
        hasher.combine(billingAmount)
        hasher.combine(spendingCurrencyCode)
        hasher.combine(method)
        hasher.combine(online)
        hasher.combine(cbf)
        hasher.combine(cat)
        hasher.combine(loc)
        hasher.combine(date)
        hasher.combine(rule)
        return hasher.finalize()
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
    let spendingAmount: Double
    let billingAmount: Double
    let spendingCurrencyCode: String
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
        hasher.combine(spendingAmount)
        hasher.combine(billingAmount)
        hasher.combine(selectedRuleIndex)
        hasher.combine(paymentMethod)
        hasher.combine(isOnlineShopping)
        hasher.combine(isCBFApplied)
        hasher.combine(category)
        hasher.combine(location)
        hasher.combine(spendingCurrencyCode)
        hasher.combine(date)
        return hasher.finalize()
    }
    
    private func calculate() async {
        // 立即设置 loading，防止 UI 闪烁
        withAnimation { isLoading = true }
        
        // 延迟极短时间确保状态更新已生效（可选）
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        print("这里的billingamount是啥",billingAmount)
        let calculationResult = await CashbackService.calculateCashbackWithDetails(
            card: card,
            spendingAmount: spendingAmount,
            spendingCurrencyCode: spendingCurrencyCode,
            paymentMethod: paymentMethod,
            isOnlineShopping: isOnlineShopping,
            isCBFApplied: isCBFApplied,
            category: category,
            location: location,
            date: date,
            selectedConditionIndex: selectedRuleIndex,
            transactionToExclude: transactionToExclude,
            billingAmount: billingAmount
        )
        
        await MainActor.run {
            onResult(calculationResult)
            withAnimation { isLoading = false }
        }
    }
}


