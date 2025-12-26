//
//  TrendAnalysisView.swift
//  CashbackCounter
//
//  Created by Assistant.
//

import SwiftUI
import Charts
import SwiftData

// MARK: - Models

// 1. 定义分析类型：支出 vs 返现
enum TrendType {
    case expense  // 支出
    case cashback // 返现
    
    var title: String {
        switch self {
        case .expense: return AppConstants.Trend.expense
        case .cashback: return AppConstants.Trend.cashback
        }
    }
    
    var color: Color {
        switch self {
        case .expense: return .red   // 支出用红色
        case .cashback: return .green // 返现用绿色
        }
    }
}

// 数据点结构
struct MonthlyData: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let amount: Double
}

// MARK: - Filter Model
enum TrendFilter: Identifiable, Hashable {
    case all
    case rewardCash
    case card(CreditCard)
    
    var id: String {
        switch self {
        case .all: return "all"
        case .rewardCash: return "rewardCash"
        case .card(let card): return String(describing: card.id)
        }
    }
    
    static func == (lhs: TrendFilter, rhs: TrendFilter) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all): return true
        case (.rewardCash, .rewardCash): return true
        case (.card(let c1), .card(let c2)): return c1.id == c2.id
        default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .all: hasher.combine(0)
        case .rewardCash: hasher.combine(1)
        case .card(let card):
            hasher.combine(2)
            hasher.combine(card.id)
        }
    }
}

// MARK: - View

struct TrendAnalysisView: View {
    @Environment(\.dismiss) var dismiss
    
    // 外部传入的数据
    var transactions: [Transaction]
    var cards: [CreditCard]
    var exchangeRates: [String: Double]
    
    // 👇 核心：当前分析的类型 (由外部传入)
    let type: TrendType
    
    @State private var selectedFilter: TrendFilter = .all
    
    // 缓存计算结果，避免每次视图刷新都重新计算
    @State private var cachedData: [MonthlyData] = []
    // 当前显示的币种符号
    @State private var displayCurrencySymbol: String = "CNY"
    
    // ✨ iOS 17+: 图表交互选择
    @State private var rawSelectedDate: Date?
    
    // ⚙️ 设置: 0 = 近12个月, 1 = 全部记录
    @AppStorage(AppConstants.Keys.trendDisplayMode) private var trendDisplayMode: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // --- 1. 图表区域 ---
                ChartView(
                    type: type,
                    selectedFilter: selectedFilter,
                    data: cachedData,
                    currencySymbol: displayCurrencySymbol,
                    rawSelectedDate: $rawSelectedDate,
                    trendDisplayMode: trendDisplayMode
                )
                
