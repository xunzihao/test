//
//  ImageCache.swift
//  CashbackCounter
//
//  Created by AI Assistant on 12/20/25.
//

import UIKit
import Foundation

/// 负责图片的内存缓存和磁盘缓存
actor ImageCache {
    static let shared = ImageCache()
    
    private init() {}
    
    // MARK: - Memory Cache
    
    private let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 64
        return cache
    }()
    
    func image(forKey key: String) -> UIImage? {
        return memoryCache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        memoryCache.setObject(image, forKey: key as NSString)
    }
    
    // MARK: - Disk Cache
    
    private var cacheDirectory: URL? {
        try? FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent(AppConstants.Config.imageCacheDirectory, isDirectory: true)
    }
    
    private func ensureCacheDirectoryExists() {
        guard let dir = cacheDirectory else { return }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    
    private func fileURL(for key: String) -> URL? {
        guard let dir = cacheDirectory else { return nil }
        
        // 简单清洗文件名
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "._-"))
        let safeKey = String(key.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        let fileName = safeKey.isEmpty ? AppConstants.Config.defaultImageName : safeKey
        
        return dir.appendingPathComponent(fileName)
    }
    
    func loadFromDisk(key: String) -> UIImage? {
        guard let url = fileURL(for: key),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    func saveToDisk(data: Data, key: String) {
        ensureCacheDirectoryExists()
        guard let url = fileURL(for: key) else { return }
        try? data.write(to: url, options: [.atomic])
    }
    
    func load(forKey key: String) -> UIImage? {
        // 1. Check memory
        if let image = image(forKey: key) {
            return image
        }
        
        // 2. Check disk
        if let image = loadFromDisk(key: key) {
            // Restore to memory
            setImage(image, forKey: key)
            return image
        }
        
        return nil
    }
    
    func save(_ image: UIImage, data: Data, forKey key: String) {
        setImage(image, forKey: key)
        saveToDisk(data: data, key: key)
    }
}
