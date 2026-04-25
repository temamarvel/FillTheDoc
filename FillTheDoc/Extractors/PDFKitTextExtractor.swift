//
//  PDFKitTextExtractor.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//

import Foundation
import PDFKit


/// PDF-adapter на базе `PDFKit`.
///
/// Он извлекает только доступный selectable text. Если страницы являются сканами
/// и `PDFKit` не видит текстового слоя, extractor помечает результат как `needsOCR`.
///
/// Это сознательное ограничение текущей версии проекта:
/// полноценный OCR сюда не встроен, поэтому extractor честно сигнализирует,
/// что текстовый слой отсутствует, вместо попытки «угадать» данные.
struct PDFKitTextExtractor: TextExtracting {
    init() {}
    
    func extract(from url: URL) throws -> RawExtractionOutput {
        guard let doc = PDFDocument(url: url) else {
            return RawExtractionOutput(text: "", method: .pdfKit, needsOCR: false, notes: ["PDFDocument init failed."])
        }
        
        var pages: [String] = []
        pages.reserveCapacity(doc.pageCount)
        
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let s = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !s.isEmpty { pages.append(s) }
        }
        
        let text = pages.joined(separator: "\n\n")
        let hasSelectableText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let needsOCR = !hasSelectableText
        
        var notes = ["PDFKit extracted selectable text: \(hasSelectableText)."]
        if needsOCR { notes.append("Likely scanned PDF; OCR recommended.") }
        
        return RawExtractionOutput(text: text, method: .pdfKit, needsOCR: needsOCR, notes: notes)
    }
}
