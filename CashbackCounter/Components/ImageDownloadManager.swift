//
//  ImageDownloadManager.swift
//  CashbackCounter
//
//  Created by AI Assistant on 12/17/25.
//

import SwiftUI
import UIKit
import Combine
import os

/// 图片下载管理器，支持进度追踪和临时存储
@MainActor
class ImageDownloadManager: NSObject, ObservableObject {
    @Published var downloadProgress: Double = 0.0
    @Published var isDownloading: Bool = false
    @Published var downloadedImage: UIImage?
    @Published var errorMessage: String?
    
    private var downloadTask: URLSessionDownloadTask?
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CashbackCounter", category: "ImageDownloadManager")
    
    // MARK: - Public Methods
    
    /// 下载图片（带进度）
    /// - Parameter urlString: 图片的 URL 字符串
    func downloadImage(from urlString: String) async {
        logger.info("🚀 开始下载图片: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            handleError(AppConstants.ErrorMessages.invalidURL)
            return
        }
        
        // 1. Check Cache
        if let cachedImage = await ImageCache.shared.load(forKey: urlString) {
            logger.info("✅ 命中缓存，跳过下载")
            handleSuccess(image: cachedImage)
            return
        }
        
        // 2. Start Download
        resetState()
        isDownloading = true
        
        // Create task
        downloadTask = urlSession.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    /// 取消下载
    func cancelDownload() {
        logger.info("🛑 取消下载")
        downloadTask?.cancel()
        isDownloading = false
        downloadProgress = 0.0
        errorMessage = AppConstants.ErrorMessages.downloadCancelled
    }
    
    /// 清理下载的图片（当用户取消保存时调用）
    func cleanup() {
        logger.info("🧹 清理资源")
        downloadedImage = nil
        downloadProgress = 0.0
        errorMessage = nil
        downloadTask = nil
    }
    
    // MARK: - Private Helpers
    
    private func resetState() {
        isDownloading = false
        downloadProgress = 0.0
        errorMessage = nil
        downloadedImage = nil
    }
    
    private func handleSuccess(image: UIImage) {
        self.isDownloading = false
        self.downloadProgress = 1.0
        self.errorMessage = nil
        self.downloadedImage = image
    }
    
    private func handleError(_ message: String) {
        logger.error("❌ 错误: \(message)")
        self.isDownloading = false
        self.errorMessage = message
    }
}

// MARK: - URLSessionDownloadDelegate
extension ImageDownloadManager: URLSessionDownloadDelegate {
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        Task { @MainActor in
            self.downloadProgress = progress
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let originalURL = downloadTask.originalRequest?.url?.absoluteString else { return }
        
        // Move file to a safe place or read data immediately
        do {
            let data = try Data(contentsOf: location)
            
            Task { @MainActor in
                guard let image = UIImage(data: data) else {
                    self.handleError(AppConstants.ErrorMessages.parseError)
                    return
                }
                
                // Cache logic
                await ImageCache.shared.save(image, data: data, forKey: originalURL)
                
                self.handleSuccess(image: image)
                self.logger.info("✅ 下载完成并已缓存")
            }
        } catch {
            Task { @MainActor in
                self.handleError("\(AppConstants.ErrorMessages.fileReadErrorPrefix)\(error.localizedDescription)")
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Ignore cancellation error
            if (error as NSError).code == NSURLErrorCancelled {
                return
            }
            
            Task { @MainActor in
                self.handleError("\(AppConstants.ErrorMessages.downloadErrorPrefix)\(error.localizedDescription)")
            }
        } else {
             // Success is handled in didFinishDownloadingTo
             // But we need to check HTTP status codes if needed.
             // downloadTask doesn't expose response in didFinishDownloadingTo as easily for status codes unless we check task.response
             if let httpResponse = task.response as? HTTPURLResponse,
                !(200...299).contains(httpResponse.statusCode) {
                 Task { @MainActor in
                     self.handleError("\(AppConstants.ErrorMessages.serverErrorPrefix) (状态码: \(httpResponse.statusCode))")
                 }
             }
        }
    }
}


