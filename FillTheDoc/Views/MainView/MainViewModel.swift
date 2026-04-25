import Foundation
import SwiftUI
import OpenAIClient
import DocxUtils

/// Главный orchestration-объект приложения.
///
/// `MainViewModel` связывает между собой почти все прикладные слои:
/// - UI (`MainView`, форма редактирования, экспорт),
/// - извлечение текста из входного файла,
/// - LLM-экстракцию `CompanyDetails`,
/// - домен плейсхолдеров,
/// - заполнение DOCX-шаблона,
/// - побочные действия вроде копирования строки для Google Sheets.
///
/// Важно: view model сознательно не хранит низкоуровневую логику
/// извлечения/валидации/резолва. Эта логика вынесена в специализированные
/// сервисы, а здесь остаётся только координация сценария и UI-state.
@MainActor
@Observable
final class MainViewModel {
    
    // MARK: - Dependencies
    
    let apiKeyStore: APIKeyStore
    let updateStore: AppUpdateStore
    let placeholderRegistry: PlaceholderRegistryProtocol
    private let scanner: DocxTemplateScanner
    private let conditionalAssembler: DocxTemplateConditionalAssembler
    private let replacer: DocxTemplateFiller
    private let googleSheetsRowBuilder: DocumentDataCopyStringBuilder
    private let extractorService: DocumentTextExtractorService
    
    // MARK: - State (paths)
    
    var templatePath: String = ""
    var detailsPath: String = ""
    
    // MARK: - State (data)
    
    private(set) var details: CompanyDetails?
    /// Resolved placeholder dictionary ready for template substitution
    var resolvedValues: [PlaceholderKey: String]?
    private(set) var templatePlaceholders: [String] = []
    private(set) var googleSheetsRow: String?
    
    // MARK: - State (UI)
    
    private(set) var isLoading: Bool = false
    var isDataApproved: Bool = false
    
    // MARK: - Task management
    
    private var extractTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    /// Счётчик поколений защищает UI от race condition:
    /// если пользователь быстро меняет входной файл, более старый результат
    /// извлечения не должен перезаписать более новый.
    private var extractionGeneration: Int = 0
    
    // MARK: - State (exporter)
    
    var showExporter: Bool = false
    var exportDocument: DocxFileDocument?
    var exportDefaultFilename: String = "output"
    
    // MARK: - Computed
    
    var templateURL: URL? { url(from: templatePath) }
    var detailsURL: URL? { url(from: detailsPath) }
    
    var isTemplateValid: Bool { isExistingFile(templateURL) }
    var isDetailsValid: Bool { isExistingFile(detailsURL) }
    
    var canRun: Bool {
        isTemplateValid && isDetailsValid && apiKeyStore.hasKey && isDataApproved
    }
    
    // MARK: - Placeholder Library computed
    
    var availablePlaceholders: [PlaceholderDescriptor] {
        placeholderRegistry.allPlaceholders
    }
    
    var templatePlaceholderKeys: Set<PlaceholderKey> {
        Set(templatePlaceholders.map { PlaceholderKey(rawValue: $0) }.filter { !$0.isControlToken })
    }
    
    var unknownTemplatePlaceholderKeys: Set<PlaceholderKey> {
        templatePlaceholderKeys.filter {
            !placeholderRegistry.contains($0) && !$0.isControlToken
        }
    }
    
    // MARK: - Init
    
    init(
        apiKeyStore: APIKeyStore,
        updateStore: AppUpdateStore,
        placeholderRegistry: PlaceholderRegistryProtocol = DefaultPlaceholderRegistry(),
        scanner: DocxTemplateScanner,
        conditionalAssembler: DocxTemplateConditionalAssembler,
        replacer: DocxTemplateFiller,
        googleSheetsRowBuilder: DocumentDataCopyStringBuilder,
        extractorService: DocumentTextExtractorService
    ) {
        self.apiKeyStore = apiKeyStore
        self.updateStore = updateStore
        self.placeholderRegistry = placeholderRegistry
        self.scanner = scanner
        self.conditionalAssembler = conditionalAssembler
        self.replacer = replacer
        self.googleSheetsRowBuilder = googleSheetsRowBuilder
        self.extractorService = extractorService
    }
    
    /// Convenience init with default dependencies for production use.
    convenience init() {
        let updateStore = AppUpdateStore()
        let apiKeyStore = APIKeyStore()
        
        self.init(
            apiKeyStore: apiKeyStore,
            updateStore: updateStore,
            scanner: DocxTemplateScanner(),
            conditionalAssembler: DocxTemplateConditionalAssembler(),
            replacer: DocxTemplateFiller(),
            googleSheetsRowBuilder: DocumentDataCopyStringBuilder(),
            extractorService: DocumentTextExtractorService()
        )
    }
    
    // MARK: - Actions
    
    func handleTemplateDrop(_ urls: [URL]) {
        isDataApproved = false
        if let url = urls.first { templatePath = url.path }
        scanPlaceholders()
    }
    
    func handleDetailsDrop(_ urls: [URL]) {
        isDataApproved = false
        // При смене входного документа сбрасываем подтверждённые данные,
        // потому что они относятся к предыдущему файлу.
        details = nil
        resolvedValues = nil
        googleSheetsRow = nil
        if let url = urls.first { detailsPath = url.path }
        extractDetails()
    }
    
    func applyFormData(resolvedValues: [PlaceholderKey: String], company: CompanyDetails) {
        // На этом этапе данные считаются подтверждёнными пользователем,
        // поэтому именно они становятся источником истины для последующего fill.
        details = company
        self.resolvedValues = resolvedValues
        isDataApproved = true
    }
    
