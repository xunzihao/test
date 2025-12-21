//
//  NotificationManager.swift
//  CashbackCounter
//
//  Created by Assistant on 12/20/25.
//

import UserNotifications
import UIKit
import os

/// 管理应用内所有的本地通知逻辑
class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CashbackCounter", category: "NotificationManager")
    
    private init() {}
    
    /// 请求通知权限
    func requestAuthorization() {
        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    logger.info("✅ 通知权限已获取")
                } else {
                    logger.warning("❌ 通知权限被用户拒绝")
                }
            } catch {
                logger.error("❌ 请求通知权限出错: \(error.localizedDescription)")
            }
        }
    }
    
    /// 检查当前的授权状态
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    /// 为信用卡设置每月还款提醒
    /// - Parameter card: 需要提醒的信用卡
    func scheduleNotification(for card: CreditCard) {
        Task {
            // 1. 总是先取消旧的提醒，避免重复或数据过时
            cancelNotification(for: card)
            
            // 2. 校验配置：必须开启提醒且还款日有效
            guard card.isRemindOpen, card.repaymentDay > 0, card.repaymentDay <= 31 else {
                logger.debug("🚫 卡片 [\(card.bankName)] 未开启提醒或还款日无效，跳过注册")
                return
            }
            
            // 3. 构建通知内容
            let content = UNMutableNotificationContent()
            content.title = "\(AppConstants.Notification.repaymentTitlePrefix)\(card.bankName)"
            content.body = AppConstants.Notification.repaymentBody
            content.sound = .default
            
            // 4. 设置触发器：每月还款日 上午 9:00
            var dateComponents = DateComponents()
            dateComponents.day = card.repaymentDay
            dateComponents.hour = 9
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            // 5. 创建请求
            let identifier = notificationIdentifier(for: card)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            // 6. 提交请求
            do {
                try await center.add(request)
                logger.info("✅ 已设定提醒: [\(card.bankName)] 每月 \(card.repaymentDay) 日 09:00")
            } catch {
                logger.error("❌ 注册提醒失败 [\(card.bankName)]: \(error.localizedDescription)")
            }
        }
    }
    
    /// 取消指定卡片的提醒
    func cancelNotification(for card: CreditCard) {
        let identifier = notificationIdentifier(for: card)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        logger.debug("🗑 已移除提醒请求: [\(card.bankName)] (ID: \(identifier))")
    }
    
    /// 取消所有提醒
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        logger.info("🗑 已移除所有待办提醒")
    }
    
    // MARK: - Helpers
    
    private func notificationIdentifier(for card: CreditCard) -> String {
        return card.id.hashValue.description
    }
    
    /// 获取当前所有待处理的通知请求（用于调试）
    func getPendingRequests() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }
}

