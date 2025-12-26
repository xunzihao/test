//
//  StatementAnalysisView.swift
//  CashbackCounter
//
//  Created by Assistant on 12/19/25.
//

import SwiftUI
import SwiftData
import PhotosUI
import Vision

struct StatementAnalysisView: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    @Query var cards: [CreditCard]
    
    // MARK: - State
    
    // Image / PDF Selection
    @State private var selectedImage: UIImage?
    @State private var selectedPDFURL: URL?
    @State private var pdfImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var showPDFPicker = false
    
    // Analysis Status
    @State private var analysisResult: StatementAnalysisResult?
    @State private var isAnalyzing = false
    @State private var currentAnalyzingPage = 0
    @State private var totalPages = 0
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Warnings
    @State private var showPulseWarning = false
    
    // Card Matching & Cashback
    @State private var matchedCard: CreditCard?
    @State private var showCardPicker = false
    @State private var cashbackResults: [Int: Double] = [:]
    @State private var totalCashback: Double = 0.0
    @State private var isCalculatingCashback = false
    
    // Editing / Adding Transactions
    @State private var editingConfig: EditingTransactionConfig?
    @State private var showAddSheet = false
    
    // Helper struct for editing
    private struct EditingTransactionConfig: Identifiable {
        let id = UUID()
        let index: Int
        let transaction: StatementAnalysisResult.ParsedTransaction
    }
    
    // Analyzer
    private let analyzer = StatementAnalyzer()
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let image = selectedImage {
                    // Preview
                    StatementImagePreviewView(
                        image: image,
                        pdfImages: pdfImages,
                        onSelectPage: { selectedImage = $0 },
                        onReset: {
                            withAnimation { resetSelection() }
                        },
                        onChoosePDF: { showPDFPicker = true }
                    )
                    
                    Divider()
                    
                    // Analysis Flow
                    if let result = analysisResult {
                        StatementResultView(
                            result: result,
                            matchedCard: matchedCard,
                            cashbackResults: cashbackResults,
                            totalCashback: totalCashback,
                            isCalculatingCashback: isCalculatingCashback,
                            onSelectCard: { showCardPicker = true },
                            onEditTransaction: { index in
                                if let result = analysisResult, result.transactions.indices.contains(index) {
                                    editingConfig = EditingTransactionConfig(index: index, transaction: result.transactions[index])
                                }
                            },
                            onDeleteTransaction: deleteTransaction,
                            onAddTransaction: { showAddSheet = true }
                        )
                    } else if isAnalyzing {
                        StatementAnalyzingView(
                            currentPage: currentAnalyzingPage,
                            totalPages: totalPages
                        )
                    } else {
                        StatementAnalysisControlView(
                            totalPages: totalPages,
                            onStartAnalysis: startAnalysis
                        )
                    }
                } else {
                    // Empty State
                    StatementImageSelectionView(
                        onSelectImage: { showImagePicker = true },
                        onSelectPDF: { showPDFPicker = true }
                    )
                    // 确保空状态也应用相同的过渡，使其在切换时能够平滑衔接
                    .transition(.move(edge: .leading))
                }
            }
            // 将动画应用到整个 VStack 内容的变化上
            .animation(.easeInOut(duration: 0.3), value: selectedImage != nil)
            .navigationTitle(AppConstants.StatementAnalysis.monthlyStatementAnalysis)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedImage != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            withAnimation { resetSelection() }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
                
                if analysisResult != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppConstants.StatementAnalysis.importAction) { importTransactions() }
                            .disabled(matchedCard == nil)
                    }
                }
            }
            // Sheets & Alerts
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showPDFPicker) {
                PDFPicker(selectedPDFURL: $selectedPDFURL)
            }
            .sheet(isPresented: $showCardPicker) {
                StatementCardPickerView(cards: cards, selected: $matchedCard)
            }
            .sheet(item: $editingConfig) { config in
                NavigationStack {
                    AddTransactionToStatementView(
                        transactionToEdit: config.transaction,
                        onAdd: { updatedTrans in
                            updateTransaction(at: config.index, with: updatedTrans)
                            editingConfig = nil
                        },
                        onCancel: { editingConfig = nil }
                    )
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    AddTransactionToStatementView(
                        onAdd: { newTransaction in
                            addNewTransaction(newTransaction)
                            showAddSheet = false
                        },
                        onCancel: { showAddSheet = false }
                    )
                }
            }
            .alert(AppConstants.General.error, isPresented: $showError) {
                Button(AppConstants.General.confirm, role: .cancel) { }
            } message: {
                Text(errorMessage ?? AppConstants.General.unknownError)
            }
            .alert(AppConstants.StatementAnalysis.pulseWarningTitle, isPresented: $showPulseWarning) {
                Button(AppConstants.General.iKnow, role: .cancel) { }
            } message: {
                Text(AppConstants.StatementAnalysis.pulseWarningMessage)
            }
            // Logic Triggers
            .onChange(of: selectedImage) { _, newImage in
                if newImage != nil && pdfImages.isEmpty {
                    resetAnalysisState()
                }
            }
            .onChange(of: selectedPDFURL) { _, newURL in
                if let url = newURL {
                    resetAnalysisState()
                    processPDF(url: url)
                }
            }
            .onChange(of: matchedCard) { _, newCard in
                if let card = newCard, let result = analysisResult {
                    Task { await calculateCashbackForTransactions(result: result, card: card) }
                }
            }
        }
    }
    
    // MARK: - Logic Methods
    
    private func resetSelection() {
        pdfImages = []
        totalPages = 0
        selectedPDFURL = nil
        selectedImage = nil // 关键：清空 selectedImage 才能回到初始状态
        // showImagePicker = true // ⚠️ 删除这行：不要自动弹出 Picker
    }
    
    private func resetAnalysisState() {
        analysisResult = nil
        matchedCard = nil
        cashbackResults = [:]
        totalCashback = 0.0
    }
    
    private func startAnalysis() {
        Task {
            if !pdfImages.isEmpty {
                await analyzePDFPages()
            } else {
                await analyzeStatement()
            }
        }
    }
    
    private func updateTransaction(at index: Int, with transaction: StatementAnalysisResult.ParsedTransaction) {
        guard var result = analysisResult else { return }
        result.transactions[index] = transaction
        
        // Recalculate cashback if critical fields changed
        if let card = matchedCard {
            Task { await recalculateCashback(for: index, card: card, transaction: transaction) }
        }
        
        analysisResult = result
    }
    
    // ... [Rest of the logic methods: processPDF, analyzePDFPages, analyzeStatement, etc.] ...
    // To save space and focus on refactoring, I will reuse the existing logic methods but clean them up slightly.
    
    private func processPDF(url: URL) {
        Task {
            do {
                let images = try await PDFProcessor.convertPDFToImages(url: url)
                guard !images.isEmpty else {
                    await MainActor.run {
                        errorMessage = AppConstants.StatementAnalysis.pdfConversionFailed
                        showError = true
                    }
                    return
                }
                
                await MainActor.run {
                    pdfImages = images
                    totalPages = images.count
                    if let firstImage = images.first {
                        selectedImage = firstImage
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showPulseWarning = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = String(format: AppConstants.StatementAnalysis.pdfProcessingFailed, error.localizedDescription)
                    showError = true
                }
            }
        }
    }
    
    private func analyzePDFPages() async {
        guard !pdfImages.isEmpty else { return }
        
        await MainActor.run {
            isAnalyzing = true
            currentAnalyzingPage = 0
        }
        
        defer { Task { @MainActor in isAnalyzing = false } }
        
        var allTransactions: [StatementAnalysisResult.ParsedTransaction] = []
        var combinedRawText = ""
        var firstPageMetadata: (cardName: String, cardLastFour: String, statementDate: Date?) = ("", "", nil)
        for (index, image) in pdfImages.enumerated() {
            await MainActor.run { currentAnalyzingPage = index + 1 }
            
            do {
                let currentImage = image // Capture for closure
                let croppedImage = await Task.detached(priority: .userInitiated) {
                    return StatementImageProcessor.cropTransactionTable(from: currentImage)
                }.value
                
                let pageResult = try await analyzer.analyze(image: croppedImage)
                
                allTransactions.append(contentsOf: pageResult.transactions)
                
                if index == 0 {
                    firstPageMetadata.cardName = pageResult.cardName
                    firstPageMetadata.cardLastFour = pageResult.cardLastFour
                }
                
                // 2. 结单日期：优先取非空的
                // 如果当前还没找到，且本页找到了，就更新
                if firstPageMetadata.statementDate == nil {
                    firstPageMetadata.statementDate = pageResult.statementDate
                }
                
                // 3. 关键修改：将识别到的结单日传递给 analyzer 重新处理当前页的交易年份
                // 即使 pageResult.statementDate 为 nil，只要全局 firstPageMetadata.statementDate 有值，
                // 我们就应该尝试修正当前页交易的年份（因为有些页可能没结单日，但交易年份需要基于全局结单日推断）
                // 而如果当前页自己就有结单日，那 analyzer 内部其实已经处理好了（但为了保险，或者处理跨年边界，
                // 我们可以考虑是否需要二次处理。目前 analyzer.analyze 内部是基于传入的 image，
                // 它自己解析出 statementDate 后会用来推断年份。
                // 这里的痛点是：如果这一页识别出了交易，但没识别出结单日，导致年份推断可能出错（默认当前年）。
                // 所以我们应该：如果当前页没找到结单日，但之前页找到了，我们需要修正这一页交易的日期。
                
                if let validStatementDate = firstPageMetadata.statementDate {
                    // 修正当前页交易的年份
                    for i in (allTransactions.count - pageResult.transactions.count)..<allTransactions.count {
                        if allTransactions[i].postDate != nil {
                            allTransactions[i].postDate = StatementAnalyzer.fixDateYear(allTransactions[i].postDate!, referenceDate: validStatementDate)
                        }
                        if allTransactions[i].transDate != nil {
                            allTransactions[i].transDate = StatementAnalyzer.fixDateYear(allTransactions[i].transDate!, referenceDate: validStatementDate)
                        }
                    }
                }
                
                combinedRawText += "\n\n--- \(String(format: AppConstants.StatementAnalysis.pageNumber, index + 1)) ---\n\n\(pageResult.rawText)"
            } catch {
                print(String(format: AppConstants.StatementAnalysis.pageAnalysisFailed, index + 1, error.localizedDescription))
            }
        }
        
        let combinedResult = StatementAnalysisResult(
            cardName: firstPageMetadata.cardName,
            cardLastFour: firstPageMetadata.cardLastFour,
            statementDate: firstPageMetadata.statementDate,
            transactions: allTransactions,
            rawText: combinedRawText
        )
        
        await MainActor.run {
            analysisResult = combinedResult
            autoMatchCard(combinedResult)
        }
    }
    
    private func analyzeStatement() async {
        guard let image = selectedImage else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        do {
            let croppedImage = await Task.detached(priority: .userInitiated) {
                return StatementImageProcessor.cropTransactionTable(from: image)
            }.value
            
            let result = try await analyzer.analyze(image: croppedImage)
            
            await MainActor.run {
                analysisResult = result
                autoMatchCard(result)
            }
        } catch {
            await MainActor.run {
                errorMessage = String(format: AppConstants.StatementAnalysis.analysisFailed, error.localizedDescription)
                showError = true
            }
        }
    }
    
    private func autoMatchCard(_ result: StatementAnalysisResult) {
        guard !result.cardLastFour.isEmpty else { return }
        matchedCard = cards.first { $0.endNum == result.cardLastFour }
        if let card = matchedCard {
            Task { await calculateCashbackForTransactions(result: result, card: card) }
        }
    }
    
    private func calculateCashbackForTransactions(result: StatementAnalysisResult, card: CreditCard) async {
        await MainActor.run { isCalculatingCashback = true }
        
        var results: [Int: Double] = [:]
        var total: Double = 0.0
        
        for (index, transaction) in result.transactions.enumerated() {
            if transaction.isRefundOrPayment {
                results[index] = 0.0
                continue
            }
            
            let paymentMethod = TransactionHelpers.normalizePaymentMethod(transaction.paymentMethod ?? "SALE")
            let cashbackCurrency = transaction.cashbackCurrency
            let amount = abs(transaction.billingAmount)
            let date = transaction.transDate ?? transaction.postDate ?? Date()
            let calcResult = await CashbackService.calculateCashbackWithDetails(
                card: card,
                spendingAmount: amount,
                spendingCurrencyCode: cashbackCurrency,
                paymentMethod: paymentMethod,
                isOnlineShopping: false,
                isCBFApplied: false,
                category: Category.other,
                location: Region.hk,
                date: date,
                selectedConditionIndex: nil,
                transactionToExclude: nil,
                billingAmount: amount
            )
            
            results[index] = calcResult.finalCashback
            total += calcResult.finalCashback
        }
        
        await MainActor.run {
            cashbackResults = results
            totalCashback = total
            isCalculatingCashback = false
        }
    }
    
    private func recalculateCashback(for index: Int, card: CreditCard, transaction: StatementAnalysisResult.ParsedTransaction) async {
        if transaction.isRefundOrPayment {
            await MainActor.run {
                cashbackResults[index] = 0.0
                totalCashback = cashbackResults.values.reduce(0, +)
            }
            return
        }
        
        let paymentMethod = TransactionHelpers.normalizePaymentMethod(transaction.paymentMethod ?? "SALE")
        let cashbackCurrency = transaction.cashbackCurrency
        let billingAmount = abs(transaction.billingAmount)
        let date = transaction.transDate ?? transaction.postDate ?? Date()
        
        let calcResult = await CashbackService.calculateCashbackWithDetails(
            card: card,
            spendingAmount: billingAmount,
            spendingCurrencyCode: cashbackCurrency,
            paymentMethod: paymentMethod,
            isOnlineShopping: false,
            isCBFApplied: false,
            category: Category.other,
            location: Region.hk,
            date: date,
            selectedConditionIndex: nil,
            transactionToExclude: nil,
            billingAmount: billingAmount
        )
        
        await MainActor.run {
            cashbackResults[index] = calcResult.finalCashback
            totalCashback = cashbackResults.values.reduce(0, +)
        }
    }
    
    private func addNewTransaction(_ transaction: StatementAnalysisResult.ParsedTransaction) {
        guard var result = analysisResult else { return }
        result.transactions.append(transaction)
        analysisResult = result
        
        if let card = matchedCard {
            Task {
                await recalculateCashback(for: result.transactions.count - 1, card: card, transaction: transaction)
            }
        }
    }
    
    private func deleteTransaction(at index: Int) {
        guard var result = analysisResult, result.transactions.indices.contains(index) else { return }
        
        result.transactions.remove(at: index)
        analysisResult = result
        
        cashbackResults.removeValue(forKey: index)
        var newCashbackResults: [Int: Double] = [:]
        for (oldIndex, cashback) in cashbackResults {
            if oldIndex < index {
                newCashbackResults[oldIndex] = cashback
            } else if oldIndex > index {
                newCashbackResults[oldIndex - 1] = cashback
            }
        }
        cashbackResults = newCashbackResults
        totalCashback = cashbackResults.values.reduce(0, +)
    }
    
    private func importTransactions() {
        guard let result = analysisResult, let card = matchedCard else { return }
        
        var successCount = 0
        
        for (index, parsedTrans) in result.transactions.enumerated() {
            if parsedTrans.paymentMethod == "CBF" || parsedTrans.billingAmount == 0 { continue }
            
            let isCreditTransaction = parsedTrans.isRefundOrPayment
            let absAmount = abs(parsedTrans.billingAmount)
            let detectedPaymentMethod = TransactionHelpers.normalizePaymentMethod(parsedTrans.paymentMethod ?? "SALE")
            let calculatedCashback = cashbackResults[index] ?? 0.0
            let cbfFee = parsedTrans.cbfFee ?? 0.0
            let date = parsedTrans.transDate ?? parsedTrans.postDate ?? Date()
            let isCBFApplied = cbfFee > 0
            let spendingCurrency = parsedTrans.spendingCurrency ?? parsedTrans.billingCurrency
            let billingCurrency = parsedTrans.billingCurrency
            
            let transaction = Transaction(
                merchant: parsedTrans.description,
                category: Category.other,
                location: Region.hk,
                spendingAmount: absAmount,
                date: date,
                card: card,
                paymentMethod: detectedPaymentMethod,
                isOnlineShopping: true, // Default to true, can be edited later
                isCBFApplied: isCBFApplied,
                isCreditTransaction: isCreditTransaction,
                receiptData: nil,
                billingAmount: absAmount,
                cashbackAmount: calculatedCashback,
                cbfAmount: cbfFee,
                spendingCurrency: spendingCurrency,
                billingCurrency: billingCurrency
            )
            
            context.insert(transaction)
            successCount += 1
        }
        
        do {
            try context.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // 使用 withAnimation 包裹状态重置，让返回过程更平滑
                withAnimation(.easeInOut) {
                    // Reset to home state
                    selectedImage = nil
                    pdfImages = []
                    totalPages = 0
                    selectedPDFURL = nil
                    resetAnalysisState()
                }
            }
        } catch {
            errorMessage = String(format: AppConstants.General.importFailed, error.localizedDescription)
            showError = true
        }
    }
}

