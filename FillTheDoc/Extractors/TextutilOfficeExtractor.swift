//
//  TextutilOfficeExtractor.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//

import Foundation


/// Office-extractor через системную утилиту `textutil`.
///
/// Такой подход хорошо подходит для macOS-only приложения: он переиспользует нативную
/// конвертацию Apple для `doc/docx/xls/xlsx` и не требует тащить тяжёлые внешние зависимости.
struct TextutilOfficeExtractor: TextExtracting {
    private let runner: ProcessRunning
    private let timeout: TimeInterval
    
    init(runner: ProcessRunning, timeout: TimeInterval) {
        self.runner = runner
        self.timeout = timeout
    }
    
    func extract(from url: URL) throws -> RawExtractionOutput {
        let tool = URL(fileURLWithPath: "/usr/bin/textutil")
        let out = try runner.run(
            executable: tool,
            arguments: ["-convert", "txt", "-stdout", url.path],
            timeout: timeout
        )
        let text = TextDecoding.decodeBestEffort(out.stdout)
        return RawExtractionOutput(text: text, method: .textutil, needsOCR: false, notes: ["Converted via textutil (-stdout)."])
    }
}
