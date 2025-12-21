//
//  Formatters.swift
//  CashbackCounter
//
//  Created by Assistant.
//

import Foundation

struct Formatters {
    
    /// Formats a double value as a currency string (e.g., "123.45").
    static func currency(_ amount: Double) -> String {
        return String(format: "%.2f", amount)
    }
    
    /// Formats a double value as a percentage string (e.g., "1.50").
    /// Assumes the input is a fraction (e.g., 0.015 -> 1.50).
    static func percentage(_ value: Double) -> String {
        return String(format: "%.2f", value * 100)
    }
    
    /// Formats a double value with zero decimal places (e.g., "100").
    static func wholeNumber(_ value: Double) -> String {
        return String(format: "%.0f", value)
    }
    
    // MARK: - Input Formatters
    
    /// 将“百分比 * 100”的 Int 转为 UI 字符串（例如 100 -> "1.0"）
    static func percentString(fromScaledPercent value: Int) -> String {
        guard value != 0 else { return "" }
        let percent = Double(value) / 100.0
        return String(format: percent.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", percent)
    }

    /// 将 UI 输入的百分比字符串转成“百分比 * 100”的 Int（例如 "1.0" -> 100）
    static func scaledPercent(from input: String) -> Int {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let percent = Double(trimmed) ?? 0
        return Int((percent * 100).rounded())
    }

    /// 将 UI 输入的整数/空字符串转成 Int（空/非法 -> 0）
    static func intOrZero(from input: String) -> Int {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return Int(trimmed) ?? 0
    }
}
