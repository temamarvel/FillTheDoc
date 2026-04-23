//
//  ExtractionResult.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//


import Foundation

/// Нормализованный результат text-extraction pipeline.
///
/// Это уже не «сырой» ответ конкретного extractor'а, а формат,
/// который безопасно отдавать выше в приложение: в LLM-слой, логи и UI.
struct ExtractionResult: Sendable {
    enum Method: Sendable {
        case plainText
        case pdfKit
        case textutil
        case failed
    }
    
    let text: String
    let method: Method
    let needsOCR: Bool
    let diagnostics: Diagnostics
    
    /// Метаданные, которые помогают понять, как именно был получен результат
    /// и почему он может быть неполным.
    struct Diagnostics: Sendable {
        var originalURL: URL
        var fileExtension: String
        var fileSizeBytes: Int64?
        var producedChars: Int
        var notes: [String]
        var errors: [String]
    }
}

/// Raw output from a single TextExtracting implementation.
/// `DocumentTextExtractorService` wraps this into a full `ExtractionResult` with diagnostics.
struct RawExtractionOutput {
    let text: String
    let method: ExtractionResult.Method
    /// Флаг «похоже, нужен OCR». Это эвристический сигнал, а не окончательный verdict.
    let needsOCR: Bool
    let notes: [String]
}

enum TextExtractionError: Error {
    case unsupportedExtension(String)
    case emptyResult
}
