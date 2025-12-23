//
//  TemplateLoader.swift
//  CashbackCounter
//
//  Created by Assistant.
//

import Foundation
import OSLog

struct TemplateLoader {
    private static let logger = Logger(subsystem: "CashbackCounter", category: "TemplateLoader")
    
    /// 从 Bundle 加载模板数据
    static func loadTemplates() -> [CardTemplate] {
        // 1. 尝试从 Bundle 读取 templates.json
        if let url = Bundle.main.url(forResource: "templates", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let templates = try JSONDecoder().decode([CardTemplate].self, from: data)
                logger.info("成功从 Bundle 加载 \(templates.count) 个模板")
                return templates
            } catch let DecodingError.dataCorrupted(context) {
                logger.error("数据损坏: \(context.debugDescription)")
            } catch let DecodingError.keyNotFound(key, context) {
                logger.error("找不到键 '\(key.stringValue)': \(context.debugDescription), path: \(context.codingPath)")
            } catch let DecodingError.valueNotFound(value, context) {
                logger.error("找不到值 '\(value)': \(context.debugDescription), path: \(context.codingPath)")
            } catch let DecodingError.typeMismatch(type, context) {
                logger.error("类型不匹配 '\(type)': \(context.debugDescription), path: \(context.codingPath)")
            } catch {
                logger.error("解析 templates.json 失败: \(error.localizedDescription)")
            }
        } else {
            logger.warning("未在 Bundle 中找到 templates.json")
        }
        
        return []
    }
    
    // MARK: - 开发辅助工具
    
    /// 将硬编码数据转换为 JSON 字符串（用于生成初始的 templates.json）
    /// 你可以在调试控制台调用此方法，然后把输出内容复制到文件中
    // static func generateJSONString() -> String? {
    //     let encoder = JSONEncoder()
    //     encoder.outputFormatting = [.prettyPrinted, .sortedKeys] // 格式化输出，方便阅读
        
    //     do {
    //         let data = try encoder.encode(TemplateData.hardcodedExamples)
    //         return String(data: data, encoding: .utf8)
    //     } catch {
    //         print("生成 JSON 失败: \(error)")
    //         return nil
    //     }
    // }
}
