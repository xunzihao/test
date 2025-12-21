//
//  SharedModelContainer.swift
//  CashbackCounter
//
//  Created by Assistant.
//

import SwiftData
import Foundation
import OSLog

/// 共享的 ModelContainer 配置
/// 用于在主 App 和 AppIntents 之间共享数据
enum SharedModelContainer {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CashbackCounter", category: "SharedModelContainer")
    
    /// 创建共享的 ModelContainer
    /// - Returns: 配置好的 ModelContainer 实例
    static func create() -> ModelContainer {
        logger.info("开始初始化 SharedModelContainer")
        
        let schema = Schema([Transaction.self, CreditCard.self])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            // 👇 如果需要在快捷指令中访问数据，需要配置 App Group
            // 步骤：
            // 1. 在 Xcode 中添加 App Groups capability
            // 2. 创建一个 group identifier，例如 "group.com.yourcompany.cashbackcounter"
            // 3. 取消注释下面这行，并替换为你的 group identifier
            isStoredInMemoryOnly: false, groupContainer: .identifier(AppConstants.Config.appGroupId)
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            logger.info("SharedModelContainer 初始化成功")
            return container
        } catch {
            logger.critical("无法创建 SharedModelContainer: \(error.localizedDescription)")
            fatalError("Failed to create shared model container: \(error)")
        }
    }
}
