//
//  StatBox.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI

struct StatBox: View {
    let title: String
    let amount: String
    let icon: String
    let color: Color
    
    // 1. 安装传感器：探测当前是深色还是浅色模式
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .accessibilityHidden(true) // 装饰性图标无需朗读
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary) // secondary 颜色会自动适配深浅
            }
            
            Text(amount)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit() // 数字等宽，防止宽度跳动
                .minimumScaleFactor(0.8) // 防止数字过长截断，允许缩小
                .lineLimit(nil) // 允许换行
                .fixedSize(horizontal: false, vertical: true) // 垂直方向自适应高度
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        // 2. 背景色升级：使用系统语义化颜色
        // 浅色模式下是白色，深色模式下是深灰色
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(15)
        // 3. 阴影与描边的处理
        // 如果是深色模式，就去掉阴影 (color: .clear)；浅色模式才显示阴影
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 5, x: 0, y: 2)
        // 4. 深色模式专属描边
        // 在上面叠加一个圆角矩形，如果是深色模式，就画一圈细线；浅色模式线宽为0
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.2), lineWidth: colorScheme == .dark ? 0.5 : 0)
        )
        // 5. 无障碍支持
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(amount)")
        .accessibilityAddTraits(.isStaticText)
    }
}
