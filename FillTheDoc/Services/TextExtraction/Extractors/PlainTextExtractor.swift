//
//  PlainTextExtractor.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//

import Foundation


/// Самый прямой extractor: читает файл как `Data` и декодирует текст best-effort.
/// Используется для `txt`, где не нужна внешняя утилита или структурный парсер.
struct PlainTextExtractor: TextExtracting {
    init() {}
    
    func extract(from url: URL) throws -> RawExtractionOutput {
        let data = try Data(contentsOf: url)
        let text = TextDecoding.decodeBestEffort(data)
        return RawExtractionOutput(text: text, method: .plainText, needsOCR: false, notes: ["TXT decoded with fallbacks."])
    }
}
