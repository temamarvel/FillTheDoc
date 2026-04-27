import Foundation
import SwiftUI
import OpenAIClient
import DocxUtils

/// Главный orchestration-объект приложения.
///
/// Это центральный координатор пользовательского сценария и главный файл,
/// который стоит читать после `MainView`, если нужно быстро понять архитектуру.
///
/// `MainViewModel` связывает между собой почти все прикладные слои:
/// - UI (`MainView`, форма редактирования, системный экспортёр);
/// - extraction pipeline для входного документа с реквизитами;
/// - вызов LLM и декодирование ответа в `CompanyDetails`;
/// - placeholder-domain и построение итогового словаря значений;
/// - заполнение DOCX-шаблона;
/// - побочные действия вроде формирования строки для Google Sheets.
///
/// Ключевая идея: здесь находится логика порядка шагов, но не логика самих шагов.
/// View model знает:
/// - когда запускать extraction;
/// - когда сбрасывать подтверждённые данные;
/// - когда разрешать export;
/// - какие зависимости позвать для очередного этапа.
///
/// Но она намеренно не знает деталей:
/// - как конкретно извлекается текст из PDF/DOCX;
/// - как устроен prompt к модели;
/// - как валидируются отдельные поля;
/// - как именно заменяются XML-токены внутри DOCX.
///
/// Такой split повышает читаемость и позволяет понимать проект «по слоям»,
/// не погружаясь в низкоуровневые детали раньше времени.
@MainActor
@Observable
final class MainViewModel {
    
    // MARK: - Dependencies
    
    let apiKeyStore: APIKeyStore
    let updateStore: AppUpdateStore
    private(set) var placeholderRegistry: PlaceholderRegistryProtocol
    private let scanner: DocxTemplateScanner
    private let conditionalAssembler: DocxTemplateConditionalAssembler
    private let replacer: DocxTemplateFiller
    private let googleSheetsRowBuilder: DocumentDataCopyStringBuilder
    private let extractorService: DocumentTextExtractorService
    private let customPlaceholderRepository: CustomPlaceholderRepository?
    
    // MARK: - State (paths)
    
    var templatePath: String = ""
    var detailsPath: String = ""
    
    // MARK: - State (data)
    
    private(set) var details: CompanyDetails?
    /// Итоговый словарь значений, который уже можно отдавать в DOCX-fill.
    ///
    /// Важно: он появляется только после пользовательского подтверждения формы,
    /// а не сразу после ответа модели.
    var resolvedValues: [PlaceholderKey: String]?
    private(set) var templatePlaceholders: [String] = []
    private(set) var googleSheetsRow: String?
    private(set) var customPlaceholderDefinitions: [CustomPlaceholderDefinition] = []
    
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
    
    var availablePlaceholderKeys: Set<PlaceholderKey> {
        Set(availablePlaceholders.map(\.key))
    }
    
    var templatePlaceholderKeys: Set<PlaceholderKey> {
        Set(templatePlaceholders.map { PlaceholderKey(rawValue: $0) }.filter { !$0.isControlToken })
    }
    
    var templateUsageReport: PlaceholderUsageReport {
        PlaceholderUsageAnalyzer.analyze(
            templateKeys: templatePlaceholderKeys,
            registry: placeholderRegistry
        )
    }
    
    var unknownTemplatePlaceholderKeys: Set<PlaceholderKey> {
        templateUsageReport.unknown
    }
    
    // MARK: - Init
    
    init(
        apiKeyStore: APIKeyStore,
        updateStore: AppUpdateStore,
        placeholderRegistry: PlaceholderRegistryProtocol = DefaultPlaceholderRegistry(),
        customPlaceholderRepository: CustomPlaceholderRepository? = nil,
        scanner: DocxTemplateScanner,
        conditionalAssembler: DocxTemplateConditionalAssembler,
        replacer: DocxTemplateFiller,
        googleSheetsRowBuilder: DocumentDataCopyStringBuilder,
        extractorService: DocumentTextExtractorService
    ) {
        self.apiKeyStore = apiKeyStore
        self.updateStore = updateStore
        self.placeholderRegistry = placeholderRegistry
        self.customPlaceholderRepository = customPlaceholderRepository
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
        let customPlaceholderRepository: CustomPlaceholderRepository?
        
        do {
            let fileURL = try AppStorageLocations.customPlaceholdersFileURL()
            let store = FileCustomPlaceholderStore(fileURL: fileURL)
            customPlaceholderRepository = CustomPlaceholderRepository(store: store)
        } catch {
            print("Custom placeholder storage init failed:", error)
            customPlaceholderRepository = nil
        }
        
        self.init(
            apiKeyStore: apiKeyStore,
            updateStore: updateStore,
            customPlaceholderRepository: customPlaceholderRepository,
            scanner: DocxTemplateScanner(),
            conditionalAssembler: DocxTemplateConditionalAssembler(),
            replacer: DocxTemplateFiller(),
            googleSheetsRowBuilder: DocumentDataCopyStringBuilder(),
            extractorService: DocumentTextExtractorService()
        )
    }
    
