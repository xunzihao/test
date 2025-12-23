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
    
    @Guide(description: """
    The total amount paid in the ORIGINAL/FOREIGN currency (消费原币金额).
    This is the amount shown as the transaction amount in the merchant's currency.
    Common labels on receipts: '外币金额', '消费金额', '交易金额', 'Amount', 'Total'
    Example: If a Hong Kong card pays at a Chinese merchant showing CNY ¥100, this should be 100.
    ⚠️ Do NOT confuse this with billing amount (入账金额/记账金额).
    """)
    var spendingAmount: Double? // ✅ 消费金额（外币优先）
    
    @Guide(description: """
    The currency code of totalAmount (消费币种).
    This should match the merchant's local currency, NOT the cardholder's home currency.
    Common values: CNY (China), USD (USA), HKD (Hong Kong), JPY (Japan), NZD (New Zealand), TWD (Taiwan), KRW (South Korea), EUR (Europe), GBP (UK)
    Look for: Currency symbols near the total amount, country/region indicators
    Example: If receipt shows 'CNY ¥100' or '¥100 (中国)', use 'CNY'
    """)
    var currency: String?    // ✅ 消费原币币种
    
    @Guide(description: """
    The billing amount charged to the card (入账金额/记账金额).
    This is the amount converted to the card's home currency (after exchange rate conversion).
    Common labels on receipts: '记账金额', '入账金额', '本币金额', 'Billing Amount', 'Posted Amount'
    This field appears ONLY on cross-border transactions.
    ⚠️ If the receipt shows only ONE amount, that's totalAmount, NOT billingAmount.
    ⚠️ If you see TWO different amounts with different currency symbols, the second one is usually billingAmount.
    Leave nil if not explicitly shown.
    """)
    var billingAmount: Double? // ✅ 新增：入账金额（卡片本币）
    
    @Guide(description: """
    The currency code of billingAmount (入账币种).
    This is the card's home currency (cardholder's billing currency).
    Common values: HKD (for Hong Kong cards), CNY (for Chinese cards), USD (for US cards)
    Look for: Labels like '记账币种', '本币币种', or the currency symbol next to billing amount
    Example: If billing amount shows 'HKD $110.50', use 'HKD'
    Leave nil if billingAmount is nil.
    """)
    var billingCurrency: String? // ✅ 新增：入账币种
    
    @Guide(description: """
    The exchange rate shown on the receipt (汇率).
    This is the rate used to convert foreign currency to billing currency.
    Common labels: '汇率', 'Exchange Rate', 'Rate'
    Format: Usually '1 foreign currency unit = X billing currency units'
    Example: If receipt shows '汇率: 1.1000' or 'Rate: 1.1', extract 1.1
    ⚠️ Only extract if explicitly shown. Do NOT calculate it yourself.
    Leave nil if not shown.
    """)
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
