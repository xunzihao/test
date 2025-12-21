//
//  CardTemplate.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import Foundation

struct CardTemplate: Identifiable, Codable {
    let id: UUID
    let bankName: String
    let cardOrganization: CardOrganization
    let cardLevel: CardLevel
    let region: Region
    let specialRate: [Category: Double]
    let defaultRate: Double
    var monthlyCap: Int = 0
    var yearlyCap: Int = 0
    var categoryCaps: [Category: Double] = [:]
    var paymentDate: String = "0"
    var paymentMethod: String //
    var pictureURL : String?

    /// 外币交易兑换费（Foreign Transaction Fee）：百分比数值，例如 1.0 表示 1%
    var ftf: Double = 0

    /// 跨境港币交易费（Cross-Border HKD Fee）：百分比数值，例如 1.0 表示 1%
    var cbf: Double = 0

    /// FTF 免收币种（存 currencyCode，例如 "CNY"）
    /// 规则：**选中的币种不收 FTF，其余币种都收 FTF**
    var ftfExceptCurrencyCodes: [String] = []
    
    /// 计算属性：卡种类型的显示名称（用于向后兼容）
    var type: String {
        return "\(cardOrganization.displayName) \(cardLevel.displayName)"
    }
    
    // MARK: - Init
    // 提供默认初始化器，方便代码创建（保留原有用法）
    init(
        id: UUID = UUID(),
        bankName: String,
        cardOrganization: CardOrganization,
        cardLevel: CardLevel,
        region: Region,
        specialRate: [Category: Double],
        defaultRate: Double,
        monthlyCap: Int = 0,
        yearlyCap: Int = 0,
        categoryCaps: [Category: Double] = [:],
        paymentDate: String = "0",
        paymentMethod: String,
        pictureURL: String? = nil,
        ftf: Double = 0,
        cbf: Double = 0,
        ftfExceptCurrencyCodes: [String] = []
    ) {
        self.id = id
        self.bankName = bankName
        self.cardOrganization = cardOrganization
        self.cardLevel = cardLevel
        self.region = region
        self.specialRate = specialRate
        self.defaultRate = defaultRate
        self.monthlyCap = monthlyCap
        self.yearlyCap = yearlyCap
        self.categoryCaps = categoryCaps
        self.paymentDate = paymentDate
        self.paymentMethod = paymentMethod
        self.pictureURL = pictureURL
        self.ftf = ftf
        self.cbf = cbf
        self.ftfExceptCurrencyCodes = ftfExceptCurrencyCodes
    }
}
