//
//  DocumentTextExtractorService.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//

import Foundation


/// Фасад над несколькими стратегиями извлечения текста из документов.
///
/// Это входная точка всего extraction pipeline. Выше по стеку приложению не важно,
/// был ли исходный файл `txt`, `pdf`, `docx` или `xlsx` — ему нужен единый результат:
/// нормализованный plain text + диагностическая информация.
///
/// Сервис решает три прикладные задачи:
/// 1. безопасно открыть файл, выбранный пользователем в sandbox-среде macOS;
/// 2. привести разные форматы к plain text через подходящий extractor;
/// 3. вернуть не только текст, но и контекст, полезный для UI, логов и troubleshooting.
///
/// Почему это отдельный сервис, а не просто набор helper-функций:
/// - здесь удобно централизовать sandbox access и работу с временными копиями;
/// - orchestration-слой получает один понятный API независимо от формата файла;
/// - низкоуровневые extractors остаются маленькими и отвечают только за свой механизм.
///
/// Это намеренно не actor и не view model: сервис не владеет UI-state,
/// а только выполняет прикладную операцию, удобную для DI и тестов.
public struct DocumentTextExtractorService: Sendable {
    
    public struct Configuration {
        /// Ограничение на размер текста, отправляемого выше по pipeline.
        /// Нужно, чтобы не тащить в prompt чрезмерно большие документы целиком.
        public var maxChars: Int = 60_000
        /// Таймаут для extraction office-файлов через внешнюю системную утилиту.
        public var officeTimeout: TimeInterval = 15
        /// Если `true`, пустой результат трактуется как ошибка.
        /// Если `false`, сервис предпочитает мягкую деградацию с диагностикой.
        public var requireNonEmptyText: Bool = false
        public init() {}
    }
    
    private let config: Configuration
    private let security: SecurityScopedAccessing
    private let tempStore: TempFileStoring
    private let txtExtractor: TextExtracting
    private let pdfExtractor: TextExtracting
    private let officeExtractor: TextExtracting
    
    // Designated init for DI / tests.
    // Позволяет подменять любой кусок pipeline независимо: sandbox, temp storage,
    // extractor для конкретного формата или process runner.
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
    
    // Convenience init for production (config only).
    // Здесь собирается стандартный стек зависимостей для реального приложения.
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
                // Здесь приложение сознательно теряет часть исходного форматирования в обмен
                // на более предсказуемый и компактный вход для модели.
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
                // с диагностикой, а не ломать весь UX одной ошибкой extraction.
                // Это осознанный компромисс в пользу устойчивого пользовательского сценария:
                // оператор всё ещё может увидеть, что extraction не дал данных, и попробовать другой файл.
                // Жёсткое поведение включается флагом `requireNonEmptyText`.
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
