//
//  Logger+Extension.swift
//  CashbackCounter
//
//  Created by Assistant.
//

import OSLog
import Foundation

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? AppConstants.General.bundleName

    /// 创建指定类别的 Logger
    static func category(_ category: String) -> Logger {
        return Logger(subsystem: subsystem, category: category)
    }
}
