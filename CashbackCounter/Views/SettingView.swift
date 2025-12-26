//
//  SettingsView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/29/25.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    // 获取 App 版本号
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    // 1. 外观设置 (0=跟随, 1=浅色, 2=深色)
    // ⚡️ 优化：使用 CashbackCounterApp 中定义的枚举，保持类型一致
    @AppStorage("userTheme") private var userTheme: AppTheme = .system
        
    // 2. 语言设置 "system" = 跟随系统, "zh-Hans" = 中文, "en" = 英文
    @AppStorage("userLanguage") private var userLanguage: String = "system"
    
    // 调试设置
    @AppStorage(AppConstants.Keys.showDebugOCRText) private var showDebugOCRText = false
    
    // 添加环境变量以访问 ModelContext
    @Environment(\.modelContext) var modelContext
    
    // 控制确认对话框
    @State private var showResetConfirmation = false
    
    // 控制修正结果弹窗
    @State private var showFixAlert = false
    @State private var fixRebateCount = 0
    @State private var fixOffsetCount = 0 // 🆕 新增抵消计数
    
    // 控制去重结果弹窗
    @State private var showDeduplicateAlert = false
    @State private var deduplicateCount = 0
    
    // 控制重算结果弹窗
    @State private var showRecalculateAlert = false
    @State private var recalculateCount = 0
    @State private var isRecalculating = false
    
    var body: some View {
        NavigationStack {
            List {
                // 1. App 头部
                AppHeaderSection(appVersion: appVersion)
                
                // 2. 外观与语言
                AppearanceSection(userTheme: $userTheme, userLanguage: $userLanguage)
                
                // 3. 常规设置
                GeneralSection(showDebugOCRText: $showDebugOCRText)
                
                // 3.5 趋势分析设置
                TrendSettingsSection()
                
                // 4. 数据管理
                DataManagementSection(
                    onFixRebate: { fixHistoryTransactions() },
                    onDeduplicate: { removeDuplicateTransactions() },
                    onRecalculate: { recalculateAllTransactions() },
                    isRecalculating: isRecalculating
                )
                
                // 5. 关于
                AboutSection(appVersion: appVersion)
                
                // 6. 危险操作
                DangerZoneSection(showResetConfirmation: $showResetConfirmation)
            }
            .navigationTitle(AppConstants.Settings.settings)
            .listStyle(.insetGrouped)
            // 重置数据确认弹窗
            .alert(AppConstants.Settings.resetDataConfirmation, isPresented: $showResetConfirmation) {
                Button(AppConstants.General.cancel, role: .cancel) { }
                Button(AppConstants.Settings.confirmReset, role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text(AppConstants.Settings.resetDataWarning)
            }
            // 修正结果弹窗
            .alert("操作完成", isPresented: $showFixAlert) {
                Button("好的", role: .cancel) { }
            } message: {
                Text("已修正 \(fixRebateCount) 笔返现交易，识别并处理 \(fixOffsetCount) 对抵消交易。")
            }
            // 去重结果弹窗
            .alert("去重完成", isPresented: $showDeduplicateAlert) {
                Button("好的", role: .cancel) { }
            } message: {
                Text("已合并并删除 \(deduplicateCount) 条重复交易。")
            }
            // 重算结果弹窗
            .alert("计算完成", isPresented: $showRecalculateAlert) {
                Button("好的", role: .cancel) { }
            } message: {
                Text("已重新计算 \(recalculateCount) 笔交易的返现和费用。")
            }
        }
    }
    
    // MARK: - Actions
    
    private func fixHistoryTransactions() {
        do {
            let descriptor = FetchDescriptor<Transaction>()
            let transactions = try modelContext.fetch(descriptor)
            
            // 1. 修正返现交易
            var rebateCount = 0
            let rebateKeywords = ["REBATE", "CASH REBATE", "回赠", "現金回贈", "回贈"]
            
            for transaction in transactions {
                let desc = transaction.merchant.uppercased()
                let isRebate = rebateKeywords.contains { keyword in
                    desc.contains(keyword)
                }
                
                // 如果是返现交易，且尚未标记正确
                if isRebate {
                    // 只要识别出是 rebate，就强制更新状态
                    // 1. 支付方式标记为 "返现"
                    // 2. isCreditTransaction = true (不计入支出)
                    // 3. 修复之前可能误将 cashbackamount 设为 0 的情况
                    
                    var hasChanges = false
                    
                    if transaction.paymentMethod != AppConstants.Transaction.cashbackRebate {
                        transaction.paymentMethod = AppConstants.Transaction.cashbackRebate
                        hasChanges = true
                    }
                    
                    if !transaction.isCreditTransaction {
                        transaction.isCreditTransaction = true
                        hasChanges = true
                    }
                    
                    // 恢复数据：对于返现交易，让 cashbackAmount = abs(billingAmount)
                    // 这样即使以后逻辑变了，数据也是自洽的
                    let expectedCashback = abs(transaction.billingAmount)
                    if abs(transaction.cashbackamount - expectedCashback) > 0.01 {
                        transaction.cashbackamount = expectedCashback
                        hasChanges = true
                    }
                    
                    if hasChanges {
                        rebateCount += 1
                    }
                }
            }
            
            // 2. 识别抵消交易 (Offset)
            // 逻辑与 BillHomeView/TrendAnalysisView 保持一致
            // 但这里我们要持久化这个状态吗？
            // 目前 Transaction 模型没有 offset 字段。
            // 用户需求是“检测抵消交易的逻辑”。如果只是检测并在 UI 上抵消，那是在 View 层做的。
            // 如果要在 Settings 里“修正”，意味着可能要删除它们？或者标记它们？
            // 用户之前的指令：“如果两笔交易...那么总支出/总返现那里就抵消掉这两笔交易” -> 这是展示逻辑。
            // 现在在 Settings 里加“修正历史交易”，可能意味着用户想把这些交易标记为不计入统计，或者直接删除？
            // 考虑到这是“数据管理”下的操作，且名为“修正”，通常意味着修改数据状态。
            // 我们可以：将这些抵消交易的 cashbackAmount 设为 0（如果它们之前有算返现），
            // 或者如果我们要彻底不显示，可能需要一个新的标记字段。
            // 但鉴于目前没有新字段，最安全的做法是：不做物理删除，也不改动现有核心数据，
            // 除非用户明确说要“删除抵消交易”。
            // 但回顾之前的需求：“金额相近，且一正一负...抵消掉”。
            // 在 Settings 里的这个功能，可能是为了弥补展示层的逻辑无法覆盖所有场景，或者用户希望把这些数据“清洗”一下。
            // 假设这里的需求是：扫描出这些抵消交易，并确保它们的状态是正确的（例如：不仅展示时抵消，实际上也不应该产生返现）。
            // 比如：一笔消费 100 (返现 1)，一笔退款 100 (返现 -1 或 0)。
            // 如果我们找到了这样的一对，我们可以把那笔消费的 cashbackAmount 置为 0。
            
            // 让我们实现一个逻辑：找到抵消对，将它们的 cashbackAmount 都置为 0，并且...
            // 其实 BillHomeView 的逻辑是动态计算的。
            // 这里我们暂时只做统计，或者如果用户希望，我们可以把它们标记为“已抵消”（如果有字段）。
            // 既然目前没有字段，我们先假设用户的意图是让这些交易不再产生返现影响。
            // 策略：找到抵消对 -> 将正向交易的 cashbackAmount 设为 0。
            
            var offsetCount = 0
            let refunds = transactions.filter { $0.isCreditTransaction }
            let expenses = transactions.filter { !$0.isCreditTransaction }
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
                    
                    // 找到抵消对！
                    // 修正动作：
                    // 1. 如果这笔消费之前计算了返现，现在应该归零，因为退款了。
                    if matchedExpense.cashbackamount > 0 {
                        matchedExpense.cashbackamount = 0.0
                    }
                    
                    // 2. 同时也不计入支出金额
                    // 我们将该笔消费标记为 isCreditTransaction = true
                    // 这样在 BillHomeView 和 TrendAnalysisView 的支出计算逻辑中（filter !isCreditTransaction），它就会被自动排除
                    if !matchedExpense.isCreditTransaction {
                        matchedExpense.isCreditTransaction = true
                        offsetCount += 1 // 计数：多少笔消费被修正了
                    }
                    
                    availableExpenses.remove(at: matchIndex)
                }
            }
            
            try modelContext.save()
            
            fixRebateCount = rebateCount
            fixOffsetCount = offsetCount
            showFixAlert = true
            
        } catch {
            print("Failed to fix transactions: \(error)")
        }
    }
    
    private func resetAllData() {
        do {
            try modelContext.delete(model: Transaction.self)
            try modelContext.delete(model: CreditCard.self)
            // 立即保存以触发 UI 更新
            // try modelContext.save() // SwiftData 默认自动保存，但显式调用更安全
        } catch {
            print("数据重置失败: \(error)")
        }
    }
    
    private func removeDuplicateTransactions() {
        do {
            let descriptor = FetchDescriptor<Transaction>()
            let transactions = try modelContext.fetch(descriptor)
            
            // 使用字典对交易进行分组
            // Key: 组合哈希值 (日期, 商户, 支付方式, 消费金额, 入账金额, 消费币种, 入账币种)
            // Value: 交易数组
            var groups: [Int: [Transaction]] = [:]
            
            for transaction in transactions {
                var hasher = Hasher()
                hasher.combine(transaction.date)
                hasher.combine(transaction.merchant)
                hasher.combine(transaction.paymentMethod)
                hasher.combine(transaction.spendingAmount)
                hasher.combine(transaction.billingAmount)
                hasher.combine(transaction.spendingCurrency)
                hasher.combine(transaction.billingCurrency)
                let hash = hasher.finalize()
                
                groups[hash, default: []].append(transaction)
            }
            
            var count = 0
            for (_, duplicates) in groups {
                if duplicates.count > 1 {
                    // 保留第一个，删除其余的
                    // 优先保留有收据图片的（如果有的话）
                    let sorted = duplicates.sorted { t1, t2 in
                        if (t1.receiptData != nil) != (t2.receiptData != nil) {
                            return t1.receiptData != nil
                        }
                        return false // 否则保持原序
                    }
                    
                    let toDelete = sorted.dropFirst()
                    for item in toDelete {
                        modelContext.delete(item)
                        count += 1
                    }
                }
            }
            
            try modelContext.save()
            deduplicateCount = count
            showDeduplicateAlert = true
            
        } catch {
            print("Failed to deduplicate: \(error)")
        }
    }
    
    private func recalculateAllTransactions() {
        isRecalculating = true
        
        Task { @MainActor in
            do {
                let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)])
                let transactions = try modelContext.fetch(descriptor)
                
                var count = 0
                
                for transaction in transactions {
                    guard let card = transaction.card else { continue }
                    
                    // 使用 CashbackService 重新计算
                    let result = await CashbackService.calculateCashbackWithDetails(
                        card: card,
                        spendingAmount: transaction.spendingAmount,
                        spendingCurrencyCode: transaction.spendingCurrency,
                        paymentMethod: transaction.paymentMethod,
                        isOnlineShopping: transaction.isOnlineShopping,
                        isCBFApplied: transaction.isCBFApplied,
                        category: transaction.category,
                        location: transaction.location,
                        date: transaction.date,
                        selectedConditionIndex: nil, // 自动匹配
                        transactionToExclude: transaction, // 排除自己以正确计算上限
                        billingAmount: transaction.billingAmount
                    )
                    
                    // 更新交易数据
                    transaction.cashbackamount = floor(result.finalCashback * 100) / 100
                    transaction.cbfAmount = floor(result.cbfAmount * 100) / 100
                    
                    count += 1
                }
                
                try modelContext.save()
                recalculateCount = count
                isRecalculating = false
                showRecalculateAlert = true
                
            } catch {
                print("Recalculation failed: \(error)")
                isRecalculating = false
            }
        }
    }
}

