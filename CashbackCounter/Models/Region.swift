//
//  Region.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/24/25.
//

import FoundationModels

enum Region: String, CaseIterable, Codable {
    case cn = "中国大陆"
    case hk = "中国香港"
    case us = "美国"
    case jp = "日本"
    case nz = "新西兰"
    case tw = "台湾"
    case other = "其他地区"
    
    var icon: String {
        switch self {
        case .cn: return "🇨🇳" // 直接用 Emoji，简单明了
        case .hk: return "🇭🇰"
        case .us: return "🇺🇸"
        case .jp: return "🇯🇵"
        case .nz: return "🇳🇿"
        case .tw: return "🇹🇼"
        case .other: return "🌍"
        }
    }
    var currencySymbol: String {
        switch self {
        case .cn: return "CN¥"
        case .hk: return "HK$"
        case .us: return "US$"
        case .jp: return "JP¥"
        case .nz: return "NZ$"
        case .tw: return "NT$"
        case .other: return " " // 或者用通用符号
        }
    }
    var currencyCode: String {
        switch self {
        case .cn: return "CNY"
        case .us: return "USD"
        case .hk: return "HKD"
        case .jp: return "JPY"
        case .nz: return "NZD"
        case .tw: return "TWD"
        case .other: return "EUR"
        }
    }
    var recognitionLanguages: [String] {
            switch self {
            case .jp:
            // 日本：必须把 ja-JP 放第一，否则片假名容易丢
                return ["ja-JP", "en-US", "zh-Hans"]
                
            case .cn, .hk, .tw:
            // 中文区：繁简中优先
                return ["zh-Hans", "zh-Hant", "en-US", "ja-JP"]
                
            case .us, .nz, .other:
            // 英语区：英文优先
                return ["en-US", "zh-Hans", "ja-JP"]
            }
        }
}
