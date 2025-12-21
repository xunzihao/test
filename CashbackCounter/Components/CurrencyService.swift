//
//  CurrencyService.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import Foundation
import OSLog

// 1. 定义 API 响应结构 (保持不变)
struct FrankfurterLatestResponse: Codable {
    let amount: Double
    let base: String
    let date: String
    let rates: [String: Double]
}

// 使用 Actor 管理内存缓存，确保线程安全
actor CurrencyCache {
    static let shared = CurrencyCache()
    private var memCache: [String: CurrencyService.CachedRates] = [:]
    
    func get(_ base: String) -> CurrencyService.CachedRates? {
        return memCache[base]
    }
    
    func set(_ rates: CurrencyService.CachedRates, for base: String) {
        memCache[base] = rates
    }
}

struct CurrencyService {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CashbackCounter", category: "CurrencyService")

    // --- 缓存配置 ---
    private static let kRatesKey = AppConstants.Keys.cachedExchangeRates // 存汇率数据的 Key
    private static let cacheValidity: TimeInterval = 5 * 60 // 🆕 5分钟缓存

    struct CachedRates: Codable, Sendable {
        let base: String
        let fetchedAt: Date
        let rates: [String: Double]
    }

    // --- 🚀 智能入口：获取汇率 ---
    // View 层只调用这个方法，不需要关心内部逻辑
    static func getRates(base: String = AppConstants.Currency.cny) async -> [String: Double] {
        let normalizedBase = base.uppercased()
        
        // 1. 检查内存缓存 (最快)
        if let memCached = await CurrencyCache.shared.get(normalizedBase) {
            if isValid(memCached) {
                logCacheHit(base: normalizedBase, source: "内存", cache: memCached)
                return memCached.rates
            }
        }
        
        // 2. 检查磁盘缓存 (次快)
        if let diskCached = await loadLocalRates(),
           diskCached.base.caseInsensitiveCompare(normalizedBase) == .orderedSame {
            // 更新内存缓存
            await CurrencyCache.shared.set(diskCached, for: normalizedBase)
            
            if isValid(diskCached) {
                logCacheHit(base: normalizedBase, source: "磁盘", cache: diskCached)
                return diskCached.rates
            } else {
                logger.info("⏰ 磁盘缓存已过期（已使用 \(Int(abs(diskCached.fetchedAt.timeIntervalSinceNow) / 60)) 分钟），准备重新获取")
            }
        }

        // 3. 联网获取
        logger.info("🌍 正在联网更新汇率 (base: \(normalizedBase))...")
        do {
            let rates = try await fetchRemoteRates(base: normalizedBase)
            await saveRates(rates: rates, base: normalizedBase)
            logger.info("✅ 汇率更新成功，已缓存 5 分钟")
            return rates
        } catch {
            logger.error("❌ 网络请求失败: \(error.localizedDescription)")
            
            // 4. 失败兜底：尝试使用旧缓存
            var cached = await CurrencyCache.shared.get(normalizedBase)
            if cached == nil {
                cached = await loadLocalRates()
            }
            
            if let cached = cached, cached.base.caseInsensitiveCompare(normalizedBase) == .orderedSame {
                logger.warning("⚠️ 使用过期缓存作为备用")
                return cached.rates
            }
            
            logger.warning("⚠️ 无可用缓存，返回默认汇率")
            return [normalizedBase: 1.0]
        }
    }
    
    private static func isValid(_ cache: CachedRates) -> Bool {
        return abs(cache.fetchedAt.timeIntervalSinceNow) < cacheValidity
    }
    
    private static func logCacheHit(base: String, source: String, cache: CachedRates) {
        let cacheAge = abs(cache.fetchedAt.timeIntervalSinceNow)
        let minutes = Int((cacheValidity - cacheAge) / 60)
        logger.info("✅ 汇率使用\(source)缓存（基准：\(base)，剩余有效期：\(minutes)分）")
    }
    
    /// 获取指定货币对的汇率
    static func fetchRate(from source: String, to target: String) async throws -> Double {
        if source.caseInsensitiveCompare(target) == .orderedSame { return 1.0 }

        // 1. 尝试从批量缓存中获取
        let cachedRates = await getRates(base: source)
        if let rate = cachedRates[target] {
            return rate
        }

        // 2. 兜底：单独请求 API
        logger.info("🔍 缓存未命中，单独查询 \(source) -> \(target)")
        
        var components = URLComponents(string: AppConstants.API.frankfurterUrl)
        components?.queryItems = [
            URLQueryItem(name: "from", value: source),
            URLQueryItem(name: "to", value: target)
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(FrankfurterLatestResponse.self, from: data)

        if let rate = response.rates[target] {
            return rate
        } else {
            throw URLError(.cannotParseResponse)
        }
    }

    // --- 内部方法：联网下载 (私有) ---
    private static func fetchRemoteRates(base: String) async throws -> [String: Double] {
        var components = URLComponents(string: AppConstants.API.frankfurterUrl)
        components?.queryItems = [
            URLQueryItem(name: "from", value: base)
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(FrankfurterLatestResponse.self, from: data)
        return response.rates
    }

    // --- 内部方法：存入 UserDefaults ---
    private static func saveRates(rates: [String: Double], base: String) async {
        let cache = CachedRates(base: base, fetchedAt: Date(), rates: rates)
        
        // 更新内存
        await CurrencyCache.shared.set(cache, for: base)
        
        // 异步更新磁盘
        Task.detached(priority: .background) {
            if let data = try? JSONEncoder().encode(cache) {
                UserDefaults.standard.set(data, forKey: kRatesKey)
            }
        }
    }

    // --- 内部方法：读取 UserDefaults ---
    private static func loadLocalRates() async -> CachedRates? {
        return await Task.detached(priority: .userInitiated) {
            guard let data = UserDefaults.standard.data(forKey: kRatesKey) else { return nil }
            return try? JSONDecoder().decode(CachedRates.self, from: data)
        }.value
    }
}