// MARK: - Subviews

// 1. App 头部区域
private struct AppHeaderSection: View {
    let appVersion: String
    
    var body: some View {
        Section {
            VStack(spacing: 8) {
                // 图标组合
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .offset(x: -5, y: 0)
                    
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                        .padding(4)
                        .background(Color(uiColor: .systemGroupedBackground).clipShape(Circle()))
                        .offset(x: 18, y: 12)
                }
                .padding(.bottom, 4)
                .accessibilityHidden(true)
                .symbolEffect(.bounce, value: true) // iOS 17 动画
                
                Text(AppConstants.General.appName)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("\(AppConstants.Settings.versionPrefix) \(appVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .listRowBackground(Color.clear)
    }
}

// 2. 外观与语言设置
private struct AppearanceSection: View {
    @Binding var userTheme: AppTheme
    @Binding var userLanguage: String
    
    var body: some View {
        Section(header: Text(AppConstants.Settings.appearanceAndLanguage)) {
            Picker(selection: $userTheme, label: Label(AppConstants.Settings.theme, systemImage: "paintpalette")) {
                Text(AppConstants.Settings.followSystem).tag(AppTheme.system)
                Text(AppConstants.Settings.lightMode).tag(AppTheme.light)
                Text(AppConstants.Settings.darkMode).tag(AppTheme.dark)
            }
            
            Picker(selection: $userLanguage, label: Label(AppConstants.Settings.language, systemImage: "globe")) {
                Text(AppConstants.Settings.followSystem).tag("system")
                Text(AppConstants.Settings.zhHans).tag("zh-Hans")
                Text(AppConstants.Settings.zhHant).tag("zh-Hant")
                Text(AppConstants.Settings.english).tag("en")
            }
        }
    }
}

// 3. 常规设置
private struct GeneralSection: View {
    @Binding var showDebugOCRText: Bool
    
    var body: some View {
        Section(header: Text(AppConstants.Settings.general)) {
            NavigationLink(destination: Text(AppConstants.Settings.multiCurrencySupport)) {
                Label(AppConstants.Settings.multiCurrencySettings, systemImage: "banknote")
            }
            
            NavigationLink(destination: NotificationSettingsView()) {
                Label(AppConstants.Settings.notifications, systemImage: "bell")
            }
            
            Toggle(isOn: $showDebugOCRText) {
                Label("显示 OCR 原始文本 (调试)", systemImage: "text.viewfinder")
            }
        }
    }
}

// 3.5 趋势分析设置
private struct TrendSettingsSection: View {
    @AppStorage(AppConstants.Keys.trendDisplayMode) private var trendDisplayMode: Int = 0
    
    var body: some View {
        Section(header: Text(AppConstants.Settings.trendAnalysisSettings)) {
            Picker(AppConstants.Settings.trendDisplayMode, selection: $trendDisplayMode) {
                Text(AppConstants.Settings.last12Months).tag(0)
                Text(AppConstants.Settings.allTime).tag(1)
            }
        }
    }
}

// 4. 数据管理
private struct DataManagementSection: View {
    var onFixRebate: () -> Void
    var onDeduplicate: () -> Void
    var onRecalculate: () -> Void
    var isRecalculating: Bool
    
    var body: some View {
        Section(header: Text(AppConstants.Settings.dataManagement)) {
            Label(AppConstants.Settings.iCloudSync, systemImage: "icloud")
                .foregroundColor(.secondary)
            
            Button(action: onFixRebate) {
                Label("修正历史返现交易", systemImage: "arrow.triangle.2.circlepath.doc.on.clipboard")
            }
            
            Button(action: onDeduplicate) {
                Label("合并重复交易", systemImage: "square.on.square")
            }
            
            Button(action: onRecalculate) {
                if isRecalculating {
                    HStack {
                        Label("重新计算所有返现", systemImage: "arrow.clockwise")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Label("重新计算所有返现", systemImage: "arrow.clockwise")
                }
            }
            .disabled(isRecalculating)
            
            HStack {
                Label(AppConstants.Settings.dataImportExport, systemImage: "square.and.arrow.up")
                Spacer()
                Text(AppConstants.Home.seeHomeTopRight)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// 5. 关于
private struct AboutSection: View {
    let appVersion: String
    
    var body: some View {
        Section(header: Text(AppConstants.Settings.aboutApp)) {
            HStack {
                Label(AppConstants.Settings.version, systemImage: "info.circle")
                Spacer()
                Text("v\(appVersion)")
                    .foregroundColor(.secondary)
            }
            
            Label(AppConstants.Settings.developer, systemImage: "person.crop.circle")
            
            Link(destination: URL(string: "https://github.com/raytracingon/cashbackcounter")!) {
                Label(AppConstants.Settings.projectHomepage, systemImage: "link")
            }
        }
    }
}

// 6. 危险区域
private struct DangerZoneSection: View {
    @Binding var showResetConfirmation: Bool
    
    var body: some View {
        Section {
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label(AppConstants.Settings.resetAllData, systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
}
