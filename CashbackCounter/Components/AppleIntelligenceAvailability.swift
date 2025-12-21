//
//  AppleIntelligenceAvailability.swift
//  CashbackCounter
//
//  Created by Assistant on 11/24/25.
//

import Foundation
import SwiftUI
import Combine
import OSLog

@MainActor
final class AppleIntelligenceAvailability: ObservableObject {
    @Published private(set) var isSupported: Bool = false
    @Published var showCompatibilityAlert: Bool = false
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? AppConstants.General.bundleName, category: "AppleIntelligenceAvailability")

    func refreshSupportStatus() {
        let supported: Bool
        if #available(iOS 18.0, *) {
            // 这里还可以添加更多检查，比如设备型号是否支持 NPU
            // 目前仅检查系统版本
            supported = true
        } else {
            supported = false
        }

        if isSupported != supported {
            isSupported = supported
            logger.info("Apple Intelligence 支持状态更新: \(supported)")
        }
        
        // 如果状态从未支持变为支持，或者反之，可以在这里处理
        // 目前 showCompatibilityAlert 的逻辑是：如果不支持，则显示 Alert (通常由 UI 触发调用)
        showCompatibilityAlert = !supported
    }
}