// MARK: - Subviews

// 移除了 StatementEditTransactionView，因为现在复用了 AddTransactionToStatementView

private struct StatementImageSelectionView: View {
    let onSelectImage: () -> Void
    let onSelectPDF: () -> Void
    
    var body: some View {
        ContentUnavailableView {
            Label(AppConstants.StatementAnalysis.monthlyStatementAnalysis, systemImage: "doc.text.image")
        } description: {
            Text(AppConstants.StatementAnalysis.selectImageOrPDF)
        } actions: {
            VStack(spacing: 16) {
                Button(action: onSelectImage) {
                    Label(AppConstants.StatementAnalysis.selectFromPhotoLibrary, systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
//                .buttonStyle(.borderedProminent)
                
                Button(action: onSelectPDF) {
                    Label(AppConstants.StatementAnalysis.selectPDFFile, systemImage: "doc.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
//                .buttonStyle(.bordered)
            }
//            .frame(maxWidth: 300)
            .padding(.horizontal)
        }
    }
}

private struct StatementImagePreviewView: View {
        let image: UIImage
        let pdfImages: [UIImage]
        let onSelectPage: (UIImage) -> Void
        let onReset: () -> Void
        let onChoosePDF: () -> Void
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .frame(maxWidth: .infinity) // 居中显示
                    
                    if !pdfImages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: AppConstants.StatementAnalysis.allPages, pdfImages.count))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(pdfImages.enumerated()), id: \.offset) { index, pageImage in
                                    PageThumbnail(
                                        image: pageImage,
                                        index: index,
                                        isSelected: pageImage == image,
                                        onTap: { onSelectPage(pageImage) }
                                    )
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                HStack(spacing: 12) {
                        Button(action: onReset) {
                            Label(AppConstants.StatementAnalysis.reselectImage, systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: onChoosePDF) {
                            Label(AppConstants.StatementAnalysis.reselectPDF, systemImage: "doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
            }
            .padding()
        }
    }
    
    private struct PageThumbnail: View {
        let image: UIImage
        let index: Int
        let isSelected: Bool
        let onTap: () -> Void
        
        var body: some View {
            VStack(spacing: 4) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 141)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
                
                Text(String(format: AppConstants.StatementAnalysis.pageNumber, index + 1))
                    .font(.caption2)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .onTapGesture(perform: onTap)
        }
    }
}

private struct StatementAnalysisControlView: View {
    let totalPages: Int
    let onStartAnalysis: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .symbolEffect(.bounce, value: totalPages)
                .foregroundColor(.blue)
            
            if totalPages > 0 {
                Text(String(format: AppConstants.StatementAnalysis.pdfLoaded, totalPages))
                    .font(.headline)
                Text(AppConstants.StatementAnalysis.clickToStartAnalysis)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text(AppConstants.StatementAnalysis.clickToStartStatementAnalysis)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onStartAnalysis) {
                Text(AppConstants.StatementAnalysis.startAnalysis)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

private struct StatementAnalyzingView: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.5)
            
            if totalPages > 0 {
                Text(String(format: AppConstants.StatementAnalysis.pageAnalysisProgress, currentPage, totalPages))
                    .font(.headline)
                    .foregroundColor(.secondary)
                ProgressView(value: Double(currentPage), total: Double(totalPages))
                    .padding(.horizontal, 40)
            } else {
                Text(AppConstants.StatementAnalysis.statementAnalysisProgress)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

private struct StatementResultView: View {
    let result: StatementAnalysisResult
    let matchedCard: CreditCard?
    let cashbackResults: [Int: Double]
    let totalCashback: Double
    let isCalculatingCashback: Bool
    let onSelectCard: () -> Void
    let onEditTransaction: (Int) -> Void
    let onDeleteTransaction: (Int) -> Void
    let onAddTransaction: () -> Void
    
    @AppStorage(AppConstants.Keys.showDebugOCRText) private var showDebugOCRText = false
    
    var body: some View {
        List {
            if showDebugOCRText {
                Section("OCR Raw Text") {
                    Text(result.rawText)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
            Section(AppConstants.Card.cardInfo) {
                if !result.cardName.isEmpty { LabeledContent(AppConstants.Card.cardName, value: result.cardName) }
                if !result.cardLastFour.isEmpty { LabeledContent(AppConstants.Card.cardLastFour, value: result.cardLastFour) }
                if let date = result.statementDate { LabeledContent(AppConstants.StatementAnalysis.statementDate, value: date.formatted(date: .long, time: .omitted)) }
                
                Button(action: onSelectCard) {
                    HStack {
                        Text(AppConstants.Card.matchCard).foregroundColor(.primary)
                        Spacer()
                        if let card = matchedCard {
                            Text("\(card.bankName) (\(card.endNum))").foregroundColor(.secondary)
                        } else {
                            Text(AppConstants.General.selectPlease).foregroundColor(.red)
                        }
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            
            if matchedCard != nil {
                CashbackSummarySection(
                    totalCashback: totalCashback,
                    count: result.transactions.count,
                    isLoading: isCalculatingCashback
                )
            }
            
            Section {
                ForEach(Array(result.transactions.enumerated()), id: \.offset) { index, transaction in
                    StatementTransactionRow(
                        transaction: transaction,
                        cashback: cashbackResults[index]
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button { onEditTransaction(index) } label: { Label(AppConstants.General.edit, systemImage: "pencil") }.tint(.blue)
                        Button(role: .destructive) { onDeleteTransaction(index) } label: { Label(AppConstants.General.delete, systemImage: "trash") }
                    }
                }
            } header: {
                HStack {
                    Text(AppConstants.Transaction.transactionRecords)
                    Spacer()
                    Text("\(result.transactions.count) 笔").font(.caption).foregroundColor(.secondary)
                    Button(action: onAddTransaction) {
                        Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CashbackSummarySection: View {
    let totalCashback: Double
    let count: Int
    let isLoading: Bool
    
    var body: some View {
        Section {
            if isLoading {
                HStack { ProgressView(); Text(AppConstants.Transaction.calculatingCashback).foregroundColor(.secondary) }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppConstants.Transaction.estimatedTotalCashback).font(.caption).foregroundColor(.secondary)
                            Text(String(format: "%.2f", totalCashback))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(AppConstants.Transaction.transactionCount).font(.caption).foregroundColor(.secondary)
                            Text("\(count)")
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                    Divider()
                    HStack {
                        Image(systemName: "info.circle").foregroundColor(.blue).font(.caption)
                        Text(AppConstants.Transaction.cashbackDisclaimer).font(.caption2).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        } header: { Text(AppConstants.Transaction.cashbackStats) }
    }
}

private struct StatementTransactionRow: View {
    let transaction: StatementAnalysisResult.ParsedTransaction
    let cashback: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(transaction.description).font(.subheadline).lineLimit(2)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f", transaction.billingAmount))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(transaction.billingAmount >= 0 ? .primary : .green)
                    
                    if let cbfFee = transaction.cbfFee {
                        Text("+ CBF \(String(format: "%.2f", cbfFee))").font(.caption2).foregroundColor(.orange)
                    }
                    
                    if let cb = cashback, cb > 0 {
                        Text("+\(String(format: "%.2f", cb))").font(.caption2).foregroundColor(.green)
                    }
                }
            }
            
            HStack(spacing: 12) {
                if let postDate = transaction.postDate {
                    Text(String(format: AppConstants.StatementAnalysis.postingDatePrefix, postDate.formatted(date: .abbreviated, time: .omitted))).font(.caption).foregroundColor(.secondary)
                }
                if let transDate = transaction.transDate {
                    Text(String(format: AppConstants.StatementAnalysis.transactionDatePrefix, transDate.formatted(date: .abbreviated, time: .omitted))).font(.caption).foregroundColor(.secondary)
                }
                
                if let paymentMethod = transaction.paymentMethod {
                    HStack(spacing: 4) {
                        Image(systemName: TransactionHelpers.paymentMethodIcon(for: paymentMethod))
                            .font(.system(size: 10)).frame(width: 12)
                        Text(paymentMethod).font(.caption2).fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(TransactionHelpers.paymentMethodColor(for: paymentMethod))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct StatementCardPickerView: View {
    let cards: [CreditCard]
    @Binding var selected: CreditCard?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(cards) { card in
                Button {
                    selected = card
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(card.bankName).font(.headline)
                            Text("**** \(card.endNum)").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if selected?.id == card.id {
                            Image(systemName: "checkmark").foregroundColor(.blue)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle(AppConstants.Card.selectCard)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(AppConstants.General.cancel) { dismiss() } }
            }
        }
    }
}

// 移除不再使用的 StatementEditTransactionView 结构体定义