                // --- 2. 卡片选择列表 ---
                CardSelectionList(
                    cards: cards,
                    selectedFilter: $selectedFilter,
                    type: type
                )
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(type == .expense ? AppConstants.Trend.expenseAnalysis : AppConstants.Trend.cashbackAnalysis)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppConstants.General.close) { dismiss() }
                }
            }
            // 监听数据变化并更新图表
            .task(id: selectedFilter) {
                await updateChartData()
            }
            .task(id: transactions.count) {
                await updateChartData()
            }
            .task(id: exchangeRates) {
                await updateChartData()
            }
            .onAppear {
                Task { await updateChartData() }
            }
        }
    }
    
    // MARK: - Data Calculation
    
    @MainActor
    private func updateChartData() async {
        let calendar = Calendar.current
        let now = Date()
        var data: [MonthlyData] = []
        
        // --- 1. 准备数据 & 全局抵消计算 ---
        // 预先筛选出符合当前 Filter 的所有交易
        let relevantTransactions: [Transaction]
        switch selectedFilter {
        case .all:
            relevantTransactions = transactions
        case .rewardCash:
            relevantTransactions = transactions.filter { $0.card == nil }
        case .card(let card):
            relevantTransactions = transactions.filter { $0.card?.id == card.id }
        }
        
        // 全局计算智能抵消 (Offset)
        // 必须在全局范围内匹配，因为消费和退款可能不在同一个月
        // 这样可以确保 TrendAnalysisView 的总额与 BillHomeView (全选模式) 一致
        let refunds = relevantTransactions.filter { $0.isCreditTransaction }
        let expenses = relevantTransactions.filter { !$0.isCreditTransaction }
        var offsetTransactionIDs = Set<PersistentIdentifier>()
        var availableExpenses = expenses
        
        for refund in refunds {
            if let matchIndex = availableExpenses.firstIndex(where: { expense in
                let amountDiff = abs(abs(expense.billingAmount) - abs(refund.billingAmount))
                guard amountDiff < 1.0 else { return false }
                
                let expMerchant = expense.merchant.uppercased().replacingOccurrences(of: " ", with: "")
                let refMerchant = refund.merchant.uppercased().replacingOccurrences(of: " ", with: "")
                return expMerchant.contains(refMerchant) || refMerchant.contains(expMerchant)
            }) {
                let matchedExpense = availableExpenses[matchIndex]
                offsetTransactionIDs.insert(matchedExpense.persistentModelID)
                offsetTransactionIDs.insert(refund.persistentModelID)
                availableExpenses.remove(at: matchIndex)
            }
        }
        
        // --- 2. 确定显示币种 ---
        let targetCurrency: String
        let targetSymbol: String
        
        switch selectedFilter {
        case .card(let card):
            targetCurrency = card.issueRegion.currencyCode
            targetSymbol = card.issueRegion.currencySymbol
        case .all, .rewardCash:
            let involvedCurrencies = Set(relevantTransactions.compactMap { $0.card?.issueRegion.currencyCode ?? "CNY" })
            
            if involvedCurrencies.count == 1, let first = involvedCurrencies.first {
                 targetCurrency = first
                 if let tx = relevantTransactions.first(where: { $0.card?.issueRegion.currencyCode == first }), let card = tx.card {
                     targetSymbol = card.issueRegion.currencySymbol
                 } else {
                    if selectedFilter == .rewardCash && first == "CNY" {
                        targetSymbol = ""
                    } else {
                        targetSymbol = first == "CNY" ? "CN¥" : (first == "HKD" ? "HK$" : first)
                    }
                 }
             } else {
                 targetCurrency = "CNY"
                 targetSymbol = "CN¥"
             }
        }
        
        self.displayCurrencySymbol = targetSymbol
        
        // 确定时间范围
        let startDate: Date
        let monthCount: Int
        
        if trendDisplayMode == 1 { // 全部记录
            // 找到最早的交易日期
            let allRelevantDates = relevantTransactions.map { $0.date }
            if let earliest = allRelevantDates.min() {
                // 向前取整到月首
                let components = calendar.dateComponents([.year, .month], from: earliest)
                startDate = calendar.date(from: components) ?? calendar.date(byAdding: .month, value: -11, to: now)!
            } else {
                startDate = calendar.date(byAdding: .month, value: -11, to: now)!
            }
            
            // 计算从 startDate 到 now 的月数差
            let components = calendar.dateComponents([.month], from: startDate, to: now)
            monthCount = (components.month ?? 11) + 1
        } else { // 近12个月
            startDate = calendar.date(byAdding: .month, value: -11, to: now)!
            monthCount = 12
        }
        
        // 生成数据
        for i in 0..<monthCount {
            if let date = calendar.date(byAdding: .month, value: -(monthCount - 1 - i), to: now) {
                 let components = calendar.dateComponents([.year, .month], from: date)
                
                // 筛选
                var monthlyTransactions = relevantTransactions.filter { t in
                    let tComponents = calendar.dateComponents([.year, .month], from: t.date)
                    let isSameMonth = tComponents.year == components.year && tComponents.month == components.month
                    return isSameMonth
                }
                
                // 应用抵消：过滤掉被标记为抵消的交易
                monthlyTransactions = monthlyTransactions.filter { !offsetTransactionIDs.contains($0.persistentModelID) }
                
                // 应用类型过滤 (Expense vs Cashback)
                monthlyTransactions = monthlyTransactions.filter { t in
                    if type == .expense {
                        // 支出分析，排除所有信用交易 (除了 CBF)
                        return t.isCreditTransaction != true || t.paymentMethod == AppConstants.Transaction.cbf
                    } else {
                        // 返现分析，保留普通交易 + 纯返现交易
                        return t.isCreditTransaction == false || t.paymentMethod == AppConstants.Transaction.cashbackRebate
                    }
                }
                
                // 计算总额
                let total = monthlyTransactions.reduce(0.0) { sum, t in
                    let amountToAdd: Double
                    // 👇 分支逻辑
                    if type == .expense {
                        amountToAdd = abs(t.billingAmount) // 支出算入账金额 (取绝对值，兼容 CBF 可能为负的情况)
                    } else {
                        // 返现计算
                        if t.paymentMethod == AppConstants.Transaction.cashbackRebate {
                            // 纯返现交易：直接取入账金额（假设正数）
                            amountToAdd = abs(t.billingAmount)
                        } else {
                            // 普通交易：计算理论返现
                            amountToAdd = CashbackService.calculateCashback(for: t)
                        }
                    }
                    
                    // 汇率换算
                    // 目标: targetCurrency
                    // 来源: t.card?.issueRegion.currencyCode
                    let sourceCurrency = t.card?.issueRegion.currencyCode ?? "CNY"
                    
                    if sourceCurrency == targetCurrency {
                        return sum + amountToAdd
                    } else {
                        // 需要换算
                        // 1. 先换算成 CNY (base)
                        // rate: 1 Source = x CNY -> amount * rate = CNY
                        let rateToCNY = exchangeRates[sourceCurrency] ?? 1.0
                        let amountInCNY = amountToAdd * rateToCNY
                        
                        // 2. 再从 CNY 换算成 Target
                        // rate: 1 Target = y CNY
                        // Target = CNY / y
                        let rateTargetToCNY = exchangeRates[targetCurrency] ?? 1.0
                        let safeRate = rateTargetToCNY > 0 ? rateTargetToCNY : 1.0
                        
                        return sum + (amountInCNY / safeRate)
                    }
                }
                
                data.append(MonthlyData(date: date, amount: total))
            }
        }
        
        // data 已经是正序了 (Oldest ... Newest)
        let result = data 
        
        // 更新 UI
        withAnimation(.easeInOut) {
            self.cachedData = result
        }
    }
}

