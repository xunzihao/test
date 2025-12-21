//
//  AppConstants.swift
//  CashbackCounter
//
//  Created by Assistant.
//

import Foundation
import CoreGraphics

struct AppConstants {
    struct General {
        static let appName = "Cashback Counter"
        static let bundleName = "CashbackCounter"
        static let cancel = "取消"
        static let confirm = "确定"
        static let edit = "编辑"
        static let delete = "删除"
        static let reset = "重置"
        static let ok = "好的"
        static let close = "关闭"
        static let save = "保存"
        static let done = "完成"
        static let error = "错误"
        static let unknownError = "未知错误"
        static let iKnow = "我知道了"
        static let selectPlease = "请选择"
        static let notSelected = "未选择"
        static let none = "无"
        static let other = "其他"
        static let all = "全部"
        static let importResult = "导入结果"
        static let importSuccess = "导入成功！"
        static let importFailed = "导入失败：格式错误或文件损坏。\n%@"
    }
    
    struct Accessibility {
        static let creditTransaction = "Credit Transaction"
        static let cashback = "Cashback"
    }
    
    struct Home { // BillHomeView
         static let updatingRates = "正在更新汇率..."
         static let rateUpdateFailed = "汇率获取失败，已使用 1.0 作为默认值"
         static let totalPrefix = "总"
         static let thisYearPrefix = "本年"
         static let thisMonthPrefix = "本月"
         static let cardFilter = "卡片筛选"
         static let allBills = "全部账单"
         static let yearlyBills = "年度账单"
         static let monthlyBills = "月度账单"
         static let filterCards = "筛选卡片"
         static let exportBill = "导出账单"
         static let importCSV = "导入 CSV 文件"
         static let refreshRates = "刷新汇率"
         static let seeHomeTopRight = "见首页右上角"
    }
    
    struct Settings {
        static let notificationFooter = "开启后，将在每月还款日上午 9:00 推送提醒。"
        static let noCardsForNotification = "暂无卡片，请先添加信用卡"
        static let repaymentNotificationTitle = "还款提醒"
        static let repaymentDayFormat = "每月 %d 日还款"
        static let noRepaymentDaySet = "未设置还款日"
        static let settings = "设置"
        static let resetDataConfirmation = "⚠️ 确定要清空所有数据吗？"
        static let confirmReset = "确认清空"
        static let resetDataWarning = "此操作将删除所有交易记录和卡片信息，且无法恢复（iCloud 同步也会被清空）。"
        
        static let appearanceAndLanguage = "外观与语言"
        static let theme = "主题模式"
        static let followSystem = "跟随系统"
        static let lightMode = "浅色模式"
        static let darkMode = "深色模式"
        static let language = "语言设置"
        static let zhHans = "简体中文"
        static let zhHant = "繁體中文"
        static let english = "English"
        
        static let general = "常规"
        static let multiCurrencySupport = "更多货币支持正在开发中..."
        static let multiCurrencySettings = "多币种设置"
        static let notifications = "通知提醒"
        
        static let dataManagement = "数据管理"
        static let iCloudSync = "iCloud 同步 (自动开启)"
        static let dataImportExport = "数据导入/导出"
        
        static let aboutApp = "关于 Cashback Counter"
        static let version = "版本"
        static let versionPrefix = "Version"
        static let developer = "开发者: Junhao Huang"
        static let projectHomepage = "项目主页"
        
        static let resetAllData = "重置所有数据 (慎用)"
        static let repaymentSwitchLabel = "开启提醒"
    }
    
    struct Card {
        static let myWallet = "我的卡包"
        static let noCards = "暂无卡片"
        static let addFirstCard = "点击右上角 + 添加您的第一张信用卡"
        static let editCard = "编辑卡片"
        static let deleteCard = "删除卡片"
        static let addFromTemplate = "从模板添加"
        static let addCustom = "自定义添加"
        static let exportCards = "导出卡片"
        static let importCards = "导入卡片"
        static let selectCardTemplate = "选择卡片模板"
        static let adjustCardImage = "调整卡面图片"
        static let adjustImageInstruction = "使用双指缩放和拖动来调整图片"
        static let scaleFormat = "缩放: %d%%"
        static let zoomIn = "放大"
        static let zoomOut = "缩小"
        static let fit = "适应"
        
