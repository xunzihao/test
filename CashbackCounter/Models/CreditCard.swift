//
//  CreditCard.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData

@Model
class CreditCard: Identifiable {
    
    // MARK: - 基本信息
    
    var bankName: String
    var cardOrganization: CardOrganization  // 卡组织（例如：Visa、Mastercard）
    var cardLevel: CardLevel  // 卡等级（例如：白金卡、无限卡）
    var endNum: String
    var repaymentDay: Int = 0
    var isRemindOpen: Bool = true
    
    /// 外币交易兑换费（Foreign Transaction Fee）百分比
    var ftf: Double = 0.0
    
    /// 跨境港币交易费（Cross-Border HKD Fee）百分比
    var cbf: Double = 0.0
    
    /// FTF 免收币种（存 currencyCode，例如 "USD"）
    /// 规则：**选中的币种不收 FTF，其余币种都收 FTF**
    var ftfExceptCurrencyCodes: [String] = []
    
    /// 自定义卡面图片数据
    @Attribute(.externalStorage) var cardImageData: Data?

    /// 计算属性：卡种类型的显示名称（用于向后兼容）
    var type: String {
        return "\(cardOrganization.displayName) \(cardLevel.displayName)"
    }

    // MARK: - 返现率设置
    
    /// 基础返现率（例如：0.01 表示 1%）
    var defaultRate: Double
    
    /// 特殊类别返现率（加成部分，例如：餐饮额外 2%）
    var specialRates: [Category: Double]
    
    /// 发卡地区
    var issueRegion: Region
    
    /// 多返现条件支持（用于存储多个不同场景下的返现规则）
    var baseCashbackConditionsData: Data?
    
    // MARK: - 返现上限设置
    
    /// 基础返现月度上限（nil 或 0 表示无上限）
    var monthlyBaseCap: Double?
    
    /// 基础返现年度上限（nil 或 0 表示无上限）
    var yearlyBaseCap: Double?
    
    /// 类别加成年度上限（Key: 消费类别, Value: 该类别的年度加成上限）
    var categoryCaps: [Category: Double]
    
    // MARK: - 关联关系
    
    /// 关联的交易记录（删除卡片时，交易的 card 字段会被设为 nil）
    @Relationship(deleteRule: .nullify, inverse: \Transaction.card)
    var transactions: [Transaction]?
    
    // MARK: - 初始化
    
    init(
        bankName: String,
        cardOrganization: CardOrganization,
        cardLevel: CardLevel,
        endNum: String,
        defaultRate: Double,
        specialRates: [Category: Double] = [:],
        issueRegion: Region,
        monthlyBaseCap: Double? = nil,
        yearlyBaseCap: Double? = nil,
        categoryCaps: [Category: Double] = [:],
        repaymentDay: Int = 0,
        isRemindOpen: Bool = true,
        ftf: Double = 0.0,
        cbf: Double = 0.0,
        ftfExceptCurrencyCodes: [String] = [],
        cardImageData: Data? = nil
    ) {
        self.bankName = bankName
        self.cardOrganization = cardOrganization
        self.cardLevel = cardLevel
        self.endNum = endNum
        self.defaultRate = defaultRate
        self.specialRates = specialRates
        self.issueRegion = issueRegion
        self.monthlyBaseCap = monthlyBaseCap
        self.yearlyBaseCap = yearlyBaseCap
        self.categoryCaps = categoryCaps
        self.repaymentDay = repaymentDay
        self.isRemindOpen = isRemindOpen
        self.ftf = ftf
        self.cbf = cbf
        self.ftfExceptCurrencyCodes = ftfExceptCurrencyCodes
        self.cardImageData = cardImageData
    }
    
    func getRate(for category: Category, location: Region) -> Double {
        // 1. 获取类别带来的“额外”加成 (Category Bonus)
        // 使用 ?? 0.0 避免字典里没有该类别时发生崩溃
        let categoryBonus = specialRates[category] ?? 0.0
        
        // 2. 确定基础返现率
        let baseRate = defaultRate
        
        // 3. 核心修改：将基础返现率与类别加成相加
        return baseRate + categoryBonus
    }
}
