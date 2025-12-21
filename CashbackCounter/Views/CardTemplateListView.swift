//
//  CardTemplateListView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData

// MARK: - View

struct CardTemplateListView: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    
    // 1. 控制跳转的状态：存用户选了哪个模板
    @State private var selectedTemplate: CardTemplate?
    @Binding var rootSheet: SheetType?
    @State private var templates: [CardTemplate] = []
    
    var body: some View {
        NavigationStack {
            List(templates) { template in
                Button {
                    selectedTemplate = template
                } label: {
                    TemplateRow(template: template)
                }
            }
            .listStyle(.insetGrouped) // 优化列表样式
            .navigationTitle(AppConstants.Card.selectCardTemplate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppConstants.General.cancel) { dismiss() }
                }
            }
            .onAppear {
                templates = TemplateLoader.loadTemplates()
            }
            // 核心跳转逻辑：当 selectedTemplate 有值时，弹出 AddCardView
            .sheet(item: $selectedTemplate) { template in
                AddCardView(template: template, onSaved: {
                    rootSheet = nil
                })
            }
        }
    }
}

// MARK: - Subviews

private struct TemplateRow: View {
    let template: CardTemplate
    
    var body: some View {
        HStack(spacing: 12) {
            // 卡片图标/图片
            AsyncImage(url: URL(string: template.pictureURL ?? "")) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if phase.error != nil {
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(.gray)
                } else {
                    // 加载中或无 URL
                    if template.pictureURL == nil {
                        Image(systemName: "creditcard")
                            .foregroundColor(.gray)
                    } else {
                        ProgressView()
                    }
                }
            }
            .frame(width: 50, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(template.bankName)
                    .font(.headline)
                Text(template.type)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.tertiaryLabel) // 使用更淡的颜色
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // 扩大点击区域
    }
}

// 辅助扩展：语义化颜色
extension Color {
    static let tertiaryLabel = Color(uiColor: .tertiaryLabel)
}