        static let cardInfo = "卡片信息"
        static let cardName = "卡名称"
        static let cardLastFour = "卡号后四位"
        static let matchCard = "匹配卡片"
        static let selectCard = "选择卡片"
        
        static let addCreditCard = "添加信用卡"
        static let downloadingCardImage = "正在下载卡面图片..."
        static let downloadedPercent = "已下载 %d%%"
        static let bankNameDefault = "银行名称"
        static let basicInfo = "基本信息"
        static let cardNameLabel = "卡片名称"
        static let bankNamePlaceholder = "银行 (如: 招商银行)"
        static let cardOrganization = "卡组织"
        static let cardLevel = "卡等级"
        static let issueRegion = "发行地区"
        static let lastFourDigits = "后四位"
        static let ftfLabel = "FTF"
        static let ftfDescription = "外币交易兑换费"
        static let exemptFTFCurrencies = "免 FTF 币种"
        static let cbfLabel = "CBF"
        static let cbfDescription = "跨境港币交易费"
        static let repaymentReminderMonthly = "还款日提醒 (每月)"
        static let enableRepaymentReminder = "开启还款提醒"
        static let reminderMessage = "将在每月 %d 日发送提醒"
        static let cardFaceManagement = "卡面管理"
        static let changeCardFace = "更换卡面"
        static let addCardFace = "添加卡面"
        static let baseCashbackAll = "基础返现 (所有消费)"
        static let addCondition = "添加条件"
        static let cashbackRateLabel = "返现率"
        static let monthlyCapLabel = "月度上限"
        static let unlimited = "无限制"
        static let yearlyCapLabel = "年度上限"
        static let activityCashback = "活动返现"
        static let activityLabel = "活动"
        static let customNamePlaceholder = "自定义名称"
        static let capLabel = "上限"
        static let pleaseAddActivity = "请添加活动"
        static let pulseKeyword = "pulse"
    }
    
    struct Transaction {
        static let creditTransactionLabel = "CR"
        static let cashbackPrefix = "返现"
        static let unfillPaymentMethod = "未填写"
        static let deletedCard = "已删除卡片"
        static let noCard = "无卡"
        static let onlineShopping = "网购"
        static let offlineShopping = "线下购物"
        static let unionPayQR = "银联二维码"
        static let applePay = "Apple Pay"
        static let refund = "退款"
        static let repayment = "还款"
        static let cbf = "CBF"
        static let sale = "SALE"
        static let noTransactions = "暂无账单"
        static let noTransactionsDescription = "该时间段内没有交易记录" // or "此卡片暂无交易记录" depending on context, using the first one
        static let latestTransactions = "最新交易"
        static let exportTransactions = "导出交易"
        
        static let transactionRecords = "交易记录"
        static let calculatingCashback = "计算返现中..."
        static let estimatedTotalCashback = "预计总返现"
        static let transactionCount = "消费笔数"
        static let cashbackDisclaimer = "返现金额已考虑所选卡片的返现规则和上限"
        static let cashbackStats = "返现统计"
        static let editTransaction = "编辑交易"
        static let foreignCurrencyInfo = "外币信息"
        static let foreignCurrencyType = "外币币种"
        static let foreignCurrencyAmount = "外币金额"
        
        // Transaction Detail
        static let unknownBank = "未知银行"
        static let unknownCard = "----"
        static let transactionTime = "交易时间"
        static let paymentCard = "支付卡片"
        static let cardTailNumber = "卡片尾号"
        static let billingAmount = "入账金额"
        static let transactionRegion = "消费地区"
        static let paymentMethodLabel = "支付方式"
        static let onlineShoppingLabel = "网上购物"
        static let isAppliedCBF = "适用 CBF"
        static let currentCashback = "本单返现"
        static let actualTotalCost = "实际总成本"
        static let billing = "入账"
        static let cbfExclusionNote = "💡 CBF 费用不参与返现计算"
        static let electronicReceipt = "电子收据"
        static let electronicReceiptPreview = "电子收据预览，点击全屏查看"
        
