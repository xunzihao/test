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
        // Apple Intelligence 最低系统要求是 iOS 18.1 / macOS 15.1
        guard #available(iOS 18.0, *) else {
            updateStatus(supported: false)
            return
        }
        
        // 检查硬件支持 (A17 Pro 或 M1 及以上)
        let hardwareSupported = checkHardwareSupport()
        updateStatus(supported: hardwareSupported)
    }
    
    private func updateStatus(supported: Bool) {
        if isSupported != supported {
            isSupported = supported
            logger.info("Apple Intelligence 支持状态更新: \(supported)")
        }
        showCompatibilityAlert = !supported
    }

    private func checkHardwareSupport() -> Bool {
        // 1. 获取设备标识符
        var size: size_t = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        let identifier = String(cString: machine)
        
        logger.debug("当前设备标识符: \(identifier)")
        
        return isDeviceSupported(identifier: identifier)
    }

    private func isDeviceSupported(identifier: String) -> Bool {
        // iPhone
        if identifier.hasPrefix("iPhone") {  
            let versionString = identifier.dropFirst("iPhone".count)
            guard let commaIndex = versionString.firstIndex(of: ",") else { return false }
            
            let majorString = versionString[..<commaIndex]
            let minorString = versionString[versionString.index(after: commaIndex)...]
            
            guard let major = Int(majorString), let minor = Int(minorString) else { return false }
            
            if major >= 17 { return true } // iPhone 16 及以后
            if major == 16 {
                return minor == 1 || minor == 2
            }
            return false
        }
        return false
    }
}
