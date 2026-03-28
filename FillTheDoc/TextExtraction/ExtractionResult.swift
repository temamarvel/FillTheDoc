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

enum TextExtractionError: Error {
    case unsupportedExtension(String)
    case emptyResult
}