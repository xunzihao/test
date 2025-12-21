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
    
    // 添加环境变量以访问 ModelContext
    @Environment(\.modelContext) var modelContext
    
    // 控制确认对话框
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // 1. App 头部
                AppHeaderSection(appVersion: appVersion)
                
                // 2. 外观与语言
                AppearanceSection(userTheme: $userTheme, userLanguage: $userLanguage)
                
                // 3. 常规设置
                GeneralSection()
                
                // 4. 数据管理
                DataManagementSection()
                
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
        }
    }
    
    // MARK: - Actions
    
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
    var body: some View {
        Section(header: Text(AppConstants.Settings.general)) {
            NavigationLink(destination: Text(AppConstants.Settings.multiCurrencySupport)) {
                Label(AppConstants.Settings.multiCurrencySettings, systemImage: "banknote")
            }
            
            NavigationLink(destination: NotificationSettingsView()) {
                Label(AppConstants.Settings.notifications, systemImage: "bell")
            }
        }
    }
}

// 4. 数据管理
private struct DataManagementSection: View {
    var body: some View {
        Section(header: Text(AppConstants.Settings.dataManagement)) {
            Label(AppConstants.Settings.iCloudSync, systemImage: "icloud")
                .foregroundColor(.secondary)
            
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

#Preview {
    SettingsView()
}