        // AddTransactionView
        static let addTransactionTitle = "记一笔"
        static let editTransactionTitle = "编辑账单"
        static let aiNewPhotoDetected = "📸 检测到新照片，触发 AI 分析"
        static let aiAnalyzingReceipt = "🔍 开始 AI 分析收据..."
        static let consumptionDetails = "消费详情"
        static let merchantNamePlaceholder = "商户名称"
        static let consumptionCurrency = "消费币种"
        static let consumptionAmount = "消费金额"
        static let consumptionCategory = "消费类别"
        static let consumptionRegion = "消费地区"
        static let currencyMismatch = "消费币种(%@)与地区(%@)不一致"
        static let transactionAttributes = "交易属性"
        static let isCBFAppliedQuestion = "适用CBF？"
        static let receiptEvidence = "收据凭证"
        static let aiAnalyzing = "AI 分析中..."
        static let deleteImage = "删除图片"
        static let reupload = "重新上传"
        static let uploadReceiptImage = "上传收据图片"
        static let pleaseAddCreditCard = "请先添加信用卡"
        static let selectCreditCard = "选择信用卡"
        static let billingAmountWithCurrency = "入账金额 (%@)"
        static let actualDeduction = "实际扣款"
        static let consumptionDate = "消费日期"
        static let cashbackRules = "返现规则"
        static let selectCashbackRule = "选择返现规则"
        static let autoMatch = "自动匹配"
        static let usingRule = "使用规则"
        static let rulePrefix = "规则: %@"
        static let cashbackCalculation = "返现计算"
        static let enterConsumptionAmount = "请输入消费金额"
        static let noCashbackForThisTransaction = "此类交易不计算返现"
        static let finalCashback = "最终返现"
        static let cbfFeeNotCounted = "CBF 费用（不计入返现）"
        static let actualCost = "实际成本"
        
         // AddTransactionToStatementView
        static let addTransactionAction = "添加交易"
        static let add = "添加"
        static let removeCBFFee = "移除 CBF 费用"
        static let transactionParticipatesCashback = "添加的交易会参与返现计算"
        
        static let transactionTypeNote = "您可以随时更改某笔交易是否为线上交易或线下交易"
        static let consumptionCurrencyLabel = "消费币种"
        static let enterCurrency = "请输入币种"
        static let consumptionMethodLabel = "消费方式"
        static let enterMethod = "请输入方式"
        static let onlineTransaction = "线上交易"
        static let offlineTransaction = "线下交易"
        static let unlimitedTransaction = "不限"
        static let consumptionCurrencyMulti = "消费币种 (可多选)"
        static let consumptionMethodMulti = "消费方式 (可多选)"
    }
    
    struct StatementAnalysis {
        static let monthlyStatementAnalysis = "月账单分析"
        static let importAction = "导入"
        static let pulseWarningTitle = "汇丰 Pulse 卡提醒"
        static let pulseWarningMessage = "若您上传的是汇丰 Pulse 信用卡的结单，请注意本 App 不能很好地处理此结单。\n\n建议：请分别截图并使用图片分析，分别记录到不同的子账户中。"
        static let pdfConversionFailed = "PDF 转换失败：无法提取页面"
        static let pdfProcessingFailed = "PDF 处理失败: %@"
        static let analysisFailed = "分析失败: %@"
        static let pageAnalysisFailed = "❌ 第 %d 页分析失败: %@"
        static let pageAnalysisProgress = "正在分析第 %d / %d 页..."
        static let statementAnalysisProgress = "正在分析账单..."
        static let importFailed = "导入失败: %@"
        static let selectImageOrPDF = "请选择账单图片或 PDF 文件进行分析"
        static let selectFromPhotoLibrary = "从相册选择"
        static let selectPDFFile = "选择 PDF 文件"
        static let allPages = "所有页面 (%d 页)"
        static let reselectImage = "重选图片"
        static let reselectPDF = "重选 PDF"
        static let pageNumber = "第 %d 页"
        static let pdfLoaded = "PDF 已加载 %d 页"
        static let clickToStartAnalysis = "点击下方按钮开始分析"
        static let clickToStartStatementAnalysis = "点击下方按钮开始分析账单"
        static let startAnalysis = "开始分析"
        static let statementDate = "结单日期"
        
