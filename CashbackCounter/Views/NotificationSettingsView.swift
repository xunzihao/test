//
//  NotificationSettingsView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/29/25.
//

import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @Query var cards: [CreditCard]
    
    var body: some View {
        List {
            Section(footer: Text(AppConstants.Settings.notificationFooter)) {
                if cards.isEmpty {
                    Text(AppConstants.Settings.noCardsForNotification)
                        .foregroundColor(.secondary)
                }
                
                ForEach(cards) { card in
                    NotificationCardRow(card: card)
                }
            }
        }
        .navigationTitle(AppConstants.Settings.repaymentNotificationTitle)
        .onAppear {
            // 进页面时检查一下权限
            NotificationManager.shared.requestAuthorization()
        }
    }
}

// MARK: - Subviews

private struct NotificationCardRow: View {
    @Bindable var card: CreditCard
    
    var body: some View {
        HStack {
            // 左侧信息
            VStack(alignment: .leading, spacing: 4) {
                Text("\(card.bankName) \(card.type)")
                    .font(.headline)
                
                if card.repaymentDay > 0 {
                    Text(String(format: AppConstants.Settings.repaymentDayFormat, card.repaymentDay))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Label(AppConstants.Settings.noRepaymentDaySet, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // 右侧开关
            Toggle(AppConstants.Settings.repaymentSwitchLabel, isOn: Binding(
                get: { card.isRemindOpen },
                set: { newValue in
                    card.isRemindOpen = newValue
                    // 开关变动时，立刻刷新通知状态
                    updateNotification(enabled: newValue)
                }
            ))
            .labelsHidden() // 隐藏文字标签，只显示开关控件
            .disabled(card.repaymentDay == 0)
        }
        .padding(.vertical, 4)
    }
    
    private func updateNotification(enabled: Bool) {
        if enabled {
            NotificationManager.shared.scheduleNotification(for: card)
        } else {
            NotificationManager.shared.cancelNotification(for: card)
        }
    }
}
