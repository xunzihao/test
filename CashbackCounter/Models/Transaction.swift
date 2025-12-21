import SwiftUI
import SwiftData

@Model
class Transaction: Identifiable {
    var merchant: String
    var category: Category
    var location: Region
    
    var amount: Double        // 原币金额
    var billingAmount: Double // 入账金额
    var cbfAmount: Double = 0.0 // CBF 费用金额（如果适用）
    
    var date: Date
    var cashbackamount: Double
    var rate: Double

    /// 支付方式（如：网购 / Apple Pay / 银联二维码 / 线下购物 / 其他）
    /// 为空表示未填写（兼容旧数据）
    var paymentMethod: String = ""

    /// 是否为网上购物（与 paymentMethod 可独立；用于未来规则扩展）
    var isOnlineShopping: Bool = false

    /// 是否适用 CBF（重要：必须手动选择；不做自动推断）
    var isCBFApplied: Bool = false
    
    /// 是否为信用交易（还款/退款/调整）—— 这类交易不计算返现
    var isCreditTransaction: Bool = false
    
    var card: CreditCard?
    
    @Attribute(.externalStorage) var receiptData: Data?
    
    // 👇 修改 init 方法，增加 cashbackAmount 和 cbfAmount 参数
    init(merchant: String,
         category: Category,
         location: Region,
         amount: Double,
         date: Date,
         card: CreditCard?,
         paymentMethod: String = "",
         isOnlineShopping: Bool = false,
         isCBFApplied: Bool = false,
         isCreditTransaction: Bool = false, // 👈 新增：是否为信用交易
         receiptData: Data? = nil,
         billingAmount: Double? = nil,
         cashbackAmount: Double? = nil,
         cbfAmount: Double = 0.0 // 👈 新增 CBF 金额参数
    ) {
        self.merchant = merchant
        self.category = category
        self.location = location
        self.amount = amount
        self.date = date
        self.card = card
        self.paymentMethod = paymentMethod
        self.isOnlineShopping = isOnlineShopping
        self.isCBFApplied = isCBFApplied
        self.isCreditTransaction = isCreditTransaction // 👈 赋值
        self.receiptData = receiptData
        self.billingAmount = billingAmount ?? amount
        self.cbfAmount = cbfAmount
        
        let finalBilling = billingAmount ?? amount
        
        // 1. 记录名义费率 (用于界面显示，比如 "5%")
        // 这里依然调用 getRate，得到的是 "基础+加成" 的理论总费率
        let nominalRate = card?.getRate(for: category, location: location) ?? 0
        self.rate = nominalRate
        
        // 2. 确定实际返现额 (优先使用传入的计算结果)
        // 🔥 如果是信用交易（还款/退款），返现金额强制为 0
        if isCreditTransaction {
            self.cashbackamount = 0.0
        } else if let providedCashback = cashbackAmount {
            // 如果外部传了（也就是经过了上限计算），就用外部的
            self.cashbackamount = providedCashback
        } else {
            // 兜底：如果没传，就按简单的 费率*金额 算 (兼容旧代码)
            self.cashbackamount = finalBilling * nominalRate
        }
    }
    
    var color: Color { category.color }
    var dateString: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd" // 你可以改成 "yyyy-MM-dd" 或 "MM月dd日"
            return formatter.string(from: date)
        }
}
