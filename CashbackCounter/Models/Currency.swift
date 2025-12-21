//
//  Currency.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/24/25.
//

// import Foundation

enum Currency: String, CaseIterable, Codable {
    case cny = "CNY"
    case hkd = "HKD"
    case mop = "MOP"
    case usd = "USD"
    case jpy = "JPY"
    case krw = "KRW"
    case twd = "TWD"
    case other = "其他币种"
    case all = "所有币种"
    
    var currencyCode: String {
        switch self {
        case .cny: return "CNY"
        case .usd: return "USD"
        case .hkd: return "HKD"
        case .mop: return "MOP"
        case .jpy: return "JPY"
        case .krw: return "KRW"
        case .twd: return "TWD"
        case .other: return "其他币种"
        case .all: return "所有币种"
        }
    }
}
