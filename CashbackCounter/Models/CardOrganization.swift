//
//  CardOrganization.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 12/17/25.
//

import Foundation

/// 卡组织枚举
enum CardOrganization: String, CaseIterable, Codable {
    case unionPay = "银联"
    case visa = "Visa"
    case mastercard = "Mastercard"
    case amex = "American Express"
    case jcb = "JCB"
    case discover = "Discover"
    
    var displayName: String {
        return self.rawValue
    }
    
    /// 获取该卡组织支持的卡等级列表
    var availableLevels: [CardLevel] {
        switch self {
        case .unionPay:
            return [.unionPayStandard, .unionPayGold, .unionPayPlatinum, .unionPayDiamond]
        case .visa:
            return [.visaStandard, .visaGold, .visaPlatinum, .visaSignature, .visaInfinite]
        case .mastercard:
            return [.mastercardStandard, .mastercardGold, .mastercardPlatinum, .mastercardTitanium, .mastercardWorld, .mastercardWorldElite]
        case .amex:
            return [.amexGreen, .amexGold, .amexPlatinum, .amexCenturion]
        case .jcb:
            return [.jcbStandard, .jcbGold, .jcbPlatinum]
        case .discover:
            return [.discoverStandard, .discoverChrome]
        }
    }
    
    /// 卡面 Logo 显示文字
    var logoText: String {
        switch self {
        case .unionPay: return "银联"
        case .visa: return "VISA"
        case .mastercard: return "MC"
        case .amex: return "AMEX"
        case .jcb: return "JCB"
        case .discover: return "DISC"
        }
    }
}

/// 卡等级枚举
enum CardLevel: String, Codable, Hashable, CaseIterable {
    // 银联系列
    case unionPayStandard = "unionPayStandard"
    case unionPayGold = "unionPayGold"
    case unionPayPlatinum = "unionPayPlatinum"
    case unionPayDiamond = "unionPayDiamond"
    
    // Visa 系列
    case visaStandard = "visaStandard"
    case visaGold = "visaGold"
    case visaPlatinum = "visaPlatinum"
    case visaSignature = "visaSignature"
    case visaInfinite = "visaInfinite"
    
    // Mastercard 系列
    case mastercardStandard = "mastercardStandard"
    case mastercardGold = "mastercardGold"
    case mastercardPlatinum = "mastercardPlatinum"
    case mastercardTitanium = "mastercardTitanium"
    case mastercardWorld = "mastercardWorld"
    case mastercardWorldElite = "mastercardWorldElite"
    
    // American Express 系列
    case amexGreen = "amexGreen"
    case amexGold = "amexGold"
    case amexPlatinum = "amexPlatinum"
    case amexCenturion = "amexCenturion"
    
    // JCB 系列
    case jcbStandard = "jcbStandard"
    case jcbGold = "jcbGold"
    case jcbPlatinum = "jcbPlatinum"
    
    // Discover 系列
    case discoverStandard = "discoverStandard"
    case discoverChrome = "discoverChrome"
    
    /// 显示名称（用户看到的中文名称）
    var displayName: String {
        switch self {
        // 银联系列
        case .unionPayStandard: return "普卡"
        case .unionPayGold: return "金卡"
        case .unionPayPlatinum: return "白金卡"
        case .unionPayDiamond: return "钻石卡"
        
        // Visa 系列
        case .visaStandard: return "普卡"
        case .visaGold: return "金卡"
        case .visaPlatinum: return "白金卡"
        case .visaSignature: return "御玺卡"
        case .visaInfinite: return "无限卡"
        
        // Mastercard 系列
        case .mastercardStandard: return "普卡"
        case .mastercardGold: return "金卡"
        case .mastercardPlatinum: return "白金卡"
        case .mastercardTitanium: return "钛金卡"
        case .mastercardWorld: return "世界卡"
        case .mastercardWorldElite: return "世界之极卡"
        
        // American Express 系列
        case .amexGreen: return "绿卡"
        case .amexGold: return "金卡"
        case .amexPlatinum: return "白金卡"
        case .amexCenturion: return "黑金卡"
        
        // JCB 系列
        case .jcbStandard: return "普卡"
        case .jcbGold: return "金卡"
        case .jcbPlatinum: return "白金卡"
        
        // Discover 系列
        case .discoverStandard: return "标准卡"
        case .discoverChrome: return "Chrome卡"
        }
    }
    
    /// 获取该卡等级所属的卡组织
    var organization: CardOrganization {
        switch self {
        case .unionPayStandard, .unionPayGold, .unionPayPlatinum, .unionPayDiamond:
            return .unionPay
        case .visaStandard, .visaGold, .visaPlatinum, .visaSignature, .visaInfinite:
            return .visa
        case .mastercardStandard, .mastercardGold, .mastercardPlatinum, .mastercardTitanium, .mastercardWorld, .mastercardWorldElite:
            return .mastercard
        case .amexGreen, .amexGold, .amexPlatinum, .amexCenturion:
            return .amex
        case .jcbStandard, .jcbGold, .jcbPlatinum:
            return .jcb
        case .discoverStandard, .discoverChrome:
            return .discover
        }
    }
}