        // Edit View & Row
        static let postingDatePrefix = "记账: %@"
        static let transactionDatePrefix = "交易: %@"
        static let merchantInfoSection = "商户信息"
        static let merchantNameField = "商户名称"
        static let transactionAmountSection = "交易金额"
        static let amountField = "金额"
        static let cbfFeeLabel = "CBF 费用"
        static let cbfField = "CBF"
        static let addCbfFeeAction = "添加 CBF 费用"
        static let postingDateField = "记账日期"
        static let transactionDateField = "交易日期"
        static let paymentMethodField = "支付方式"
        static let currencyHKD = "HKD"
    }
    
    struct Trend {
        static let expense = "支出"
        static let cashback = "返现"
        static let expenseAnalysis = "支出分析"
        static let cashbackAnalysis = "返现分析"
        static let totalTrend = "总%@趋势"
        static let cardTrend = "%@ %@趋势"
        static let cumulative12Months = "近12个月累计"
        static let noData = "暂无数据"
        static let monthLabel = "月份"
        static let amountLabel = "金额"
        static let allCards = "全部卡片"
        static let showAllTransactions = "显示所有卡片的交易记录"
        static let selectCardToViewDetail = "选择卡片查看详情"
    }
    
    struct TabBar {
        static let bill = "账单"
        static let analysis = "结单"
        static let camera = "拍一笔"
        static let card = "卡包"
        static let settings = "设置"
    }
    
    struct AI {
        static let compatibilityModeEnabled = "兼容模式已启用"
        static let compatibilityMessage = "当前设备暂不支持 Apple Intelligence，已为你切换为手动输入模式。"
        static let imageSaved = "图片已保存"
        static let fileSelectionFailed = "选择文件失败: %@"
        
