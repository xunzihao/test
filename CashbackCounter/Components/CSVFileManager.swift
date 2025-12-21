//
//  CSVFileManager.swift
//  CashbackCounter
//
//  Created by Assistant.
//

import Foundation
import OSLog

/// 通用的 CSV 文件管理工具
struct CSVFileManager {
    private static let logger = Logger.category("CSVFileManager")

    /// 将 CSV 内容保存到临时文件
    /// - Parameters:
    ///   - content: CSV 文本内容
    ///   - prefix: 文件名前缀
    /// - Returns: 文件 URL（如果成功）
    static func saveCSV(content: String, prefix: String) -> URL? {
        // 添加 BOM 头，确保 Excel 能正确识别 UTF-8
        let bom = AppConstants.CSV.bom
        let fullContent = bom + content
        
        // 生成带时间戳的文件名
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.DateConstants.csvFileNameFormat
        let dateString = formatter.string(from: Date())
        
        let fileName = "\(prefix)\(dateString)\(AppConstants.CSV.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try fullContent.write(to: tempURL, atomically: true, encoding: .utf8)
            logger.info("CSV 文件已保存至: \(tempURL.path)")
            return tempURL
        } catch {
            logger.error("CSV 保存失败: \(error.localizedDescription)")
            return nil
        }
    }
}
