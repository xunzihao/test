//
//  CSVParser.swift
//  CashbackCounter
//
//  Created by Assistant.
//

import Foundation

struct CSVParser {
    
    /// Parses a CSV string into a list of rows, where each row is a list of column strings.
    static func parse(_ content: String) -> [[String]] {
        let rows = content.components(separatedBy: .newlines)
        var result: [[String]] = []
        
        for (index, row) in rows.enumerated() {
            // Skip header (optional, but handled by caller usually) and empty lines
            if row.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            let columns = splitCSVLine(row)
            result.append(columns)
        }
        
        return result
    }
    
    /// Splits a single CSV line into columns, respecting quotes.
    static func splitCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
                current.append(char)
            } else if char == "," && !insideQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }
    
    /// Cleans a CSV field by removing surrounding quotes and unescaping double quotes.
    static func cleanField(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("\"") && s.hasSuffix("\"") {
            s.removeFirst()
            s.removeLast()
        }
        return s.replacingOccurrences(of: "\"\"", with: "\"")
    }
    
    /// Escapes a field for CSV export (wrapping in quotes if needed, escaping quotes).
    static func escapeField(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return text
    }
}
