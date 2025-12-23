//
//  BillHomeView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BillHomeView: View {
    @Environment(\.modelContext) var context
    
    // MARK: - Data Query
    @Query(sort: [SortDescriptor(\Transaction.date, order: .reverse),
                  SortDescriptor(\Transaction.merchant, order: .forward)])
    var dbTransactions: [Transaction]
    
    @Query var cards: [CreditCard]
    
    // MARK: - State
    // UI State
    @State private var selectedTransaction: Transaction?
    @State private var transactionToEdit: Transaction?
    @State private var showDatePicker = false
    @State private var showCardPicker = false
    @State private var showTrendSheet = false
    @State private var showExpenseSheet = false
    @State private var showAddCashbackSheet = false
    @State private var showSearchSheet = false
    
    // Filter State
    @State private var selectedDate = Date()
    @State private var showAll = false
    @State private var selectedCard: CreditCard?
    @State private var isWholeYear = false
    
    // Import State
    @State private var showFileImporter = false
    @State private var showImportAlert = false
    @State private var importMessage = ""
    
    // Rate State
    @State private var exchangeRates: [String: Double] = [:]
    @State private var isLoadingRates = false
    @State private var rateError: String?
    
    // MARK: - Computed Properties
    
    var filteredTransactions: [Transaction] {
        var result = dbTransactions
        
        // 1. 卡片筛选
        if let card = selectedCard {
            result = result.filter { $0.card?.id == card.id }
        }
        
        // 2. 时间筛选
        if !showAll {
            let calendar = Calendar.current
            let granularity: Calendar.Component = isWholeYear ? .year : .month
            result = result.filter { calendar.isDate($0.date, equalTo: selectedDate, toGranularity: granularity) }
        }
        
        return result
    }
    
    var expenseDisplayStrings: [String] {
        calculateTotal(for: .expense)
    }
    
    var cashbackDisplayStrings: [String] {
        calculateTotal(for: .cashback)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. 统计头部
                        StatsHeader(
                            showAll: showAll,
                            isWholeYear: isWholeYear,
                            expenseStrings: expenseDisplayStrings,
                            cashbackStrings: cashbackDisplayStrings,
                            onExpenseTap: { showExpenseSheet = true },
                            onCashbackTap: { showTrendSheet = true }
                        )
                        
                        // 2. 汇率状态提示
                        if isLoadingRates {
                            ProgressView(AppConstants.Home.updatingRates)
                                .controlSize(.small)
                        } else if let error = rateError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        
                        // 3. 筛选控制栏
                        FilterControlBar(
                            selectedCard: selectedCard,
                            showAll: showAll,
                            isWholeYear: isWholeYear,
                            selectedDate: selectedDate,
                            onCardTap: { showCardPicker = true },
                            onAllTap: { withAnimation { showAll = true } },
                            onDateTap: { showDatePicker = true }
                        )
                        
                        // 4. 分析入口 (已移动到底部导航栏)
                        // AnalysisButton was here
                        
                        // 5. 交易列表 或 空状态
                        if filteredTransactions.isEmpty {
                            ContentUnavailableView(
                                AppConstants.Transaction.noTransactions,
                                systemImage: "list.bullet.clipboard",
                                description: Text(AppConstants.Transaction.noTransactionsDescription)
                            )
                            .padding(.top, 40)
                        } else {
                            TransactionListView(
                                transactions: filteredTransactions,
                                onSelect: { selectedTransaction = $0 },
                                onEdit: { transactionToEdit = $0 },
                                onDelete: { context.delete($0) }
                            )
                        }
                    }
                    .padding(.bottom, 20)
                }
                .refreshable { await refreshRates() }
            }
            .navigationTitle(AppConstants.General.appName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAddCashbackSheet = true
                    } label: {
                        Label("添加返现", systemImage: "plus.circle")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ShareLink(item: TransactionCSV(transactions: filteredTransactions), preview: SharePreview(AppConstants.Home.exportBill)) {
                            Label(AppConstants.Home.exportBill, systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            showSearchSheet = true
                        } label: {
                            Label("搜索交易", systemImage: "magnifyingglass")
                        }
                        
                        Divider()
                        
                        Button {
                            showFileImporter = true
                        } label: {
                            Label(AppConstants.Home.importCSV, systemImage: "square.and.arrow.down")
                        }
                        
                        Button(action: { Task { await refreshRates() } }) {
                            Label(AppConstants.Home.refreshRates, systemImage: "arrow.clockwise")
                        }
                        .disabled(isLoadingRates)
                        
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            // MARK: - Sheets
            .sheet(item: $selectedTransaction) { item in
                TransactionDetailView(transaction: item).presentationDetents([.large])
            }
            .sheet(item: $transactionToEdit) { item in
                AddTransactionView(transaction: item)
            }
            .sheet(isPresented: $showDatePicker) {
                MonthYearPicker(date: $selectedDate, isWholeYear: $isWholeYear)
                    .presentationDetents([.height(300)])
                    .onDisappear { withAnimation { showAll = false } }
            }
            .sheet(isPresented: $showCardPicker) {
                CardPickerView(selectedCard: $selectedCard, cards: cards)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showTrendSheet) {
                TrendAnalysisView(transactions: dbTransactions, cards: cards, exchangeRates: exchangeRates, type: .cashback)
            }
            .sheet(isPresented: $showExpenseSheet) {
                TrendAnalysisView(transactions: dbTransactions, cards: cards, exchangeRates: exchangeRates, type: .expense)
            }
            .sheet(isPresented: $showAddCashbackSheet) {
                AddCashbackView()
            }
            .sheet(isPresented: $showSearchSheet) {
                SearchTransactionView()
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                handleImport(result)
            }
            .alert(AppConstants.General.importResult, isPresented: $showImportAlert) {
                Button(AppConstants.General.confirm, role: .cancel) { }
            } message: {
                Text(importMessage)
            }
            .task { await refreshRates() }
        }
    }
    
    // MARK: - Logic Helpers
    
    private enum CalculationType {
        case expense
        case cashback
    }
    
    private func calculateTotal(for type: CalculationType) -> [String] {
        var validTxs = filteredTransactions
        
        // --- 核心逻辑：智能抵消 (Offset) ---
        // 1. 找出所有退款/信用交易 (refunds) 和 普通消费 (expenses)
        let refunds = validTxs.filter { $0.isCreditTransaction }
        let expenses = validTxs.filter { !$0.isCreditTransaction }
        
        // 2. 建立需要被抵消的交易 ID 集合
        var offsetTransactionIDs = Set<PersistentIdentifier>()
        
        // 3. 遍历退款，寻找匹配的消费
        // 为了避免重复匹配，我们需要一个临时的 expenses 池
        var availableExpenses = expenses
        
        for refund in refunds {
            // 匹配条件：
            // a. 商户名相似（这里简单用包含或前缀匹配，忽略大小写）
            // b. 金额相近（允许 1.0 的误差）
            // c. 尚未被匹配
            
            if let matchIndex = availableExpenses.firstIndex(where: { expense in
                // 1. 金额匹配：退款金额通常是负数（在 TransactionRow 里显示时），但在 billingAmount 存储时可能是一样的正数或者负数
                // 假设 billingAmount 对于消费是正数，对于退款可能是负数，或者也是正数但 isCreditTransaction=true
                // 无论如何，我们要比较的是绝对值
                let amountDiff = abs(abs(expense.billingAmount) - abs(refund.billingAmount))
                guard amountDiff < 1.0 else { return false } // 允许 1.0 的误差
                
                // 2. 商户名匹配
                // 简单规则：归一化后，是否互相包含，或者 Levenshtein 距离很小
                // 这里用简单的包含检查，通常退款单的商户名会包含消费单的关键字
                let expMerchant = expense.merchant.uppercased().replacingOccurrences(of: " ", with: "")
                let refMerchant = refund.merchant.uppercased().replacingOccurrences(of: " ", with: "")
                
                // 如果长度差异太大，可能不是同一个
                return expMerchant.contains(refMerchant) || refMerchant.contains(expMerchant)
            }) {
                // 找到匹配！
                let matchedExpense = availableExpenses[matchIndex]
                
                // 标记这对交易为“已抵消”
                offsetTransactionIDs.insert(matchedExpense.persistentModelID)
                offsetTransactionIDs.insert(refund.persistentModelID)
                
                // 从可用池中移除，避免被再次匹配
                availableExpenses.remove(at: matchIndex)
            }
        }
        
        // 4. 过滤掉已抵消的交易
        validTxs = validTxs.filter { !offsetTransactionIDs.contains($0.persistentModelID) }
        
        // --- 原有逻辑继续 ---
        
        validTxs = validTxs.filter { 
            // 支出计算：排除所有信用交易 (isCreditTransaction=true)
            // 返现计算：排除信用交易，但必须包含 "返现" 类型的交易
            // CBF 费用：它被标记为 cbf，且 isCreditTransaction = true（因为是负向费用？）
            // 让我们确认 CBF 的属性：paymentMethod = "CBF", isCreditTransaction = ? 
            // 通常 CBF 是额外的费用，应该是正数入账，或者负数？
            // 如果 CBF 是费用，它应该算在支出里。
            
            if type == .expense {
                // 支出包括：
                // 1. 普通消费 (isCreditTransaction = false)
                // 2. CBF 费用 (paymentMethod = "CBF")，即使它可能被错误标记为 credit，或者我们需要明确包含它
                // 根据之前的逻辑，CBF 被归类为 isRefundOrRepayment -> isCreditTransaction = true?
                // 如果是这样，我们需要特例放行 CBF
                return $0.isCreditTransaction != true || $0.paymentMethod == AppConstants.Transaction.cbf
            } else {
                // 如果是返现统计，我们既要包含普通交易产生的计算返现，也要包含直接的“返现”交易
                // 普通交易：isCreditTransaction == false
                // 返现交易：paymentMethod == "返现" (即使 isCreditTransaction == true)
                return $0.isCreditTransaction == false || $0.paymentMethod == AppConstants.Transaction.cashbackRebate
            }
        }
        guard !validTxs.isEmpty else { return ["0"] }
        
        if let card = selectedCard {
            let symbol = card.issueRegion.currencySymbol
            let total = validTxs.reduce(0.0) { acc, t in
                if type == .expense {
                    // 支出累加
                    // 如果是 CBF，取绝对值加入支出（假设它是正向成本）
                    // 普通消费也是取 billingAmount
                    return acc + abs(t.billingAmount)
                } else {
                    // 如果是直接的返现交易，累加其入账金额（billingAmount，通常为正数表示获得的返现）
                    if t.paymentMethod == AppConstants.Transaction.cashbackRebate {
                        // 注意：入账金额在 Transaction 中通常是正数。
                        // 如果在数据库中返现是负数（表示抵扣），这里需要取绝对值或者直接加
                        // 假设：返现交易的 billingAmount 记录的是获得的金额（正数）
                        return acc + abs(t.billingAmount)
                    } else {
                        // 普通交易计算理论返现
                        return acc + CashbackService.calculateCashback(for: t)
                    }
                }
            }
            return ["\(symbol)\(String(format: "%.2f", total))"]
        } else {
            var cnyTotal = 0.0
            var hkdTotal = 0.0
            
            for t in validTxs {
                let code = t.card?.issueRegion.currencyCode ?? "CNY"
                var amt = 0.0
                
                if type == .expense {
                    amt = abs(t.billingAmount)
                } else {
                    if t.paymentMethod == AppConstants.Transaction.cashbackRebate {
                        amt = abs(t.billingAmount)
                    } else {
                        amt = CashbackService.calculateCashback(for: t)
                    }
                }
                
                if code == "CNY" { cnyTotal += amt }
                else if code == "HKD" { hkdTotal += amt }
            }
            
            var result: [String] = []
            if cnyTotal > 0.01 { result.append("CN¥\(String(format: "%.2f", cnyTotal))") }
            if hkdTotal > 0.01 { result.append("HK$\(String(format: "%.2f", hkdTotal))") }
            return result.isEmpty ? ["0"] : result
        }
    }
    
    private func refreshRates() async {
        await MainActor.run {
            isLoadingRates = true
            rateError = nil
        }
        let rates = await CurrencyService.getRates(base: "CNY")
        await MainActor.run {
            exchangeRates = rates.isEmpty ? ["CNY": 1.0] : rates
            if rates.isEmpty {
                rateError = AppConstants.Home.rateUpdateFailed
            }
            isLoadingRates = false
        }
    }
    
    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                try CSVService.Transactions.parse(content: content, context: context, allCards: cards)
                importMessage = AppConstants.General.importSuccess
                showImportAlert = true
            } catch {
                importMessage = String(format: AppConstants.General.importFailed, error.localizedDescription)
                showImportAlert = true
            }
        case .failure(let error):
            print("选择文件失败: \(error)")
        }
    }
}