        static let instructions = """
        You are an expert receipt data extractor.
        
        Your job is to analyze the OCR text and extract key details into a structure.
        
        CRITICAL RULES FOR MERCHANT NAME extraction:
        - You can use Chinese, Japanese, English to get the MERCHANT NAME
        - The MERCHANT NAME is usually at the top left corner.
        
        CRITICAL RULES FOR AMOUNT extraction:
        - You must extract the FINAL PAID amount (实付金额/合计/Total).
        - If there are discounts (立减/优惠/Discount), DO NOT use the subtotal (原价/小计). Use the final amount AFTER discount.
        - DO NOT add the discount to the total. DO NOT sum up numbers yourself.
        - Usually is the biggest one
        - Look for keywords like:
          - English: 'Total', 'Amount Due'
          - Chinese: '实付', '已支付', '合计'
          - Japanese: '合計', '合計', 'お支払い', '請求金額', '税込'
        
        CRITICAL RULES FOR FOREIGN CURRENCY (外币金额):
        - ONLY extract billingAmount if the receipt EXPLICITLY shows TWO DIFFERENT amounts with different currencies.
        - Look for these specific patterns:
          • '外币金额 XXX CNY, 记账金额 YYY HKD' → totalAmount=XXX, billingAmount=YYY
          • 'Foreign Amount: 1000 JPY, Billing Amount: 88.50 HKD' → totalAmount=1000, billingAmount=88.50
        - If the receipt shows BOTH amounts with DIFFERENT currencies:
          1. totalAmount = The FOREIGN currency amount (外币金额/交易金额)
          2. currency = The FOREIGN currency code (e.g., CNY, JPY)
          3. billingAmount = The BILLING amount (记账金额/入账金额)
          4. billingCurrency = The CARD's home currency (e.g., HKD, USD)
          5. exchangeRate = The exchange rate if shown (汇率/Exchange Rate/兑换率)
        
        - Keywords for detecting dual-currency receipts:
          - Foreign amount: '外币金额', 'Foreign Amount', '外幣金額'
          - Billing amount: '记账金额', '入账金额', 'Billing Amount', '記賬金額'
          - Exchange rate: '汇率', '兑换率', 'Exchange Rate', '匯率', 'Rate'
        
        - ❌ DO NOT extract billingAmount if:
          • Only ONE amount appears on the receipt (e.g., 'RMB 1000.00' only)
          • Only ONE currency appears (e.g., only CNY, only JPY)
          • No exchange rate is shown AND no explicit '入账金额' field exists
          • The receipt is a simple domestic transaction
        
        - ✅ Example of SINGLE currency (billingAmount = nil):
          Receipt: '交易金额: RMB 1000.00'
          → totalAmount=1000, currency='CNY', billingAmount=nil, billingCurrency=nil
        
        - ✅ Example of DUAL currency (billingAmount filled):
          Receipt: '外币金额: JPY 5000, 汇率: 0.0885, 入账金额: HKD 442.50'
          → totalAmount=5000, currency='JPY', billingAmount=442.5, billingCurrency='HKD', exchangeRate=0.0885
        
        - IMPORTANT: Extract the exchange rate EXACTLY as shown. Do NOT calculate it yourself.
        
        CRITICAL RULES FOR CATEGORIZATION:
        - Analyze the merchant name and items purchased.
        - 'dining': Restaurants, Cafes, Starbucks, Izakaya (居酒屋), Ramen (ラーメン).
        - 'grocery': Supermarkets, 7-Eleven, Lawson, FamilyMart, Daily necessities.
        - 'travel': Uber, Taxi, Flights, Hotels, Suica, Pasmo, Shinkansen (新幹線).
        - 'digital': Electronics, Apple Store, Yodobashi, Bic Camera.
        - 'other': Anything that doesn't fit above.
        
        CRITICAL RULES FOR PAYMENT METHOD detection:
        - Analyze the receipt text to detect the payment method used.
        - Map to these EXACT values (case-sensitive):
          • 'Apple Pay' if text contains: 'Apple Pay', 'APPLE PAY', 'ApplePay', '苹果支付', 'アップルペイ'
          • '银联二维码' if text contains: 'QR', '二维码', '扫码', '云闪付', 'QuickPass', 'UnionPay QR', 'QRコード'
          • '网购' if text contains: '网购', '在线支付', 'Online Payment', 'E-commerce', 'オンライン'
          • '线下购物' for physical store purchases (default for most paper receipts)
          • nil if cannot determine with confidence
        - Examples:
          Receipt: 'Apple Pay ***1234' → paymentMethod='Apple Pay'
          Receipt: '云闪付二维码支付' → paymentMethod='银联二维码'
          Receipt: '淘宝订单' → paymentMethod='网购'
          Receipt: normal store receipt with no online/QR indicators → paymentMethod='线下购物'
        
        Rules:
        - Extract exact values for merchant, amount, card ending number, merchant category, and date.
        - Infer currency from symbols (¥, $, JPY) or location (e.g. Tokyo -> JPY).
        - If a value is missing, leave it nil.
        """
         static let SMSinstructions = """
             You are an expert SMS notification data extractor for credit card transactions.
             
             Your job is to analyze credit card SMS notifications and extract key transaction details.
             If you are not sure about any field, return nil for that field.
             
             CRITICAL RULES FOR MERCHANT NAME extraction:
             - Extract the merchant/store name from the SMS
             - Can be in Chinese, Japanese, English, or other languages
             - Look for keywords like: '在...消费', 'at', '於', '商户'
             
             CRITICAL RULES FOR AMOUNT extraction:
             - Extract the TRANSACTION amount (not the remaining balance)
             - Look for keywords: '消费', '支出', 'spent', 'paid', '金额'
             - Example: '消费人民币123.45元' → 123.45
             
             CRITICAL RULES FOR CURRENCY detection:
             - MUST extract the actual currency from the SMS text
             - Look for currency indicators:
               • CNY/RMB/人民币 → currency='CNY'
               • USD/美元/美金 → currency='USD'
               • HKD/港币/港元 → currency='HKD'
               • JPY/日元/円 → currency='JPY'
               • NZD/纽币 → currency='NZD'
               • TWD/新台币 → currency='TWD'
             - Example: '您尾号1234的卡消费人民币500元' → currency='CNY'
             - Example: 'Your card ending 1234 spent USD 50.00' → currency='USD'
             - If currency not mentioned, return nil
             
             CRITICAL RULES FOR BILLING AMOUNT (入账金额):
             - Some SMS shows BOTH foreign amount AND billing amount
             - Look for keywords:
               • '入账金额', '记账金额', 'billing amount'
               • '折算', '折合'
             - Example: '消费美元100.00，入账人民币720.50元' → totalAmount=100.0, currency='USD', billingAmount=720.5, billingCurrency='CNY'
             - If only one amount appears, billingAmount should be nil
             
             CRITICAL RULES FOR CARD LAST 4 DIGITS:
             - Extract the last 4 digits of the card number
             - Look for: '尾号', 'ending', '末4位', 'last 4'
             - Example: '您尾号1234的卡' → cardLast4='1234'
             
             CRITICAL RULES FOR CATEGORIZATION:
             - Analyze the merchant name to categorize
             - 'dining': Restaurants, Cafes, food delivery (美团/饿了么), Starbucks
             - 'grocery': Supermarkets, convenience stores (7-11/全家/罗森)
             - 'travel': Transportation (滴滴/Uber), hotels, flights, metro
             - 'digital': Online shopping (淘宝/京东/Amazon), App Store, electronics
             - 'other': Cannot determine or doesn't fit above
             
             Example SMS:
             '您尾号1234的招商银行信用卡于12月19日在STARBUCKS消费人民币45.00元，当前可用额度10000.00元。'
             → merchant='STARBUCKS', totalAmount=45.0, currency='CNY', cardLast4='1234', category='dining'
         """
    }
    
