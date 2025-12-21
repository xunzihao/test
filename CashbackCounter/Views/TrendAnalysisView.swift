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

// MARK: - View

struct TrendAnalysisView: View {
    @Environment(\.dismiss) var dismiss
    
    // 外部传入的数据
    var transactions: [Transaction]
    var cards: [CreditCard]
    var exchangeRates: [String: Double]
    
    // 👇 核心：当前分析的类型 (由外部传入)
    let type: TrendType
    
    @State private var selectedCard: CreditCard? = nil
    
    // 缓存计算结果，避免每次视图刷新都重新计算
    @State private var cachedData: [MonthlyData] = []
    
    // ✨ iOS 17+: 图表交互选择
    @State private var rawSelectedDate: Date?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // --- 1. 图表区域 ---
                ChartView(
                    type: type,
                    selectedCard: selectedCard,
                    data: cachedData,
                    rawSelectedDate: $rawSelectedDate
                )
                
                // --- 2. 卡片选择列表 ---
                CardSelectionList(
                    cards: cards,
                    selectedCard: $selectedCard
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
            .task(id: selectedCard?.id) {
                await updateChartData()
            }
            .task(id: transactions.count) {
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
        // 在后台线程计算
        let result = await Task.detached(priority: .userInitiated) {
            let calendar = Calendar.current
            let now = Date()
            var data: [MonthlyData] = []
            
            for i in 0..<12 {
                if let date = calendar.date(byAdding: .month, value: -i, to: now) {
                    let components = calendar.dateComponents([.year, .month], from: date)
                    
                    // 筛选
                    let monthlyTransactions = transactions.filter { t in
                        let tComponents = calendar.dateComponents([.year, .month], from: t.date)
                        let isSameMonth = tComponents.year == components.year && tComponents.month == components.month
                        let isCardMatch = (selectedCard == nil) || (t.card?.id == selectedCard?.id)
                        return isSameMonth && isCardMatch
                    }
                    
                    // 计算总额 (根据类型区分逻辑)
                    let total = monthlyTransactions.reduce(0.0) { sum, t in
                        let amountToAdd: Double
                        // 👇 分支逻辑
                        if type == .expense {
                            amountToAdd = t.billingAmount // 支出算入账金额
                        } else {
                            amountToAdd = t.cashbackamount // 直接使用存储的返现金额
                        }
                        
                        // 汇率换算
                        let code = t.card?.issueRegion.currencyCode ?? "CNY"
                        let rate = exchangeRates[code] ?? 1.0
                        return sum + (amountToAdd / rate)
                    }
                    
                    data.append(MonthlyData(date: date, amount: total))
                }
            }
            return data.reversed() as [MonthlyData]
        }.value
        
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
    let selectedCard: CreditCard?
    let data: [MonthlyData]
    @Binding var rawSelectedDate: Date?
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedCard == nil ? String(format: AppConstants.Trend.totalTrend, type.title) : String(format: AppConstants.Trend.cardTrend, selectedCard!.bankName, type.title))
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 16)
            
            // 动态颜色
            VStack(alignment: .leading, spacing: 4) {
                if let selected = selectedDataPoint {
                    Text(selected.date.formatted(.dateTime.year().month()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", selected.amount))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(type.color)
                        .contentTransition(.numericText())
                } else {
                    Text(AppConstants.Trend.cumulative12Months)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", totalAmount))
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
                    // 线条
                    LineMark(
                        x: .value(AppConstants.Trend.monthLabel, item.date, unit: .month),
                        y: .value(AppConstants.Trend.amountLabel, item.amount)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(type.color)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .symbol {
                        Circle()
                            .fill(type.color)
                            .frame(width: 8, height: 8)
                            .shadow(radius: 2)
                    }
                    
                    // 渐变填充
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
                    
                    // ✨ iOS 17+: 选中指示器
                    if let selected = selectedDataPoint, selected.id == item.id {
                        RuleMark(x: .value("Selected", selected.date, unit: .month))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .foregroundStyle(.gray.opacity(0.5))
                            .annotation(position: .top) {
                                Circle()
                                    .stroke(type.color, lineWidth: 3)
                                    .fill(.white)
                                    .frame(width: 12, height: 12)
                            }
                    }
                }
                .chartScrollableAxes(.horizontal) // 支持横向滚动（如果数据点很多）
                .chartXVisibleDomain(length: 12) // 默认显示12个月
                // ✨ iOS 17+: 交互选择
                .chartXSelection(value: $rawSelectedDate)
                .frame(height: 260)
                .padding(.horizontal)
                .padding(.bottom, 16)
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
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// 2. 卡片选择列表
private struct CardSelectionList: View {
    let cards: [CreditCard]
    @Binding var selectedCard: CreditCard?
    
    var body: some View {
        List {
            // "全部卡片" 选项
            Button {
                withAnimation { selectedCard = nil }
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
                    if selectedCard == nil {
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
                        withAnimation { selectedCard = card }
                    } label: {
                        CardRowView(card: card, isSelected: selectedCard?.id == card.id)
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
