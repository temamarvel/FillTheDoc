//
//  DocumentTextExtractorService.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//

import Foundation


/// Фасад над несколькими стратегиями извлечения текста из документов.
///
/// Сервис решает три прикладные задачи:
/// 1. безопасно открыть файл, выбранный пользователем в sandbox-среде macOS;
/// 2. привести разные форматы (`txt`, `pdf`, `docx`, `xlsx`...) к plain text;
/// 3. вернуть не только текст, но и диагностическую информацию для UI и логов.
///
/// Это намеренно не actor и не view model: сервис не владеет UI-state,
/// а только выполняет чистую прикладную операцию, удобную для DI и тестов.
public struct DocumentTextExtractorService: Sendable {
    
    public struct Configuration {
        public var maxChars: Int = 60_000
        public var officeTimeout: TimeInterval = 15
        public var requireNonEmptyText: Bool = false
        public init() {}
    }
    
    private let config: Configuration
    private let security: SecurityScopedAccessing
    private let tempStore: TempFileStoring
    private let txtExtractor: TextExtracting
    private let pdfExtractor: TextExtracting
    private let officeExtractor: TextExtracting
    
    // ✅ Designated init for DI / tests
    init(
        config: Configuration = .init(),
        security: SecurityScopedAccessing,
        tempStore: TempFileStoring,
        txtExtractor: TextExtracting,
        pdfExtractor: TextExtracting,
        officeExtractor: TextExtracting
    ) {
        self.config = config
        self.security = security
        self.tempStore = tempStore
        self.txtExtractor = txtExtractor
        self.pdfExtractor = pdfExtractor
        self.officeExtractor = officeExtractor
    }
    
    // ✅ Convenience init for production (config only)
    public init(config: Configuration = .init()) {
        let runner = DefaultProcessRunner()
        self.init(
            config: config,
            security: DefaultSecurityScopedAccessor(),
            tempStore: DefaultTempFileStore(),
            txtExtractor: PlainTextExtractor(),
            pdfExtractor: PDFKitTextExtractor(),
            officeExtractor: TextutilOfficeExtractor(runner: runner, timeout: config.officeTimeout)
        )
    }
    
    func extract(from originalURL: URL) async throws -> ExtractionResult {
        // Диагностика собирается независимо от того, завершится ли extraction успехом.
        var diagnostics = ExtractionResult.Diagnostics(
            originalURL: originalURL,
            fileExtension: originalURL.pathExtension.lowercased(),
            fileSizeBytes: FileInfo.fileSizeBytes(originalURL),
            producedChars: 0,
            notes: [],
            errors: []
        )
        
        return try security.withAccess(originalURL) {
            // Работа идёт с временной копией файла, чтобы внешние утилиты вроде textutil
            // не зависели от исходного sandbox-url и не держали открытый ресурс дольше нужного.
            let tempURL = try tempStore.copyToTemp(originalURL)
            defer { tempStore.cleanup(forTempCopy: tempURL) }
            
            let ext = tempURL.pathExtension.lowercased()
            
            do {
                let raw: RawExtractionOutput = try {
                    switch ext {
                        case "txt":
                            return try txtExtractor.extract(from: tempURL)
                        case "pdf":
                            return try pdfExtractor.extract(from: tempURL)
                        case "doc", "docx", "xls", "xlsx":
                            return try officeExtractor.extract(from: tempURL)
                        default:
                            throw TextExtractionError.unsupportedExtension(ext)
                    }
                }()
                
                diagnostics.notes.append(contentsOf: raw.notes)
                
                // Нормализация подготавливает текст именно для LLM/prompt'а:
                // убирает артефакты форматирования, ограничивает объём и делает результат стабильнее.
                let normalized = Normalizers.forDocumentDisplay(raw.text, maxChars: config.maxChars)
                let finalText = normalized.trimmed
                diagnostics.producedChars = finalText.count
                
                // Для PDF пустой результат обычно означает скан, а не отсутствие содержимого.
                let finalNeedsOCR = raw.needsOCR || (ext == "pdf" && finalText.isEmpty)
                if finalText.isEmpty {
                    diagnostics.notes.append("Text is empty after normalization.")
                    if config.requireNonEmptyText { throw TextExtractionError.emptyResult }
                }
                
                return ExtractionResult(
                    text: finalText,
                    method: raw.method,
                    needsOCR: finalNeedsOCR,
                    diagnostics: diagnostics
                )
            } catch {
                // Сервис по умолчанию предпочитает деградировать мягко: вернуть пустой результат
                // с диагностикой, а не ломать весь UX. Жёсткое поведение включается флагом
                // `requireNonEmptyText`.
                diagnostics.errors.append("Extractor error: \(String(describing: error))")
                let needsOCR = (ext == "pdf")
                let result = ExtractionResult(
                    text: "",
                    method: .failed,
                    needsOCR: needsOCR,
                    diagnostics: diagnostics
                )
                if config.requireNonEmptyText { throw TextExtractionError.emptyResult }
                return result
            }
        }
    }
}