    struct Notification {
        static let repaymentTitlePrefix = "还款提醒: "
        static let repaymentBody = "今天是您的信用卡还款日，请及时还款以免逾期。"
    }

    struct DateConstants {
        static let selectTime = "选择时间"
        static let yearSuffix = "年"
        static let monthSuffix = "月"
        static let wholeYear = "全年"
        static let yearLabel = "Year"
        static let monthLabel = "Month"
        static let csvFileNameFormat = "yyyyMMdd_HHmmss"
    }
    
    struct Keys {
        static let userTheme = "userTheme"
        static let userLanguage = "userLanguage"
        static let cachedExchangeRates = "cached_exchange_rates"
    }
    
    struct API {
        static let frankfurterUrl = "https://api.frankfurter.app/latest"
    }
    
    struct Logs {
        static let appInitComplete = "App 启动初始化完成"
    }
    
    struct CSV {
        static let header = "交易时间,商户名称,消费类别,消费金额(原币),入账金额(本币),返现金额(本币),名义费率(%),支付卡片,卡片尾号,消费地区,支付方式,是否网购,适用CBF,CBF金额,是否为退款/返现交易\n"
        static let cardHeader = "银行名称,卡组织,卡等级,尾号,地区,基础返现(%),月度上限,年度上限,餐饮加成(%),超市加成(%),出行加成(%),数码加成(%),其他加成(%),餐饮上限,超市上限,出行上限,数码上限,其他上限,还款日"
        static let yes = "是"
        static let no = "否"
        static let transactionFileNamePrefix = "Cashback_Export_"
        static let cardFileNamePrefix = "Cards_Backup_"
        static let fullWidthComma = "，"
        static let bom = "\u{FEFF}"
        static let fileExtension = ".csv"
    }
    
