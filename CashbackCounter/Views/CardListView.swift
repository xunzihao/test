//
//  CardListView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Enums & Keys

enum SheetType: Identifiable {
    case template
    case custom
    var id: Int { hashValue }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Main View

struct CardListView: View {
    @Query var cards: [CreditCard]
    @Environment(\.modelContext) var context
    
    // UI State
    @State private var cardToEdit: CreditCard?
    @State private var activeSheet: SheetType?
    @State private var selectedCardID: PersistentIdentifier? = nil
    @State private var scrollOffset: CGFloat = 0
    
    // Import/Export State
    @State private var showFileImporter = false
    @State private var showImportAlert = false
    @State private var importError: String?
    
    // Computed Props
    private var isDetailMode: Bool { selectedCardID != nil }
    private var currentSelectedCard: CreditCard? {
        guard let id = selectedCardID else { return nil }
        return cards.first(where: { $0.id == id })
    }
    
    private let springAnimation = Animation.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                // Layer 1: Detail View (Bottom)
                if let card = currentSelectedCard {
                    CardDetailLayer(card: card) {
                        // 点击详情页顶部的卡片区域也可以关闭详情
                        withAnimation(springAnimation) {
                            selectedCardID = nil
                        }
                    }
                }
                
                // Layer 2: Card Stack (Top)
                CardStackLayer(
                    cards: cards,
                    selectedCardID: $selectedCardID,
                    scrollOffset: $scrollOffset,
                    isDetailMode: isDetailMode,
                    springAnimation: springAnimation
                )
                .zIndex(1)
                
                // Layer 3: Tap Area to Close
                if isDetailMode {
                    CloseTapArea {
                        withAnimation(springAnimation) {
                            selectedCardID = nil
                        }
                    }
                }
            }
            .navigationTitle(currentSelectedCard?.bankName ?? AppConstants.Card.myWallet)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    CardListToolbar(
                        cards: cards,
                        selectedCard: currentSelectedCard,
                        cardToEdit: $cardToEdit,
                        activeSheet: $activeSheet,
                        showFileImporter: $showFileImporter,
                        deleteAction: deleteSelectedCard
                    )
                }
            }
            .sheet(item: $activeSheet) { type in
                switch type {
                case .template: CardTemplateListView(rootSheet: $activeSheet)
                case .custom: AddCardView()
                }
            }
            .sheet(item: $cardToEdit) { card in
                AddCardView(cardToEdit: card)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert(AppConstants.General.importResult, isPresented: $showImportAlert) {
                Button(AppConstants.General.confirm, role: .cancel) { }
            } message: {
                Text(importError ?? AppConstants.General.unknownError)
            }
        }
    }
    
    // MARK: - Logic
    
    private func deleteSelectedCard() {
        guard let card = currentSelectedCard else { return }
        withAnimation(springAnimation) {
            selectedCardID = nil
            NotificationManager.shared.cancelNotification(for: card)
            context.delete(card)
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                try CSVService.Cards.parse(content: content, into: context)
                importError = nil
            } catch {
                importError = String(format: AppConstants.General.importFailed, error.localizedDescription)
                showImportAlert = true
            }
        case .failure(let error):
            print(String(format: AppConstants.AI.fileSelectionFailed, error.localizedDescription))
        }
    }
}

// MARK: - Subviews

private struct CardDetailLayer: View {
    let card: CreditCard
    let onClose: () -> Void
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            // 添加一个透明的点击区域覆盖在卡片显示的位置
            // 实际上这里的 ScrollView 内容是从 padding 280 开始的
            // 为了让用户点击顶部区域（即视觉上卡片所在的位置）能触发关闭，
            // 我们可以在这里放置一个透明视图或者让上层处理
            // 但目前的架构是 CardStackLayer 浮在上面。
            
            // 关键逻辑：
            // 当 isDetailMode 为 true 时，CardStackLayer 中的卡片被移动到了顶部。
            // 此时点击 CardStackLayer 中的卡片（即 CreditCardView）会触发 CardStackLayer 中的 onTapGesture。
            // 让我们检查 CardStackLayer 的逻辑。
            
            EmbeddedTransactionListView(card: card)
        }
        .padding(.top, 280)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(0)
    }
}