// MARK: - Subviews

private struct StatsHeader: View {
    let showAll: Bool
    let isWholeYear: Bool
    let expenseStrings: [String]
    let cashbackStrings: [String]
    let onExpenseTap: () -> Void
    let onCashbackTap: () -> Void
    
    var titlePrefix: String {
        showAll ? AppConstants.Home.totalPrefix : (isWholeYear ? AppConstants.Home.thisYearPrefix : AppConstants.Home.thisMonthPrefix)
    }
    
    var body: some View {
        HStack(spacing: 15) {
            StatsButton(
                title: "\(titlePrefix)\(AppConstants.Trend.expense)",
                amount: expenseStrings.joined(separator: "\n"),
                icon: "arrow.down.circle.fill",
                color: .red,
                action: onExpenseTap
            )
            
            StatsButton(
                title: "\(titlePrefix)\(AppConstants.Trend.cashback)",
                amount: cashbackStrings.joined(separator: "\n"),
                icon: "arrow.up.circle.fill",
                color: .green,
                action: onCashbackTap
            )
        }
        .padding(.horizontal).padding(.top)
    }
}

private struct StatsButton: View {
    let title: String
    let amount: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            StatBox(title: title, amount: amount, icon: icon, color: color)
                .overlay(
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.trailing, 10),
                    alignment: .trailing
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FilterControlBar: View {
    let selectedCard: CreditCard?
    let showAll: Bool
    let isWholeYear: Bool
    let selectedDate: Date
    let onCardTap: () -> Void
    let onAllTap: () -> Void
    let onDateTap: () -> Void
    
    var cardButtonText: String {
        selectedCard.map { "\($0.bankName) (\($0.endNum))" } ?? AppConstants.Trend.allCards
    }
    
    var dateButtonText: String {
        isWholeYear ? selectedDate.formatted(.dateTime.year()) + " \(AppConstants.DateConstants.wholeYear)" : selectedDate.formatted(.dateTime.year().month())
    }
    
    var body: some View {
        VStack(spacing: 12) {
            FilterRow(title: AppConstants.Home.cardFilter) {
                FilterButton(
                    icon: "creditcard",
                    text: cardButtonText,
                    isActive: selectedCard != nil,
                    action: onCardTap
                )
            }
            
            FilterRow(title: showAll ? AppConstants.Home.allBills : (isWholeYear ? AppConstants.Home.yearlyBills : AppConstants.Home.monthlyBills)) {
                HStack(spacing: 10) {
                    FilterButton(text: AppConstants.General.all, isActive: showAll, action: onAllTap)
                    FilterButton(icon: "calendar", text: dateButtonText, isActive: !showAll, action: onDateTap)
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct FilterRow<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            content
        }
    }
}

private struct FilterButton: View {
    var icon: String?
    let text: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon) }
                Text(text)
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.blue : Color.clear)
            .foregroundStyle(isActive ? .white : .blue)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.blue, lineWidth: 1))
        }
    }
}

