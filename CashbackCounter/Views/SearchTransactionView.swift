
import SwiftUI
import SwiftData

struct SearchTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    
    @Query(sort: [SortDescriptor(\Transaction.date, order: .reverse)])
    var transactions: [Transaction]
    
    @State private var searchText = ""
    @State private var selectedFilter: String = "全部"
    @State private var selectedTransaction: Transaction?
    
    // 动态获取筛选选项
    var filterOptions: [String] {
        var options = ["全部"]
        options.append(contentsOf: AppConstants.OCR.PaymentDetection.candidates)
        return options
    }
    
    var filteredTransactions: [Transaction] {
        var result = transactions
        
        // 1. Text Search
        if !searchText.isEmpty {
            result = result.filter { $0.merchant.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 2. Category Filter
        if selectedFilter != "全部" {
            result = result.filter { transaction in
                // 主要匹配 paymentMethod
                if transaction.paymentMethod == selectedFilter {
                    return true
                }
                
                // 兼容性匹配：如果没有 paymentMethod，尝试从描述中模糊匹配
                // 仅针对特定几个旧类型保留模糊匹配，新类型依赖 paymentMethod
                if transaction.paymentMethod.isEmpty {
                    if selectedFilter == "退款" {
                        return transaction.merchant.localizedCaseInsensitiveContains("退款") ||
                               transaction.merchant.localizedCaseInsensitiveContains("REFUND")
                    }
                    if selectedFilter == "还款" {
                        return transaction.merchant.localizedCaseInsensitiveContains("还款") ||
                               transaction.merchant.localizedCaseInsensitiveContains("PAYMENT")
                    }
                    if selectedFilter == "SALE" {
                        return transaction.merchant.localizedCaseInsensitiveContains("SALE")
                    }
                }
                
                return false
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filterOptions, id: \.self) { filter in
                            FilterChip(title: filter, isSelected: selectedFilter == filter) {
                                withAnimation {
                                    selectedFilter = filter
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .frame(height: 60) // 强制指定高度，防止被压缩
                .background(Color(uiColor: .systemBackground))
                
                Divider() // 添加分割线，区分筛选区和列表
                
                if filteredTransactions.isEmpty {
                    ContentUnavailableView("无相关交易", systemImage: "magnifyingglass")
                        .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredTransactions) { transaction in
                            TransactionRow(transaction: transaction)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedTransaction = transaction
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .navigationTitle("搜索交易")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索商户名称")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedTransaction) { item in
                TransactionDetailView(transaction: item)
                    .presentationDetents([.large])
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Text(title)
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(uiColor: .systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .contentShape(Rectangle()) // 扩大点击区域
            .onTapGesture(perform: action)
    }
}
