//
//  ReceiptModels.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/24/25.
//

import Foundation
import FoundationModels

// 1. 定义收据结构 (对应 Apple 的 Itinerary)
@Generable
struct ReceiptMetadata {
    @Guide(description: "The name of the store or merchant.")
    var merchant: String?  // ✅ 加上问号
    
    @Guide(description: "The total amount paid in the LOCAL/FOREIGN currency (消费原币). If receipt shows '外币金额', use that value. Example: If Hong Kong card pays CNY ¥100, this should be 100.")
    var totalAmount: Double? // ✅ 消费金额（外币优先）
    
    @Guide(description: "The currency code of totalAmount (choice from: CNY, USD, HKD, JPY, NZD, TWD, other). Use the currency of the MERCHANT'S country, not the card's country.")
    var currency: String?    // ✅ 消费原币币种
    
    @Guide(description: "The billing amount charged to the card (入账金额). This is the amount converted to the card's home currency. If receipt shows '记账金额/入账金额', use that value. If not present, leave nil.")
    var billingAmount: Double? // ✅ 新增：入账金额（卡片本币）
    
    @Guide(description: "The currency code of billingAmount. This is the card's home currency. Example: HKD for Hong Kong cards. If not specified, leave nil.")
    var billingCurrency: String? // ✅ 新增：入账币种
    
    @Guide(description: "The exchange rate shown on the receipt (汇率). This is the rate used to convert foreign currency to billing currency. Example: If receipt shows '汇率: 1.1000', extract 1.1000. Format: 1 foreign currency unit = X billing currency units. If not shown, leave nil.")
    var exchangeRate: Double? // 🆕 汇率
    
    @Guide(description: "The payment method used for this transaction. Detect from receipt text and map to: 'Apple Pay' if contains 'Apple Pay/APPLE PAY/苹果支付'; '银联二维码' if contains 'QR/二维码/扫码/云闪付'; '网购' if contains '网购/在线支付/Online'; '线下购物' for physical store purchases; Leave nil if cannot determine.")
    var paymentMethod: String? // 🆕 支付方式
    
    @Guide(description: "The date of transaction in YYYY-MM-DD format.")
    var dateString: String?  // ✅ 加上问号
    
    @Guide(description: "The last 4 digits of the credit card used.")
    var cardLast4: String?   // ✅ 加上问号
    
    @Guide(description: "Classify the receipt into one of the categories based on the merchant and items")
    var category: Category?
}

@Generable
struct SMSMetadata {
    @Guide(description: "The name of the store or merchant.")
    var merchant: String?  // ✅ 加上问号
    
    @Guide(description: "The total amount paid (not contain deduction).")
    var totalAmount: Double? // ✅ 加上问号
    
    @Guide(description: "The last 4 digits of the credit card used.")
    var cardLast4: String?   // ✅ 加上问号
    
    @Guide(description: "Classify the receipt into one of the categories based on the merchant and items")
    var category: Category?
}
