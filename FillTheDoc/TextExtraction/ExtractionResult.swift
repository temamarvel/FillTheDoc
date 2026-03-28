//
//  ExtractionResult.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//


import Foundation

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
    let needsOCR: Bool
    let notes: [String]
}

enum TextExtractionError: Error {
    case unsupportedExtension(String)
    case emptyResult
}
