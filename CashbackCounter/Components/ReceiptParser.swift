//
//  AppleIntelligenceService.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/24/25.
//
import FoundationModels
import Observation // 苹果的新状态管理框架
import Foundation


@MainActor
@Observable
final class ReceiptParser {
    
    // 1. 这里的 session 定义和苹果一模一样
    private let instructions = Instructions(AppConstants.AI.instructions)
    private let SMSinstructions = Instructions(AppConstants.AI.SMSinstructions)
    
    init() {}
    
    // 3. 解析方法
    func parse(text: String) async throws -> ReceiptMetadata {
            
            // 👇👇👇 核心修改：每次调用 parse 时，创建一个全新的 session！
            // 这样每次都是“第一次”，没有历史包袱
            let session = LanguageModelSession(instructions: instructions)
            
            let response = try await session.respond(
                generating: ReceiptMetadata.self
            ) {
                "Analyze this receipt text:"
                text
            }
            
        return response.content
        }
    // func SMSparse(text: String) async throws -> ReceiptMetadata {
            
    //         // 👇👇👇 核心修改：每次调用 parse 时，创建一个全新的 session！
    //         // 这样每次都是“第一次”，没有历史包袱
    //         let session = LanguageModelSession(instructions: SMSinstructions)
            
    //         let response = try await session.respond(
    //             generating: ReceiptMetadata.self
    //         ) {
    //             "Analyze this receipt text:"
    //             text
    //         }
            
        // return response.content
        // }
    
}
