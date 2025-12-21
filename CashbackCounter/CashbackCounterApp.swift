//
//  CashbackCounterApp.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct CashbackCounterApp: App {
    // MARK: - App Storage
    @AppStorage(AppConstants.Keys.userTheme) private var userTheme: AppTheme = .system
    @AppStorage(AppConstants.Keys.userLanguage) private var userLanguage: String = "system"
    
    // MARK: - State
    @StateObject private var aiAvailability = AppleIntelligenceAvailability()
    
    // MARK: - Model Container
    // 使用共享的 ModelContainer，确保和 AppIntents 使用同一个数据源
    private let sharedModelContainer: ModelContainer
    
    // MARK: - Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CashbackCounter", category: "AppLifecycle")
    
    // MARK: - Init
    init() {
        // 1. 初始化 ModelContainer
        // 注意：由于 sharedModelContainer 是 let 常量，必须在 init 中赋值
        self.sharedModelContainer = SharedModelContainer.create()
        
        // 2. 请求通知权限
        NotificationManager.shared.requestAuthorization()
        
        logger.info("\(AppConstants.Logs.appInitComplete)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(userTheme.colorScheme)
                .environment(\.locale, locale)
                .environmentObject(aiAvailability)
                .task {
                    // 异步检查 AI 支持状态
                    aiAvailability.refreshSupportStatus()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Helpers

private extension CashbackCounterApp {
    var locale: Locale {
        userLanguage == "system" ? .current : Locale(identifier: userLanguage)
    }
}

// MARK: - Types

// 定义主题枚举，避免 Magic Number (0, 1, 2)
enum AppTheme: Int {
    case system = 0
    case light = 1
    case dark = 2
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