private struct TransactionListView: View {
    let transactions: [Transaction]
    let onSelect: (Transaction) -> Void
    let onEdit: (Transaction) -> Void
    let onDelete: (Transaction) -> Void
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(transactions) { item in
                TransactionRow(transaction: item)
                    .onTapGesture { onSelect(item) }
                    .contextMenu {
                        Button { onEdit(item) } label: { Label(AppConstants.General.edit, systemImage: "pencil") }
                        Button(role: .destructive) { onDelete(item) } label: { Label(AppConstants.General.delete, systemImage: "trash") }
                    }
                    // ✨ iOS 17+: 滚动过渡动画
                    .scrollTransition(.animated.threshold(.visible(0.9))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.6)
                            .scaleEffect(phase.isIdentity ? 1 : 0.95)
                            .blur(radius: phase.isIdentity ? 0 : 1)
                    }
            }
        }
        .padding(.horizontal)
    }
}

private struct CardPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCard: CreditCard?
    let cards: [CreditCard]
    
    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedCard = nil
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(AppConstants.Trend.allCards).font(.headline)
                            Text(AppConstants.Trend.showAllTransactions).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedCard == nil {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Section(AppConstants.Card.selectCard) {
                    ForEach(cards) { card in
                        Button {
                            selectedCard = card
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                CardThumbnail(data: card.cardImageData)
                                
                                VStack(alignment: .leading) {
                                    Text(card.bankName).font(.headline)
                                    Text("\(card.cardOrganization.displayName) • \(card.endNum)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedCard?.id == card.id {
                                    Image(systemName: "checkmark").foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(AppConstants.Home.filterCards)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppConstants.General.cancel) { dismiss() }
                }
            }
        }
    }
}

private struct CardThumbnail: View {
    let data: Data?
    
    var body: some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.2)
                    .overlay(Image(systemName: "creditcard").foregroundStyle(.gray))
            }
        }
        .frame(width: 50, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