    func handleExportResult(_ result: Result<URL, any Error>) {
        switch result {
            case .success:
                print("NEW DOC SAVED")
            case .failure:
                print("NEW DOC! Не удалось сохранить файл")
        }
        exportDocument = nil
    }
    
    // MARK: - Scan placeholders (IO off main thread)
    
    func scanPlaceholders() {
        guard let templateURL else { return }
        let scanner = self.scanner
        
        scanTask?.cancel()
        scanTask = Task {
            do {
                // Сканер возвращает все ключи из шаблона, а их интерпретация
                // (известный / неизвестный / control token) делается уже выше,
                // через placeholder-domain.
                let keys = try scanner.scanKeys(templateURL: templateURL)
                try Task.checkCancellation()
                self.templatePlaceholders = keys
            } catch is CancellationError {
            } catch {
                print("Scan failed:", error)
            }
        }
    }
    
    // MARK: - Extract details (IO + OpenAI off main thread)
    
    func extractDetails() {
        guard let detailsURL else { return }
        let extractorService = self.extractorService
        
        extractTask?.cancel()
        extractionGeneration += 1
        let generation = extractionGeneration
        
        extractTask = Task { [weak self] in
            guard let self else { return }
            
            self.isLoading = true
            defer { Task { @MainActor [weak self] in self?.isLoading = false } }
            
            do {
                // Первый этап: приводим произвольный входной файл
                // к обычному тексту, пригодному для prompt'а.
                let extractedDetails = try await extractorService.extract(from: detailsURL)
                try Task.checkCancellation()
                
                // Второй этап: LLM строит структурированный `CompanyDetails`.
                let companyDetails = try await self.callOpenAI(extractedDetails: extractedDetails)
                try Task.checkCancellation()
                
                guard generation == self.extractionGeneration else { return }
                self.details = companyDetails
                print("DTO:", companyDetails.toMultilineString())
            } catch is CancellationError {
            } catch {
                print("Extraction failed:", error)
            }
        }
    }
    
    // MARK: - Fill template (IO off main thread)
    
    func runFill() async {
        guard let templateURL else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let values = resolvedValues else { return }
            let stringValues = values.stringKeyed
            
            let tempOutURL = makeTempOutputURL(from: templateURL)
            
            // Сначала собираем/раскрываем условные блоки, затем подставляем значения.
            // Это позволяет template engine корректно обработать служебные control tokens.
            try conditionalAssembler.assemble(
                templateURL: templateURL,
                outputURL: tempOutURL,
                values: stringValues
            )
            
            let report = try replacer.fill(
                templateURL: tempOutURL,
                outputURL: tempOutURL,
                values: stringValues
            )
            
            exportDocument = try DocxFileDocument(fileURL: tempOutURL)
            exportDefaultFilename = "\(templateURL.deletingPathExtension().lastPathComponent)_filled"
            showExporter = true
            
            if let details, let resolvedValues {
                // Отдельный read-model для копирования строки в Google Sheets.
                // Он не является источником истины для плейсхолдеров,
                // а только переиспользует уже подтверждённые данные.
                let documentDetails = DocumentDetails(
                    documentNumber: resolvedValues[.documentNumber],
                    fee: resolvedValues[.fee],
                    minFee: resolvedValues[.minFee],
                    companyDetails: details
                )
                let row = googleSheetsRowBuilder.makeRow(
                    from: documentDetails,
                    resolvedValues: resolvedValues
                )
                googleSheetsRow = row
                googleSheetsRowBuilder.copyToPasteboard(row)
            }
            
            print("missing", report.missingKeys)
            print("found", report.foundKeys)
            print("REPLACE OK")
        } catch {
            print("Replacement failed:", error)
        }
    }
    
    // MARK: - Private
    
    private func callOpenAI(extractedDetails: ExtractionResult) async throws -> CompanyDetails {
        // View model знает, КОГДА вызвать модель, но правила prompt'а и JSON-схему
        // инкапсулирует `PromptBuilder` + `CompanyDetails`.
        let openAIClient = OpenAIClient(apiKey: apiKeyStore.apiKey ?? "", model: "gpt-4o-mini")
        let system = PromptBuilder.system(for: CompanyDetails.self)
        let user = PromptBuilder.user(sourceText: extractedDetails.text)
        
        let (companyDetails, _) = try await openAIClient.request(
            system: system,
            user: user,
            as: CompanyDetails.self
        )
        
        return companyDetails
    }
    
    private func fakeOpenAICall(extractedDetails: ExtractionResult) async throws -> CompanyDetails {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return CompanyDetails(companyName: "Тест компания", legalForm: LegalForm.parse("ЗАО"), ceoFullName: "Тест Тестович Тестов", ceoFullGenitiveName: "Теста Тестовича Тестова", ceoShortenName: "Тестов Т. Т.", ogrn: "1187746707280", inn: "9731007287", kpp: "773101001", email: "test_test@test.com", address: "город Москва, ул Горбунова, д. 2 стр. 3", phone: "+79991234567")
    }
    
    private func makeTempOutputURL(from templateURL: URL) -> URL {
        let base = templateURL.deletingPathExtension().lastPathComponent
        let name = "\(base)_out_\(UUID().uuidString).docx"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }
    
    private func url(from path: String) -> URL? {
        let trimmed = path.trimmed
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed)
    }
    
    private func isExistingFile(_ url: URL?) -> Bool {
        guard let url else { return false }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && !isDir.boolValue
    }
}