    struct CashbackDetail {
        static let originalAmount = "原币金额: %@"
        static let exchangeRateConversion = "汇率转换: %@ × %@ = %@"
        static let ftfFee = "FTF费用: %@ × %@%% = %@"
        static let billingAmount = "入账金额: %@ × (1 + %@%%) = %@"
        static let exchangeRateConversionNoFTF = "汇率转换: %@ × %@ = %@（免FTF）"
        static let billingAmountNoConversion = "入账金额: %@（无需转换）"
        static let usingRuleManual = "使用规则: 规则%d（手动选择）"
        static let baseCashbackRate = "基础返现率: %@%%"
        static let usingRuleAuto = "使用规则: 规则%d（自动匹配，基于币种: %@）"
        static let noRuleMatched = "⚠️ 未匹配到任何返现规则"
        static let cashbackAmountZero = "返现金额: 0.00 %@"
        static let categoryBonus = "类别加成: %@%%"
        static let totalRateCalculation = "总返现率: %@%% + %@%% = %@%%"
        static let totalRate = "总返现率: %@%%"
        static let theoreticalCashback = "理论返现: %@ × %@ = %@"
        static let cappedFinalCashback = "⚠️ 受上限限制，最终返现: %@"
        static let finalCashback = "最终返现: %@"
        static let cbfFeeTitle = "💳 CBF 费用（跨境港币交易费）"
        static let cbfRate = "CBF 费率: %@%%"
        static let cbfAmount = "CBF 金额: %@ × %@%% = %@"
        static let cbfNote = "⚠️ 注意：CBF 不参与返现计算"
        static let totalCost = "总成本: %@ + %@ = %@"
        static let defaultRule = "默认规则"
        static let unlimited = "不限"
        static let ruleFormat = "规则%d: %@ (%@%%)"
    }
    
    struct Intent {
        static let title = "从信用卡通知短信添加交易"
        static let description = "解析短信内容并新增一笔消费记录"
        static let parameterTitle = "短信全文"
        static let parameterRequestDialog = "请粘贴信用卡短信内容"
        static let parameterSummary = "解析短信文本 ${smsText}"
        
        static let errorDomain = "AddTransactionFromSMSIntent"
        static let errorEmptyText = "请提供短信文本"
        static let errorMissingInfo = "缺少商户、金额或类别信息"
        static let successResultPrefix = "已成功添加账单："
    }
    
    struct ErrorMessages {
        static let invalidURL = "无效的 URL"
        static let downloadErrorPrefix = "下载出错："
        static let serverErrorPrefix = "下载失败：服务器返回错误"
        static let tempFileError = "下载失败：无法获取临时文件"
        static let parseError = "无法解析图片数据"
        static let fileReadErrorPrefix = "读取文件出错："
        static let downloadCancelled = "下载已取消"
        static let visionError = "Vision 请求内部错误: %@"
        static let visionHandlerError = "Vision Handler 执行失败: %@"
        static let ocrError = "OCR 文本提取失败: %@"
        static let cgImageError = "无法获取 CGImage"
    }
    
    struct OCR {
        static let unionPayQRChinese = "银联二维码"
        static let applePay = "Apple Pay"
        static let unionPayQREnglish = "UNIONPAY QR"
        static let paidByAutopay = "PAID BY AUTOPAY"
        static let autoRepayment = "自动还款"
        static let repayment = "IFS PAYMENT"
        static let mobInstalment = "MOB INSTALMENT"
        static let instalment = "分期"
        static let cbfFee = "DCC FEE NON-HK MERCHANT"
        static let sale = "SALE"
        
        static let postDate = "POST DATE"
        static let transDate = "TRANS DATE"
        static let postingDateCN = "記賬日期"
        static let transDateCN = "交易日期"
        
        static let rewardCash = "REWARDCASH"
        static let summary = "SUMMARY"
        static let points = "积分"
        static let rewardCashCN = "奖赏钱"
        
        static let pulse = "PULSE"
        static let cardType = "CARD TYPE"
        static let statementDate = "STATEMENT DATE"
        static let statementDateCN = "结单日"
        