    // MARK: - Actions
    
    func handleTemplateDrop(_ urls: [URL]) {
        // Смена шаблона не инвалидирует сам LLM draft, но инвалидирует утверждение данных,
        // потому что новый шаблон может требовать другой набор placeholder'ов.
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
        // Это ключевая смысловая граница проекта:
        // до этой точки `details` — черновик после LLM,
        // после этой точки `details` и `resolvedValues` — подтверждённый оператором источник истины.
        details = company
        self.resolvedValues = resolvedValues
        isDataApproved = true
    }
    
    func loadCustomPlaceholders() async {
        guard let customPlaceholderRepository else { return }
        do {
            try await customPlaceholderRepository.load()
            let allDefinitions = await customPlaceholderRepository.all()
            refreshPlaceholderRegistry(customDefinitions: allDefinitions)
        } catch {
            print("Custom placeholder loading failed:", error)
        }
    }
    
    func addCustomPlaceholder(_ definition: CustomPlaceholderDefinition) async throws {
        guard let customPlaceholderRepository else { return }
        try await customPlaceholderRepository.add(definition)
        let allDefinitions = await customPlaceholderRepository.all()
        refreshPlaceholderRegistry(customDefinitions: allDefinitions)
    }
    
    func updateCustomPlaceholder(_ definition: CustomPlaceholderDefinition) async throws {
        guard let customPlaceholderRepository else { return }
        try await customPlaceholderRepository.update(definition)
        let allDefinitions = await customPlaceholderRepository.all()
        refreshPlaceholderRegistry(customDefinitions: allDefinitions)
    }
    
    func deleteCustomPlaceholder(key: PlaceholderKey) async throws {
        guard let customPlaceholderRepository else { return }
        try await customPlaceholderRepository.delete(key: key)
        let allDefinitions = await customPlaceholderRepository.all()
        refreshPlaceholderRegistry(customDefinitions: allDefinitions)
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
                // к plain text, пригодному для prompt'а.
                // View model не знает, как именно это делается для каждого формата,
                // и получает уже нормализованный `ExtractionResult`.
                let extractedDetails = try await extractorService.extract(from: detailsURL)
                try Task.checkCancellation()
                
                // Второй этап: LLM строит структурированный `CompanyDetails`.
                // Это всё ещё draft, а не окончательные данные для шаблона.
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
            
            // Важно соблюдать порядок этапов:
            // 1) сначала раскрываем условные блоки (`switch/case/...` control tokens),
            // 2) затем делаем обычную подстановку placeholder'ов.
            //
            // Если поменять местами эти шаги, шаблонный движок может попытаться трактовать
            // управляющие токены как обычный текст и часть условий перестанет работать.
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
            
            if let resolvedValues {
                // Google Sheets row — побочный продукт утверждённых данных.
                // Он сознательно строится здесь, после успешной подготовки итогового документа,
                // чтобы пользователь не получил строку из неподтверждённого черновика.
                let row = googleSheetsRowBuilder.makeRow(from: resolvedValues)
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
        // View model знает, КОГДА вызвать модель, но детали контракта с ней хранит
        // не здесь, а в `PromptBuilder` + `CompanyDetails`/`LLMExtractable`.
        // Это позволяет менять prompt/схему независимо от orchestration-слоя.
        assert(
            Set(placeholderRegistry.llmSchemaKeys.map(\.rawValue)) == Set(CompanyDetails.llmSchemaKeys),
            "LLM schema must stay aligned with extracted placeholder definitions. Manual/choice placeholders must not leak into prompt schema."
        )
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
    
    private func refreshPlaceholderRegistry(customDefinitions: [CustomPlaceholderDefinition]) {
        customPlaceholderDefinitions = customDefinitions.sorted { lhs, rhs in
            if lhs.order == rhs.order {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.order < rhs.order
        }
        placeholderRegistry = DefaultPlaceholderRegistry(customDefinitions: customDefinitions)
    }
}
