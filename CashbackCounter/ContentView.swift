import SwiftUI
import SwiftData

// --- 2. 主入口 (包含底部导航栏) ---
struct ContentView: View {
    // 选中的 Tab 索引
    @State private var selectedTab: Tab = .bill
    @EnvironmentObject private var aiAvailability: AppleIntelligenceAvailability

    // 使用枚举管理 Tab，避免 Magic Number
    enum Tab: Int {
        case bill = 0
        case analysis
        case camera
        case card
        case settings
    }

    var body: some View {
        // TabView 是底部导航栏的核心容器
        TabView(selection: $selectedTab) {
            
            // ---账单页 ---
            BillHomeView()
                .tabItem {
                    Label(AppConstants.TabBar.bill, systemImage: selectedTab == .bill ? "doc.text.image.fill" : "doc.text.image")
                }
                .tag(Tab.bill)
            
            // --- 结单分析页 ---
            StatementAnalysisView()
                .tabItem {
                    Label(AppConstants.TabBar.analysis, systemImage: "doc.text.magnifyingglass")
                }
                .tag(Tab.analysis)
            
            // ---拍照/记账页 ---
            CameraRecordView()
                .tabItem {
                    Label(AppConstants.TabBar.camera, systemImage: "camera.circle.fill")
                }
                .tag(Tab.camera)
            
            // ---信用卡页 ---
            CardListView()
                .tabItem {
                    Label(AppConstants.TabBar.card, systemImage: selectedTab == .card ? "creditcard.fill" : "creditcard")
                }
                .tag(Tab.card)
            
            // --- 设置页 ---
            SettingsView()
                .tabItem {
                    Label(AppConstants.TabBar.settings, systemImage: selectedTab == .settings ? "gearshape.fill" : "gearshape")
                }
                .tag(Tab.settings)
        }
        .tint(.blue) // 设置底部选中时的颜色 (Apple 蓝)
        .task {
            aiAvailability.refreshSupportStatus()
        }
        .alert(AppConstants.AI.compatibilityModeEnabled, isPresented: $aiAvailability.showCompatibilityAlert) {
            Button(AppConstants.General.ok, role: .cancel) { }
        } message: {
            Text(AppConstants.AI.compatibilityMessage)
        }
    }
}