        static let headerKeywords = ["POST", "TRANS", "DATE", "DESCRIPTION OF TRANSACTION"]
        static let footerKeywords = ["NOTE", "CR", "REWARDCASH"]
        static let ignoreKeywords = ["HSBC", "STATEMENT OF", "PAGE"]
        static let supportedLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        
        struct PaymentDetection {
            static let applePay = ["APPLE PAY", "APPLEPAY", "苹果支付", "アップルペイ"]
            static let unionPayQR = ["二维码", "QR", "扫码", "云闪付", "QUICKPASS", "UNIONPAY QR", "QRコード", "スキャン"]
            static let online = ["网购", "在线支付", "ONLINE", "淘宝", "天猫", "京东", "美团", "饿了么", "拼多多", "E-COMMERCE", "オンライン", "Online Payment"]
            static let physicalStore = ["收银", "店铺", "门店", "STORE", "SHOP", "RECEIPT", "レシート"]
            static let autoRepayment = ["PAID BY AUTOPAY", "自动还款"]
            static let repayment = ["IFS PAYMENT"]
            static let instalment = ["MOB INSTALMENT", "分期"]
            static let cbf = ["DCC FEE NON-HK MERCHANT"]
            static let refund = ["退款", "REFUND", "CREDIT"]
            static let candidates = [
                "网购",
                "Apple Pay",
                "银联二维码",
                "线下购物",
                "退款",
                "还款",
                "分期",
                "SALE",
                "CBF",
                "自动还款",
                "未填写"
            ]

        }
        struct Camera {
            static let dragToImport = "松手导入图片"
            static let wideAngle = "广角"
            static let ultraWide = "超广角"
            static let telephoto = "长焦"
            static let camera = "相机"
        }
        struct RegionDetection {
            static let jpCurrency = ["JPY", "円"]
            static let jpKeywords = ["合計", "料金"]
            
            static let hkCurrency = ["HKD", "HK$"]
            static let hkKeywords = ["HONG KONG"]
            
            static let twCurrency = ["TWD", "NT$"]
            static let twKeywords = ["TAIPEI", "台灣"]
            
            static let nzCurrency = ["NZD"]
            
            static let cnCurrency = ["CNY", "RMB", "人民币"]
            static let cnKeywords = ["金额", "交易"]
            
            static let usCurrency = ["USD"]
            static let usKeywords = ["USA", "US$"]
        }
    }
    
    struct Languages {
        static let zhHans = "zh-Hans"
        static let enUS = "en-US"
        static let jaJP = "ja-JP"
        static let zhHant = "zh-Hant"
    }

    struct Currency {
        static let cny = "CNY"
        static let hkd = "HKD"
        static let nzd = "NZD"
        static let usd = "USD"
        static let jpy = "JPY"
        static let mop = "MOP"
        static let twd = "TWD"
        static let krw = "KRW"
        static let otherCurrency = "OTHER"
        
        static let all = [
            "USD", "EUR", "GBP", "JPY", "CNY", "RMB", "HKD",
            "AUD", "NZD", "SGD", "KRW", "TWD", "MOP",
            "THB", "MYR", "PHP", "IDR", "VND",
            "CAD", "CHF", "SEK", "NOK", "DKK",
            "MXN", "BRL", "ARS", "CLP",
            "ZAR", "AED", "SAR", "RUB", "TRY"
        ]
    }
    struct ImageCropperParameter {
        static let defaultCardAspectRatio: CGFloat = 1.586
        static let minScale: CGFloat = 0.1
        static let maxScale: CGFloat = 3.0
        static let cropPadding: CGFloat = 40.0
        static let cornerMarkerLength: CGFloat = 20.0
        static let cornerMarkerThickness: CGFloat = 3.0
    }

    struct Config {
        static let appGroupId = "group.testgroup.cashback"
        static let cameraSessionQueue = "com.cashbackcounter.camera.sessionQueue"
        static let imageCacheDirectory = "DownloadedImages"
        static let defaultImageName = "image"
    }

}
