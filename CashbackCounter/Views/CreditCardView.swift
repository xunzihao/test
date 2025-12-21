//
//  CreditCardView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI

struct CreditCardView: View {
    let bankName: String
    let type: String
    let endNum: String
    let cardOrganization: CardOrganization?
    let cardImageData: Data?
    
    var body: some View {
        ZStack(alignment: .leading) {
            // 1. 卡片背景
            CardBackground(
                imageData: cardImageData,
                gradientColors: gradientColors
            )
            
            // 2. 卡片内容
            VStack(alignment: .leading) {
                // 顶部行：Logo 和 银行名称
                HStack {
                    CardLogoView(
                        organization: cardOrganization,
                        hasCustomImage: cardImageData != nil
                    )
                    
                    Spacer()
                    
                    // 仅在无自定义卡面时显示银行信息，避免遮挡
                    if cardImageData == nil {
                        Text("\(bankName) \(type)")
                            .font(.caption.bold())
                            .padding(6)
                            .background(.ultraThinMaterial) // 使用毛玻璃效果，适配性更好
                            .cornerRadius(5)
                    }
                }
                
                Spacer()
                
                // 底部行：卡号
                HStack {
                    Text("**** **** **** \(endNum)")
                        .font(.subheadline)
                        .monospacedDigit() // 等宽数字
                    
                    Spacer()
                }
            }
            .padding(25)
            .foregroundColor(.white)
        }
        .aspectRatio(1.586, contentMode: .fit) // 标准信用卡比例
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bankName) \(type), 尾号 \(endNum)")
    }
    
    // MARK: - Computed Properties
    
    private var gradientColors: [Color] {
        guard let org = cardOrganization else {
            return [.blue, .purple]
        }
        
        switch org {
        case .unionPay:  return [.red, Color(red: 0.8, green: 0, blue: 0)]
        case .visa:      return [.blue, Color(red: 0, green: 0.3, blue: 0.8)]
        case .mastercard:return [.orange, .red]
        case .amex:      return [.blue, .cyan]
        case .jcb:       return [.green, .blue]
        case .discover:  return [.orange, Color(red: 0.9, green: 0.5, blue: 0)]
        }
    }
}

// MARK: - Subviews

private struct CardBackground: View {
    let imageData: Data?
    let gradientColors: [Color]
    
    var body: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // ✨ iOS 18+: 使用 MeshGradient 作为默认背景
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        .init(0, 0), .init(0.5, 0), .init(1, 0),
                        .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                        .init(0, 1), .init(0.5, 1), .init(1, 1)
                    ],
                    colors: [
                        gradientColors.first ?? .blue, .white.opacity(0.2), gradientColors.last ?? .purple,
                        gradientColors.last?.opacity(0.5) ?? .purple.opacity(0.5), .clear, gradientColors.first?.opacity(0.5) ?? .blue.opacity(0.5),
                        gradientColors.last ?? .purple, .white.opacity(0.2), gradientColors.first ?? .blue
                    ]
                )
                .opacity(0.8) // 稍微柔和一点
            } else {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

private struct CardLogoView: View {
    let organization: CardOrganization?
    let hasCustomImage: Bool
    
    var body: some View {
        if hasCustomImage {
            // 已有自定义卡面，显示非接触支付图标作为装饰
            Image(systemName: "wave.3.right")
                .font(.title2)
                .accessibilityHidden(true)
        } else if let org = organization {
            // 显示卡组织 Logo
            OrganizationBadge(organization: org)
                .frame(width: 60, height: 40)
        } else {
            // 默认图标
            Image(systemName: "wave.3.right")
                .font(.title2)
                .accessibilityHidden(true)
        }
    }
}

private struct OrganizationBadge: View {
    let organization: CardOrganization
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.white.opacity(0.9))
            
            Text(organization.logoText)
                .font(.system(size: logoFontSize, weight: .bold))
                .foregroundColor(logoColor)
        }
    }
    
    private var logoFontSize: CGFloat {
        switch organization {
        case .unionPay: return 18
        case .discover: return 14
        default: return 16
        }
    }
    
    private var logoColor: Color {
        switch organization {
        case .unionPay: return .red
        case .visa: return .blue
        case .mastercard: return .orange
        case .amex: return .blue
        case .jcb: return .green
        case .discover: return .orange
        }
    }
}
