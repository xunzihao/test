//
//  TextCorrector.swift
//  CashbackCounter
//
//  Created by Assistant.
//

import Foundation

struct TextCorrector {
    
    /// Corrects common OCR errors in merchant names and other text.
    static func correctMerchantName(_ text: String) -> String {
        var corrected = text
        
        // Definitions of common OCR errors (pattern -> replacement)
        let corrections: [(pattern: String, replacement: String)] = [
            // Payment Platforms
            ("A1ipay", "Alipay"),          // l → 1
            ("A1iPay", "Alipay"),
            ("AIipay", "Alipay"),
            
            // WeChat Pay
            ("WeCh4t", "WeChat"),          // a → 4
            ("WeGhat", "WeChat"),
            
            // Tencent
            ("Tenc3nt", "Tencent"),        // e → 3
            
            // Other Common Merchants
            ("Taob4o", "Taobao"),          // a → 4
            ("Ta0bao", "Taobao"),          // o → 0
            
            // UnionPay
            ("UNIONPAY OR", "UNIONPAY QR") // OR -> QR
        ]
        
        // Apply corrections
        for (pattern, replacement) in corrections {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(corrected.startIndex..., in: corrected)
                corrected = regex.stringByReplacingMatches(
                    in: corrected,
                    options: [],
                    range: range,
                    withTemplate: replacement
                )
            }
        }
        
        return corrected
    }
    
    /// Corrects common OCR errors in date strings (e.g., O4DEC -> 04DEC).
    static func correctDateText(_ dateStr: String) -> String {
        var corrected = dateStr
        
        let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        
        // Rule 1: O + Digit + Month → 0 + Digit + Month (e.g., O4DEC → 04DEC)
        for month in months {
            corrected = corrected.replacingOccurrences(of: "O([0-9])\(month)", with: "0$1\(month)", options: .regularExpression)
        }
        
        // Rule 2: Digit + O + Month → Digit + 0 + Month (e.g., 3ONOV → 30NOV)
        for month in months {
            corrected = corrected.replacingOccurrences(of: "([0-9])O\(month)", with: "$10\(month)", options: .regularExpression)
        }
        
        // Rule 3: O + O + Month → 0 + 0 + Month (e.g., OODEC → 00DEC)
        for month in months {
            corrected = corrected.replacingOccurrences(of: "OO\(month)", with: "00\(month)")
        }
        
        // Rule 4: I + Digit + Month → 1 + Digit + Month (e.g., I4DEC → 14DEC)
        for month in months {
            corrected = corrected.replacingOccurrences(of: "I([0-9])\(month)", with: "1$1\(month)", options: .regularExpression)
        }
        
        // Rule 5: Digit + I + Month → Digit + 1 + Month (e.g., 2INOV → 21NOV)
        for month in months {
            corrected = corrected.replacingOccurrences(of: "([0-9])I\(month)", with: "$11\(month)", options: .regularExpression)
        }
        
        // Step 2: Fix typos in Month names themselves
        let monthCorrections: [(wrong: String, correct: String)] = [
            ("N0V", "NOV"),   // O → 0
            ("0CT", "OCT"),   // O → 0
            ("DEC", "DEC"),   // Correct, just for completeness if needed
            ("JAN", "JAN"),
        ]
        
        for (wrong, correct) in monthCorrections {
            corrected = corrected.replacingOccurrences(of: wrong, with: correct)
        }
        
        return corrected
    }
}