// MARK: - Subviews

// 1. 图表子视图
private struct ChartView: View {
    let type: TrendType
    let selectedFilter: TrendFilter
    let data: [MonthlyData]
    let currencySymbol: String
    @Binding var rawSelectedDate: Date?
    var trendDisplayMode: Int = 0 // Default to 0
    
    var totalAmount: Double {
        data.reduce(0) { $0 + $1.amount }
    }
    
    // 选中的数据点（根据手势位置计算）
    var selectedDataPoint: MonthlyData? {
        guard let rawSelectedDate else { return nil }
        return data.min(by: {
            abs($0.date.timeIntervalSince(rawSelectedDate)) < abs($1.date.timeIntervalSince(rawSelectedDate))
        })
    }
    
    var headerTitle: String {
        switch selectedFilter {
        case .all:
            return String(format: AppConstants.Trend.totalTrend, type.title)
        case .rewardCash:
            return String(format: AppConstants.Trend.cardTrend, "奖赏钱账户", type.title)
        case .card(let card):
            return String(format: AppConstants.Trend.cardTrend, card.bankName, type.title)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headerTitle)
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 16)
            
            // 动态颜色
            VStack(alignment: .leading, spacing: 4) {
                if let selected = selectedDataPoint {
                    Text(selected.date.formatted(.dateTime.year().month()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol)\(String(format: "%.2f", selected.amount))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(type.color)
                        .contentTransition(.numericText())
                } else {
                    Text(trendDisplayMode == 0 ? AppConstants.Trend.cumulative12Months : "累计总额")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol)\(String(format: "%.2f", totalAmount))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(type.color)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .animation(.snappy, value: selectedDataPoint)
            
            if data.isEmpty {
                ContentUnavailableView(AppConstants.Trend.noData, systemImage: "chart.xyaxis.line")
                    .frame(height: 260)
            } else {
                Chart(data) { item in
                    // 1. 渐变填充 (来自旧版代码)
                    AreaMark(
                        x: .value(AppConstants.Trend.monthLabel, item.date, unit: .month),
                        y: .value(AppConstants.Trend.amountLabel, item.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [type.color.opacity(0.3), type.color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    // 2. 线条
                    LineMark(
                        x: .value(AppConstants.Trend.monthLabel, item.date, unit: .month),
                        y: .value(AppConstants.Trend.amountLabel, item.amount)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(type.color)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    // 3. 数据点 (来自旧版代码，稍作调整)
                    PointMark(
                        x: .value(AppConstants.Trend.monthLabel, item.date, unit: .month),
                        y: .value(AppConstants.Trend.amountLabel, item.amount)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(40) // 稍微调小一点，旧版是60
                    .symbol {
                        Circle()
                            .fill(.white)
                            .stroke(type.color, lineWidth: 2)
                            .frame(width: 8, height: 8)
                    }
                    
                    // ✨ iOS 17+: 选中指示器
                    if let selected = selectedDataPoint, selected.id == item.id {
                        RuleMark(x: .value("Selected", selected.date, unit: .month))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .foregroundStyle(.gray.opacity(0.5))
                            .zIndex(-1) // 放在最底层
                    }
                }
                .chartScrollableAxes(trendDisplayMode == 1 ? .horizontal : [])
                .chartXVisibleDomain(length: trendDisplayMode == 1 ? 3600 * 24 * 365 : 0) // Show approx 12 months if scrollable
                // ✨ iOS 17+: 交互选择
                .chartXSelection(value: $rawSelectedDate)
                .frame(height: 260)
                .padding(.horizontal)
                .padding(.bottom, 16)
                // .drawingGroup() // ⚠️ 移除：可能导致渲染问题
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisValueLabel(format: .dateTime.month(), centered: true)
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                        .font(.system(size: 13))
                    }
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// 2. 卡片选择列表
private struct CardSelectionList: View {
    let cards: [CreditCard]
    @Binding var selectedFilter: TrendFilter
    let type: TrendType
    
    var body: some View {
        List {
            // "全部卡片" 选项
            Button {
                withAnimation { selectedFilter = .all }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppConstants.Trend.allCards)
                            .font(.headline)
                        Text(AppConstants.Trend.showAllTransactions)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if selectedFilter == .all {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Section(header: Text(AppConstants.Trend.selectCardToViewDetail)) {
                ForEach(cards) { card in
                    Button {
                        withAnimation { selectedFilter = .card(card) }
                    } label: {
                        CardRowView(card: card, isSelected: selectedFilter == .card(card))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 奖赏钱账户返现 (仅在返现分析时显示，或者用户要求都显示？用户说"返现分析页面里")
            // 用户说：返现分析页面里在最后加一个"奖赏钱账户返现“
            if type == .cashback {
                Section {
                    Button {
                        withAnimation { selectedFilter = .rewardCash }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("奖赏钱账户返现")
                                    .font(.headline)
                                Text("不属于任何卡片的返现")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedFilter == .rewardCash {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .fontWeight(.bold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// 3. 卡片行视图
private struct CardRowView: View {
    let card: CreditCard
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 卡片缩略图
            if let imageData = card.cardImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 32)
                    .overlay(
                        Image(systemName: "creditcard")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.bankName)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(card.cardOrganization.displayName)
                        .font(.caption)
                    Text("•")
                        .font(.caption)
                    Text(card.endNum)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .fontWeight(.bold)
            }
        }
        .contentShape(Rectangle())
    }
}