private struct CardStackLayer: View {
    let cards: [CreditCard]
    @Binding var selectedCardID: PersistentIdentifier?
    @Binding var scrollOffset: CGFloat
    let isDetailMode: Bool
    let springAnimation: Animation
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: -proxy.frame(in: .named("scrollSpace")).minY
                    )
                }
                .frame(height: 0)
                
                if cards.isEmpty {
                    ContentUnavailableView(
                        AppConstants.Card.noCards,
                        systemImage: "creditcard",
                        description: Text(AppConstants.Card.addFirstCard)
                    )
                    .frame(height: 400)
                    .padding(.top, 40)
                } else {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        let isSelected = card.id == selectedCardID
                        
                        CreditCardView(
                            bankName: card.bankName,
                            type: card.type,
                            endNum: card.endNum,
                            cardOrganization: card.cardOrganization,
                            cardImageData: card.cardImageData
                        )
                        .contentShape(Rectangle())
                        .offset(y: calculateOffset(index: index, isSelected: isSelected))
                        .opacity(isDetailMode && !isSelected ? 0 : 1)
                        .scaleEffect(isDetailMode && !isSelected ? 0.9 : 1)
                        .zIndex(isSelected ? 100 : Double(index))
                        .shadow(color: .black.opacity(isDetailMode ? 0.2 : 0.1), radius: isDetailMode ? 20 : 10, x: 0, y: 5)
                        .onTapGesture {
                            withAnimation(springAnimation) {
                                if isSelected {
                                    // 如果当前已经是选中状态（详情模式），再次点击则取消选中（返回列表）
                                    selectedCardID = nil
                                } else {
                                    // 否则选中该卡片（进入详情模式）
                                    selectedCardID = card.id
                                }
                            }
                        }
                    }
                }
                
            }
        }
        .coordinateSpace(name: "scrollSpace")
        // iOS 17+: 优化滚动对齐
        .scrollTargetBehavior(.viewAligned)
        .onPreferenceChange(ScrollOffsetKey.self) { value in
            if !isDetailMode {
                scrollOffset = value
            }
        }
        .scrollDisabled(isDetailMode)
        // 关键修复：确保在详情模式下，卡片本身依然可以接收点击事件
        // 之前的 .allowsHitTesting(!isDetailMode) 禁用了整个 ScrollView 的交互，导致点击卡片无效
        // 我们应该只禁用滚动，但不禁用点击
        // .allowsHitTesting(!isDetailMode) <--- 删除这一行
    }
    
    private func calculateOffset(index: Int, isSelected: Bool) -> CGFloat {
        if isSelected {
            return scrollOffset + 10
        } else {
            return isDetailMode ? 800 : CGFloat(index * 100 + 20)
        }
    }
}

private struct CloseTapArea: View {
    let action: () -> Void
    
    var body: some View {
        Color.clear.contentShape(Rectangle())
            .frame(height: 280)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .zIndex(2)
            .onTapGesture(perform: action)
    }
}

private struct CardListToolbar: View {
    let cards: [CreditCard]
    let selectedCard: CreditCard?
    @Binding var cardToEdit: CreditCard?
    @Binding var activeSheet: SheetType?
    @Binding var showFileImporter: Bool
    let deleteAction: () -> Void
    
    var body: some View {
        if let card = selectedCard {
            Menu {
                Button { cardToEdit = card } label: {
                    Label(AppConstants.Card.editCard, systemImage: "pencil")
                }
                
                if let transactions = card.transactions, !transactions.isEmpty {
                    let sortedTxs = transactions.sorted(by: { $0.date > $1.date })
                    ShareLink(item: TransactionCSV(transactions: sortedTxs), preview: SharePreview(AppConstants.Transaction.exportTransactions)) {
                        Label(AppConstants.Transaction.exportTransactions, systemImage: "square.and.arrow.up")
                    }
                }
                
                Divider()
                
                Button(role: .destructive, action: deleteAction) {
                    Label(AppConstants.Card.deleteCard, systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 24))
            }
        } else {
            Menu {
                Button { activeSheet = .template } label: {
                    Label(AppConstants.Card.addFromTemplate, systemImage: "doc.on.doc")
                }
                
                Button { activeSheet = .custom } label: {
                    Label(AppConstants.Card.addCustom, systemImage: "square.and.pencil")
                }
                
                Divider()
                
                ShareLink(item: CardCSV(cards: cards), preview: SharePreview(AppConstants.Card.exportCards)) {
                    Label(AppConstants.Card.exportCards, systemImage: "square.and.arrow.up")
                }
                
                Button { showFileImporter = true } label: {
                    Label(AppConstants.Card.importCards, systemImage: "square.and.arrow.down")
                }
            } label: {
                Image(systemName: "plus.circle.fill") // Use + icon for adding
                    .font(.system(size: 24))
            }
        }
    }
}

struct EmbeddedTransactionListView: View {
    let card: CreditCard
    @State private var selectedTransaction: Transaction? = nil
    @State private var transactionToEdit: Transaction?
    @Environment(\.modelContext) var context

    var sortedTransactions: [Transaction] {
        (card.transactions ?? []).sorted { $0.date > $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppConstants.Transaction.latestTransactions)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.leading, 16)
                .padding(.top, 10)
            
            if sortedTransactions.isEmpty {
                ContentUnavailableView(
                    AppConstants.Transaction.noTransactions,
                    systemImage: "list.bullet.clipboard",
                    description: Text(AppConstants.Transaction.noTransactionsDescription)
                )
                .frame(height: 200)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            } else {
                TransactionList(
                    transactions: sortedTransactions,
                    onSelect: { selectedTransaction = $0 },
                    onEdit: { transactionToEdit = $0 },
                    onDelete: { context.delete($0) }
                )
            }
            
            Spacer().frame(height: 50)
        }
        .sheet(item: $selectedTransaction) { item in
            TransactionDetailView(transaction: item).presentationDetents([.large])
        }
        .sheet(item: $transactionToEdit) { item in
            AddTransactionView(transaction: item)
        }
    }
}



private struct TransactionList: View {
    let transactions: [Transaction]
    let onSelect: (Transaction) -> Void
    let onEdit: (Transaction) -> Void
    let onDelete: (Transaction) -> Void
    
    var body: some View {
        LazyVStack(spacing: 15) {
            ForEach(transactions) { item in
                TransactionRow(transaction: item)
                    .onTapGesture { onSelect(item) }
                    .contextMenu {
                        Button { onEdit(item) } label: { Label(AppConstants.General.edit, systemImage: "pencil") }
                        Button(role: .destructive) { onDelete(item) } label: { Label(AppConstants.General.delete, systemImage: "trash") }
                    }
            }
        }
        .padding(.horizontal)
    }
}
