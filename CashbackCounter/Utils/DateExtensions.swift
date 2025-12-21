//
//  DateExtensions.swift
//  CashbackCounter
//
//  Created by Assistant.
//

import Foundation

extension String {
    /// Converts a string in "yyyy-MM-dd" format to a Date object.
    /// Returns today's date if parsing fails.
    func toDate() -> Date {
        return toOptionalDate() ?? Date()
    }
    
    /// Converts a string in "yyyy-MM-dd" format to a Date object.
    /// Returns nil if parsing fails.
    func toOptionalDate() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: self)
    }
}

extension Date {
    /// Returns a string representation of the date in "yyyy-MM-dd" format.
    func toDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
    
    /// Returns a string representation of the date in "yyyyMMdd" format (for file names).
    func toFileNameString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: self)
    }
}
