//
//  AddCardView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData

struct AddCardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // 接收要编辑的卡片 (如果是 nil 就是添加模式)
    let cardToEdit: CreditCard?
    let onSaved: (() -> Void)?

    // MARK: - Form State

    @State private var bankName: String
    @State private var endNum: String

    @State private var cardOrganization: CardOrganization
    @State private var cardLevel: CardLevel
    @State private var region: Region
    @State private var repaymentDayStr: String
    @State private var isRemindOpen: Bool

    // 外币交易费率（百分比，整型输入）
    @State private var ftf: Double
    @State private var cbf: Int
    
    /// 免 FTF 币种
    @State private var ftfExceptCurrencies: Set<Currency>

    // 多基础返现条件
    @State private var baseCashbackConditions: [BaseCashbackCondition]

    // 类别加成（额外叠加）
    @State private var categoryBonus: [CategoryBonus]

    // 图片选择相关
    @State private var selectedCardImage: UIImage?
    @State private var showImagePicker = false
    @State private var showImageCropper = false
    @State private var imageToEdit: UIImage?

    // 模板图片下载相关
    @StateObject private var imageDownloader = ImageDownloadManager()
    private let templatePictureURL: String?
    @State private var hasDownloadedTemplateImage = false
    
    // Sheet State
    @State private var activeCashbackSheet: ActiveMultiSelectSheet?
    
    // 焦点管理
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case bankName, endNum, ftf, cbf, repaymentDay, customCurrency(String), customMethod(String), rate(String), monthlyCap(String), yearlyCap(String), customCategory(String), bonusRate(String), bonusCap(String)
    }

    // MARK: - Init

    init(template: CardTemplate? = nil, cardToEdit: CreditCard? = nil, onSaved: (() -> Void)? = nil) {
        self.cardToEdit = cardToEdit
        self.onSaved = onSaved
        self.templatePictureURL = template?.pictureURL

        let config: FormConfiguration
        if let cardToEdit {
            config = .from(card: cardToEdit)
        } else if let template {
            config = .from(template: template)
        } else {
            config = .empty
        }

        _bankName = State(initialValue: config.bankName)
        _endNum = State(initialValue: config.endNum)
        _repaymentDayStr = State(initialValue: config.repaymentDayStr)
        _isRemindOpen = State(initialValue: config.isRemindOpen)
        _ftf = State(initialValue: config.ftf)
        _cbf = State(initialValue: config.cbf)
        _ftfExceptCurrencies = State(initialValue: config.ftfExceptCurrencies)

        _cardOrganization = State(initialValue: config.cardOrganization)
        _cardLevel = State(initialValue: config.cardLevel)
        _region = State(initialValue: config.region)

        _baseCashbackConditions = State(initialValue: config.baseCashbackConditions)
        _categoryBonus = State(initialValue: config.categoryBonus)

        if let imageData = cardToEdit?.cardImageData {
            _selectedCardImage = State(initialValue: UIImage(data: imageData))
        } else {
            _selectedCardImage = State(initialValue: nil)
        }
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            Form {
                ImageStatusSection(imageDownloader: imageDownloader)
                
                CardPreviewSection(
                    bankName: bankName,
                    cardOrganization: cardOrganization,
                    cardLevel: cardLevel,
                    endNum: endNum,
                    selectedCardImage: selectedCardImage
                )

                BasicInfoSection(
                    bankName: $bankName,
                    cardOrganization: $cardOrganization,
                    cardLevel: $cardLevel,
                    region: $region,
                    endNum: $endNum,
                    ftf: $ftf,
                    cbf: $cbf,
                    ftfExceptCurrencies: $ftfExceptCurrencies,
                    repaymentDayStr: $repaymentDayStr,
                    isRemindOpen: $isRemindOpen,
                    selectedCardImage: $selectedCardImage,
                    showImagePicker: $showImagePicker,
                    focusedField: $focusedField
                )

                BaseCashbackSection(
                    conditions: $baseCashbackConditions,
                    activeSheet: $activeCashbackSheet,
                    focusedField: $focusedField
                )

                CategoryBonusSection(
                    bonuses: $categoryBonus,
                    focusedField: $focusedField
                )
            }
            .navigationTitle(cardToEdit == nil ? AppConstants.Card.addCreditCard : AppConstants.Card.editCard)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppConstants.General.cancel) {
                        if hasDownloadedTemplateImage || imageDownloader.isDownloading {
                            imageDownloader.cleanup()
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppConstants.General.save) { saveCard() }
                        .disabled(bankName.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(AppConstants.General.done) { focusedField = nil }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .task {
                if let pictureURL = templatePictureURL,
                   !hasDownloadedTemplateImage,
                   selectedCardImage == nil {
                    await imageDownloader.downloadImage(from: pictureURL)
                    hasDownloadedTemplateImage = true

                    if let downloadedImage = imageDownloader.downloadedImage {
                        selectedCardImage = downloadedImage
                    }
                }
            }
            .onChange(of: imageDownloader.downloadedImage) { _, newValue in
                if let image = newValue, selectedCardImage == nil {
                    selectedCardImage = image
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $imageToEdit)
            }
            .sheet(isPresented: $showImageCropper) {
                if let image = imageToEdit {
                    ImageCropperView(image: image) { croppedImage in
                        selectedCardImage = croppedImage
                    }
                }
            }
            .onChange(of: imageToEdit) { _, newValue in
                if newValue != nil { showImageCropper = true }
            }
            .sheet(item: $activeCashbackSheet) { sheet in
                MultiSelectSheetWrapper(sheet: sheet, conditions: $baseCashbackConditions)
            }
        }
    }

    // MARK: - Save

    private func saveCard() {
        // 1. 序列化所有返现条件
        let encoder = JSONEncoder()
        let conditionsData = try? encoder.encode(baseCashbackConditions)

        // 2. 向后兼容：使用第一个条件作为主数据
        let firstCondition = baseCashbackConditions.first
        let defaultRate = Double(firstCondition?.rate ?? 0) / 10_000.0
        let repaymentDay = Int(repaymentDayStr) ?? 0

        // FTF / CBF：Int(%) -> Double(小数)
        let ftfValue = ftf / 100.0
        let cbfValue = Double(cbf) / 100.0

        // 处理类别加成
        var specialRates: [Category: Double] = [:]
        var catCaps: [Category: Double] = [:]

        for bonus in categoryBonus {
            if let category = bonus.category, category != .other {
                // 标准类别：保存到 specialRates
                if bonus.rate > 0 {
                    specialRates[category] = Double(bonus.rate) / 10_000.0
                }
                if bonus.cap > 0 {
                    catCaps[category] = Double(bonus.cap)
                }
            }
        }

        // 上限（取最大的上限作为主上限）
        let monthlyCap = baseCashbackConditions.compactMap { $0.monthlyBaseCap > 0 ? Double($0.monthlyBaseCap) : nil }.max()
        let yearlyCap = baseCashbackConditions.compactMap { $0.yearlyBaseCap > 0 ? Double($0.yearlyBaseCap) : nil }.max()

        if let existingCard = cardToEdit {
            existingCard.bankName = bankName
            existingCard.cardOrganization = cardOrganization
            existingCard.cardLevel = cardLevel
            existingCard.endNum = endNum
            existingCard.defaultRate = defaultRate
            existingCard.issueRegion = region
            existingCard.specialRates = specialRates

            existingCard.monthlyBaseCap = monthlyCap
            existingCard.yearlyBaseCap = yearlyCap
            existingCard.categoryCaps = catCaps
            existingCard.repaymentDay = repaymentDay
            existingCard.isRemindOpen = isRemindOpen

            existingCard.ftf = ftfValue
            existingCard.cbf = cbfValue
            existingCard.ftfExceptCurrencyCodes = ftfExceptCurrencies.map(\.currencyCode).sorted()

            existingCard.cardImageData = selectedCardImage?.jpegData(compressionQuality: 0.8)
            existingCard.baseCashbackConditionsData = conditionsData

            NotificationManager.shared.scheduleNotification(for: existingCard)
        } else {
            let newCard = CreditCard(
                bankName: bankName,
                cardOrganization: cardOrganization,
                cardLevel: cardLevel,
                endNum: endNum,
                defaultRate: defaultRate,
                specialRates: specialRates,
                issueRegion: region,
                monthlyBaseCap: monthlyCap,
                yearlyBaseCap: yearlyCap,
                categoryCaps: catCaps,
                repaymentDay: repaymentDay,
                isRemindOpen: isRemindOpen,
                ftf: ftfValue,
                cbf: cbfValue,
                ftfExceptCurrencyCodes: ftfExceptCurrencies.map(\.currencyCode).sorted(),
                cardImageData: selectedCardImage?.jpegData(compressionQuality: 0.8)
            )

            newCard.baseCashbackConditionsData = conditionsData

            context.insert(newCard)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationManager.shared.scheduleNotification(for: newCard)
            }
        }

        dismiss()
        onSaved?()
    }
}

