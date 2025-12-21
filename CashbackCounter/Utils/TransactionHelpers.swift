//
//  TransactionHelpers.swift
//  CashbackCounter
//
//  Created by Assistant on 12/20/25.
//

import SwiftUI

struct TransactionHelpers {
    
    /// 🔧 标准化支付方式名称
    static func normalizePaymentMethod(_ method: String) -> String {
        switch method.uppercased() {
        case "APPLE PAY":
            return AppConstants.Transaction.applePay
        case "UNIONPAY QR", "银联二维码":
            return AppConstants.Transaction.unionPayQR
        case "SALE", "线下购物":
            return AppConstants.OCR.sale
        case "退款":
            return AppConstants.Transaction.refund
        case "还款":
            return AppConstants.Transaction.repayment
        case "自动还款", "PAID BY AUTOPAY":
            return AppConstants.OCR.autoRepayment
        case "分期计划", "MOB INSTALMENT":
            return AppConstants.OCR.PaymentDetection.instalment[0] // Use first item or define a single string constant if needed.
        case "CBF", "DCC FEE":
            return AppConstants.Transaction.cbf
        default:
            return method
        }
    }
    
    /// 支付方式图标
    static func paymentMethodIcon(for method: String) -> String {
        switch method {
        case AppConstants.Transaction.applePay:
            return "applelogo"
        case AppConstants.Transaction.unionPayQR, "UNIONPAY QR":
            return "qrcode"
        case AppConstants.Transaction.refund:
            return "arrow.uturn.backward"
        case AppConstants.Transaction.repayment, AppConstants.OCR.autoRepayment:
            return "creditcard.and.123"
        case "分期计划":
            return "calendar.badge.clock"
        case AppConstants.Transaction.cbf:
            return "percent"
        case AppConstants.OCR.sale:
            return "creditcard.fill"
        default:
            return "creditcard"
        }
    }
    
    /// 支付方式颜色
    static func paymentMethodColor(for method: String) -> Color {
        switch method {
        case AppConstants.Transaction.applePay:
            return Color.black
        case AppConstants.Transaction.unionPayQR, "UNIONPAY QR":
            return Color.blue
        case AppConstants.Transaction.refund:
            return Color.green
        case AppConstants.Transaction.repayment, AppConstants.OCR.autoRepayment:
            return Color.purple
        case "分期计划":
            return Color.orange
        case AppConstants.Transaction.cbf:
            return Color.red
        case AppConstants.OCR.sale:
            return Color.gray
        default:
            return Color.secondary
        }
    }
}