// MARK: - Subviews

private struct ImageStatusSection: View {
    @ObservedObject var imageDownloader: ImageDownloadManager
    
    var body: some View {
        if imageDownloader.isDownloading {
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Text(AppConstants.Card.downloadingCardImage).font(.headline)
                        Spacer()
                        Button(AppConstants.General.cancel) { imageDownloader.cancelDownload() }
                            .foregroundColor(.red)
                    }
                    ProgressView(value: imageDownloader.downloadProgress) {
                        Text(String(format: AppConstants.Card.downloadedPercent, Int(imageDownloader.downloadProgress * 100)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        
        if let error = imageDownloader.errorMessage {
            Section {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(error).font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct CardPreviewSection: View {
    let bankName: String
    let cardOrganization: CardOrganization
    let cardLevel: CardLevel
    let endNum: String
    let selectedCardImage: UIImage?
    
    var body: some View {
        Section {
            CreditCardView(
                bankName: bankName.isEmpty ? AppConstants.Card.bankNameDefault : bankName,
                type: "\(cardOrganization.displayName) \(cardLevel.displayName)",
                endNum: endNum.isEmpty ? AddCardView.defaultEndNum : endNum,
                cardOrganization: cardOrganization,
                cardImageData: selectedCardImage?.jpegData(compressionQuality: 0.8)
            )
            .listRowInsets(EdgeInsets())
            .padding(.vertical)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

private struct BasicInfoSection: View {
    @Binding var bankName: String
    @Binding var cardOrganization: CardOrganization
    @Binding var cardLevel: CardLevel
    @Binding var region: Region
    @Binding var endNum: String
    @Binding var ftf: Double
    @Binding var cbf: Int
    @Binding var ftfExceptCurrencies: Set<Currency>
    @Binding var repaymentDayStr: String
    @Binding var isRemindOpen: Bool
    @Binding var selectedCardImage: UIImage?
    @Binding var showImagePicker: Bool
    var focusedField: FocusState<AddCardView.Field?>.Binding
    
    var body: some View {
        Section(header: Text(AppConstants.Card.basicInfo)) {
            HStack {
                Text(AppConstants.Card.cardNameLabel).frame(width: 80, alignment: .leading)
                TextField(AppConstants.Card.bankNamePlaceholder, text: $bankName)
                    .multilineTextAlignment(.trailing)
                    .focused(focusedField, equals: .bankName)
            }
            
            Picker(AppConstants.Card.cardOrganization, selection: $cardOrganization) {
                ForEach(CardOrganization.allCases, id: \.self) { org in
                    Text(org.displayName).tag(org)
                }
            }
            .onChange(of: cardOrganization) { _, newValue in
                if let firstLevel = newValue.availableLevels.first { cardLevel = firstLevel }
            }
            
            Picker(AppConstants.Card.cardLevel, selection: $cardLevel) {
                ForEach(cardOrganization.availableLevels, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            
            Picker(AppConstants.Card.issueRegion, selection: $region) {
                ForEach(Region.allCases, id: \.self) { r in
                    Text("\(r.icon) \(r.rawValue)").tag(r)
                }
            }
            
            HStack {
                Text(AppConstants.Transaction.cardTailNumber).frame(width: 80, alignment: .leading)
                Spacer()
                TextField(AppConstants.Card.lastFourDigits, text: $endNum)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .focused(focusedField, equals: .endNum)
                    .onChange(of: endNum) { _, newValue in
                        if newValue.count > 4 { endNum = String(newValue.prefix(4)) }
                    }
            }
            
            HStack {
                Text(AppConstants.Card.ftfLabel).frame(width: 80, alignment: .leading)
                Spacer()
                TextField(AppConstants.Card.ftfDescription, value: $ftf, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused(focusedField, equals: .ftf)
                Text("%").foregroundColor(.secondary)
            }
            
            NavigationLink {
                CurrencyMultiSelectView(
                    title: AppConstants.Card.exemptFTFCurrencies,
                    selection: $ftfExceptCurrencies,
                    candidates: Currency.allCases.filter { $0 != .other }
                )
            } label: {
                HStack {
                    Text(AppConstants.Card.exemptFTFCurrencies).frame(width: 80, alignment: .leading)
                    Spacer()
                    Text(ftfExceptCurrencies.isEmpty ? AppConstants.General.none : ftfExceptCurrencies.map(\.currencyCode).sorted().joined(separator: ", "))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            HStack {
                Text(AppConstants.Card.cbfLabel).frame(width: 80, alignment: .leading)
                Spacer()
                TextField(AppConstants.Card.cbfDescription, value: $cbf, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused(focusedField, equals: .cbf)
                Text("%").foregroundColor(.secondary)
            }
            
            HStack {
                Text(AppConstants.Card.repaymentReminderMonthly)
                Spacer()
                TextField(AppConstants.General.none, text: $repaymentDayStr)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .focused(focusedField, equals: .repaymentDay)
                    .onChange(of: repaymentDayStr) { _, newValue in
                        if let day = Int(newValue), day > 31 { repaymentDayStr = "31" }
                    }
                Text("日").foregroundColor(.secondary)
            }
            
            HStack {
                Text(AppConstants.Card.enableRepaymentReminder)
                Spacer()
                Toggle("", isOn: $isRemindOpen).labelsHidden()
            }
            .disabled(repaymentDayStr.isEmpty || Int(repaymentDayStr) == 0)
            .opacity((repaymentDayStr.isEmpty || Int(repaymentDayStr) == 0) ? 0.5 : 1.0)
            
            if let day = Int(repaymentDayStr), day > 0, isRemindOpen {
                Text(String(format: AppConstants.Card.reminderMessage, day))
                    .font(.caption).foregroundColor(.secondary)
            }
            
            HStack {
                Text(AppConstants.Card.cardFaceManagement).foregroundColor(.primary)
                Spacer()
                Button { showImagePicker = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedCardImage != nil ? "photo.badge.arrow.down" : "photo.badge.plus")
                        Text(selectedCardImage != nil ? AppConstants.Card.changeCardFace : AppConstants.Card.addCardFace)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

private struct BaseCashbackSection: View {
    @Binding var conditions: [AddCardView.BaseCashbackCondition]
    @Binding var activeSheet: AddCardView.ActiveMultiSelectSheet?
    var focusedField: FocusState<AddCardView.Field?>.Binding
    
    var body: some View {
        Section(header: Text(AppConstants.Card.baseCashbackAll)) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill").foregroundColor(.blue)
                Text(AppConstants.Transaction.transactionTypeNote)
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            
            ForEach(Array(conditions.enumerated()), id: \.element.id) { index, _ in
                // 使用 Binding 传递给子视图
                BaseCashbackRow(
                    condition: $conditions[index],
                    index: index,
                    activeSheet: $activeSheet,
                    focusedField: focusedField
                )
            }
            .onDelete { conditions.remove(atOffsets: $0) }
            
            Button {
                conditions.append(AddCardView.BaseCashbackCondition(
                    currencies: [AddCardView.defaultCurrency],
                    paymentMethods: AddCardView.defaultPaymentMethods,
                    defaultRate: AddCardView.defaultCashbackRate,
                    monthlyBaseCap: 0,
                    yearlyBaseCap: 0
                ))
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                    Text(AppConstants.Card.addCondition)
                }
            }
        }
    }
}

private struct BaseCashbackRow: View {
    @Binding var condition: AddCardView.BaseCashbackCondition
    let index: Int
    @Binding var activeSheet: AddCardView.ActiveMultiSelectSheet?
    var focusedField: FocusState<AddCardView.Field?>.Binding
    
    var body: some View {
        VStack(spacing: 12) {
            // 币种
            HStack {
                Text(AppConstants.Transaction.consumptionCurrencyLabel)
                Spacer()
                Button {
                    activeSheet = .currencies(index: index)
                } label: {
                    HStack {
                        Spacer(minLength: 0)
                        Text(AddCardView.displayCurrencySelection(condition.currencies))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                    .frame(minWidth: 180, alignment: .trailing)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            if condition.currencies.contains(.other) {
                HStack {
                    Spacer()
                    TextField(AppConstants.Transaction.enterCurrency, text: $condition.customCurrency)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        .padding(5)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(5)
                        .focused(focusedField, equals: .customCurrency(condition.id.uuidString))
                }
            }
            
            // 方式
            HStack {
                Text(AppConstants.Transaction.consumptionMethodLabel)
                Spacer()
                Button {
                    activeSheet = .paymentMethods(index: index)
                } label: {
                    HStack {
                        Spacer(minLength: 0)
                        Text(AddCardView.displayPaymentMethodSelection(condition.paymentMethods))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                    .frame(minWidth: 180, alignment: .trailing)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            if condition.paymentMethods.contains(AddCardView.otherPaymentMethodValue) {
                HStack {
                    Spacer()
                    TextField(AppConstants.Transaction.enterMethod, text: $condition.customPaymentMethod)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        .padding(5)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(5)
                        .focused(focusedField, equals: .customMethod(condition.id.uuidString))
                }
            }
            
            // 交易类型
            Picker("", selection: $condition.transactionType) {
                ForEach(AddCardView.TransactionType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            // 返现率
            HStack {
                Text(AppConstants.Card.cashbackRateLabel)
                Spacer()
                TextField("1.0", text: $condition.rateStr)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .padding(5)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(5)
                    .focused(focusedField, equals: .rate(condition.id.uuidString))
            }
            
            // 上限
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(AppConstants.Card.monthlyCapLabel)
                    Spacer()
                    TextField(AppConstants.Card.unlimited, text: $condition.monthlyCapStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .padding(5)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(5)
                        .focused(focusedField, equals: .monthlyCap(condition.id.uuidString))
                }
                
                HStack {
                    Text(AppConstants.Card.yearlyCapLabel)
                    Spacer()
                    TextField(AppConstants.Card.unlimited, text: $condition.yearlyCapStr)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .padding(5)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(5)
                        .focused(focusedField, equals: .yearlyCap(condition.id.uuidString))
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct MultiSelectSheetWrapper: View {
    let sheet: AddCardView.ActiveMultiSelectSheet
    @Binding var conditions: [AddCardView.BaseCashbackCondition]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            switch sheet {
            case let .currencies(index):
                if conditions.indices.contains(index) {
                    CurrencyMultiSelectView(
                        title: AppConstants.Transaction.consumptionCurrencyMulti,
                        selection: Binding(
                            get: { conditions[index].currencies },
                            set: { newValue in
                                conditions[index].currencies = newValue
                                if !newValue.contains(.other) {
                                    conditions[index].customCurrency = ""
                                }
                            }
                        ),
                        candidates: Currency.allCases
                    )
                    .toolbar { Button(AppConstants.General.done) { dismiss() } }
                }
            case let .paymentMethods(index):
                if conditions.indices.contains(index) {
                    StringMultiSelectView(
                        title: AppConstants.Transaction.consumptionMethodMulti,
                        selection: Binding(
                            get: { conditions[index].paymentMethods },
                            set: { newValue in
                                conditions[index].paymentMethods = newValue
                                if !newValue.contains(AddCardView.otherPaymentMethodValue) {
                                    conditions[index].customPaymentMethod = ""
                                }
                            }
                        ),
                        candidates: AddCardView.paymentMethodCandidates
                    )
                    .toolbar { Button(AppConstants.General.done) { dismiss() } }
                }
            }
        }
    }
}

private struct CategoryBonusSection: View {
    @Binding var bonuses: [AddCardView.CategoryBonus]
    var focusedField: FocusState<AddCardView.Field?>.Binding
    
    var body: some View {
        Section(header: Text(AppConstants.Card.activityCashback)) {
            ForEach(Array(bonuses.enumerated()), id: \.element.id) { index, _ in
                VStack(spacing: 8) {
                    HStack {
                        if bonuses[index].category != nil {
                            Picker(AppConstants.Card.activityLabel, selection: Binding(
                                get: { bonuses[index].category ?? .dining },
                                set: { newCat in
                                    if newCat == .other {
                                        bonuses[index].category = nil
                                        bonuses[index].customCategory = ""
                                    } else {
                                        bonuses[index].category = newCat
                                    }
                                }
                            )) {
                                ForEach(Category.allCases, id: \.self) { cat in
                                    Text(cat.displayName).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            Text(AppConstants.Card.activityLabel).foregroundColor(.primary)
                            Spacer()
                            TextField(AppConstants.Card.customNamePlaceholder, text: $bonuses[index].customCategory)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 150)
                                .focused(focusedField, equals: .customCategory(bonuses[index].id.uuidString))
                        }
                    }
                    
                    HStack {
                        Text(AppConstants.Card.cashbackRateLabel).foregroundColor(.secondary)
                        Spacer()
                        TextField("0", text: $bonuses[index].rateStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                            .focused(focusedField, equals: .bonusRate(bonuses[index].id.uuidString))
                        Text("%").foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(AppConstants.Card.capLabel).foregroundColor(.secondary)
                        Spacer()
                        TextField(AppConstants.Card.unlimited, text: $bonuses[index].capStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused(focusedField, equals: .bonusCap(bonuses[index].id.uuidString))
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { bonuses.remove(atOffsets: $0) }
            
            Button {
                bonuses.append(AddCardView.CategoryBonus(category: .dining, rate: 0, cap: 0))
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                    Text(AppConstants.Card.pleaseAddActivity)
                }
            }
        }
    }
}

// MARK: - Types & Extensions

extension AddCardView {
    
    enum TransactionType: String, Codable, CaseIterable {
        case online = "线上交易"
        case offline = "线下交易"
        case unlimited = "不限"
        var displayName: String {
            switch self {
            case .online: return AppConstants.Transaction.onlineTransaction
            case .offline: return AppConstants.Transaction.offlineTransaction
            case .unlimited: return AppConstants.Transaction.unlimitedTransaction
            }
        }
    }

    enum ActiveMultiSelectSheet: Identifiable, Equatable {
        case currencies(index: Int)
        case paymentMethods(index: Int)
        var id: String {
            switch self {
            case let .currencies(index): return "currencies-\(index)"
            case let .paymentMethods(index): return "paymentMethods-\(index)"
            }
        }
    }

    struct BaseCashbackCondition: Identifiable, Equatable, Codable {
        let id: UUID
        var currencies: Set<Currency>
        var customCurrency: String
        var paymentMethods: Set<String>
        var customPaymentMethod: String
        var transactionType: TransactionType
        var rate: Int
        var monthlyBaseCap: Int
        var yearlyBaseCap: Int

        init(currencies: Set<Currency>, customCurrency: String = "", paymentMethods: Set<String>, customPaymentMethod: String = "", transactionType: TransactionType = .unlimited, defaultRate: Int, monthlyBaseCap: Int, yearlyBaseCap: Int) {
            self.id = UUID()
            self.currencies = currencies
            self.customCurrency = customCurrency
            self.paymentMethods = paymentMethods
            self.customPaymentMethod = customPaymentMethod
            self.transactionType = transactionType
            self.rate = defaultRate
            self.monthlyBaseCap = monthlyBaseCap
            self.yearlyBaseCap = yearlyBaseCap
        }

        // UI 绑定桥接（保持你原来 UI 的 TextField 逻辑不变）
        var rateStr: String {
            get { Formatters.percentString(fromScaledPercent: rate) }
            set { rate = Formatters.scaledPercent(from: newValue) }
        }

        var monthlyCapStr: String {
            get { monthlyBaseCap > 0 ? String(monthlyBaseCap) : "" }
            set { monthlyBaseCap = Formatters.intOrZero(from: newValue) }
        }

        var yearlyCapStr: String {
            get { yearlyBaseCap > 0 ? String(yearlyBaseCap) : "" }
            set { yearlyBaseCap = Formatters.intOrZero(from: newValue) }
        }
    }

    struct CategoryBonus: Identifiable, Equatable {
        let id: UUID
        var category: Category?
        var customCategory: String
        var rate: Int
        var cap: Int
        
        init(category: Category?, customCategory: String = "", rate: Int = 0, cap: Int = 0) {
            self.id = UUID()
            self.category = category
            self.customCategory = customCategory
            self.rate = rate
            self.cap = cap
        }
        
        // UI 绑定桥接
        var rateStr: String {
            get { Formatters.percentString(fromScaledPercent: rate) }
            set { rate = Formatters.scaledPercent(from: newValue) }
        }

        var capStr: String {
            get { cap > 0 ? String(cap) : "" }
            set { cap = Formatters.intOrZero(from: newValue) }
        }
    }

    // Constants & Helpers
    static let defaultCashbackRate = 100
    static let defaultEndNum = "8888"
    static let defaultCurrency: Currency = .cny
    static let defaultPaymentMethods: Set<String> = [AppConstants.OCR.PaymentDetection.candidates[0]] // "网购"
    static let otherPaymentMethodValue = AppConstants.OCR.PaymentDetection.candidates.last! // "未填写" (assuming it is last)
    static let paymentMethodCandidates: [String] = AppConstants.OCR.PaymentDetection.candidates

    static func displayCurrencySelection(_ selection: Set<Currency>) -> String {
        if selection.isEmpty { return "请选择" }
        return selection.map { $0 == .other ? "其他" : $0.currencyCode }.sorted().joined(separator: ", ")
    }

    static func displayPaymentMethodSelection(_ selection: Set<String>) -> String {
        if selection.isEmpty { return "请选择" }
        return selection.sorted().joined(separator: ", ")
    }
    
    struct FormConfiguration {
        var bankName: String
        var endNum: String
        var repaymentDayStr: String
        var isRemindOpen: Bool
        var ftf: Double
        var cbf: Int
        var ftfExceptCurrencies: Set<Currency>
        var baseCashbackConditions: [BaseCashbackCondition]
        var categoryBonus: [CategoryBonus]
        var cardOrganization: CardOrganization
        var cardLevel: CardLevel
        var region: Region

        static func from(card: CreditCard) -> FormConfiguration {
            var bonus: [CategoryBonus] = []
            for cat in Category.allCases {
                if let rate = card.specialRates[cat], rate > 0 {
                    let rateInt = Int((rate * 10_000).rounded())
                    let capInt = formatCapInt(card.categoryCaps[cat])
                    bonus.append(CategoryBonus(category: cat, rate: rateInt, cap: capInt))
                }
            }
            var conditions: [BaseCashbackCondition] = []
            if let data = card.baseCashbackConditionsData {
                conditions = (try? JSONDecoder().decode([BaseCashbackCondition].self, from: data)) ?? []
            }
            if conditions.isEmpty {
                conditions = [BaseCashbackCondition(currencies: [defaultCurrency], paymentMethods: defaultPaymentMethods, defaultRate: Int((card.defaultRate * 10_000).rounded()), monthlyBaseCap: Int(card.monthlyBaseCap ?? 0), yearlyBaseCap: Int(card.yearlyBaseCap ?? 0))]
            }
            return FormConfiguration(bankName: card.bankName, endNum: card.endNum, repaymentDayStr: card.repaymentDay > 0 ? String(card.repaymentDay) : "", isRemindOpen: card.isRemindOpen, ftf: card.ftf * 100, cbf: Int((card.cbf * 100).rounded()), ftfExceptCurrencies: Set(card.ftfExceptCurrencyCodes.compactMap { Currency(rawValue: $0) }), baseCashbackConditions: conditions, categoryBonus: bonus, cardOrganization: card.cardOrganization, cardLevel: card.cardLevel, region: card.issueRegion)
        }

        static func from(template: CardTemplate) -> FormConfiguration {
            let defRate = formatRateInt(template.defaultRate)
            var bonus: [CategoryBonus] = []
            for cat in Category.allCases {
                if let rate = template.specialRate[cat], rate > 0 {
                    bonus.append(CategoryBonus(category: cat, rate: formatRateInt(rate), cap: formatCapInt(template.categoryCaps[cat])))
                }
            }
            var conditions: [BaseCashbackCondition] = []
            let methods = template.paymentMethod.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if methods.isEmpty {
                conditions = [BaseCashbackCondition(currencies: [defaultCurrency], paymentMethods: defaultPaymentMethods, defaultRate: defRate, monthlyBaseCap: template.monthlyCap, yearlyBaseCap: template.yearlyCap)]
            } else {
                conditions = [BaseCashbackCondition(currencies: [defaultCurrency], paymentMethods: Set(methods), defaultRate: defRate, monthlyBaseCap: template.monthlyCap, yearlyBaseCap: template.yearlyCap)]
            }
            return FormConfiguration(bankName: template.bankName, endNum: defaultEndNum, repaymentDayStr: "", isRemindOpen: true, ftf: template.ftf, cbf: Int(template.cbf.rounded()), ftfExceptCurrencies: Set(template.ftfExceptCurrencyCodes.compactMap { Currency(rawValue: $0) }), baseCashbackConditions: conditions, categoryBonus: bonus, cardOrganization: template.cardOrganization, cardLevel: template.cardLevel, region: template.region)
        }

        static var empty: FormConfiguration {
            FormConfiguration(bankName: "", endNum: "", repaymentDayStr: "", isRemindOpen: true, ftf: 0, cbf: 0, ftfExceptCurrencies: [], baseCashbackConditions: [BaseCashbackCondition(currencies: [defaultCurrency], paymentMethods: defaultPaymentMethods, defaultRate: defaultCashbackRate, monthlyBaseCap: 0, yearlyBaseCap: 0)], categoryBonus: [], cardOrganization: .unionPay, cardLevel: .unionPayStandard, region: .cn)
        }
        
        private static func formatRateInt(_ rate: Double) -> Int { Int((rate * 100).rounded()) }
        private static func formatCapInt(_ cap: Double?) -> Int { guard let cap, cap > 0 else { return 0 }; return Int(cap) }
    }
}

// MARK: - Reusable Selection Views

private struct CurrencyMultiSelectView: View {
    let title: String
    @Binding var selection: Set<Currency>
    let candidates: [Currency]
    
    var body: some View {
        List {
            ForEach(candidates, id: \.self) { currency in
                Button {
                    if selection.contains(currency) { selection.remove(currency) } else { selection.insert(currency) }
                } label: {
                    HStack {
                        Text(currency.currencyCode)
                        Spacer()
                        if selection.contains(currency) { Image(systemName: "checkmark").foregroundColor(.blue) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(title)
    }
}

private struct StringMultiSelectView: View {
    let title: String
    @Binding var selection: Set<String>
    let candidates: [String]
    
    var body: some View {
        List {
            ForEach(candidates, id: \.self) { value in
                Button {
                    if selection.contains(value) { selection.remove(value) } else { selection.insert(value) }
                } label: {
                    HStack {
                        Text(value)
                        Spacer()
                        if selection.contains(value) { Image(systemName: "checkmark").foregroundColor(.blue) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(title)
    }
}
