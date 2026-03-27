import Foundation
import SwiftUI
import OpenAIClient

@MainActor
@Observable
final class MainViewModel {
    
    // MARK: - Dependencies
    
    let apiKeyStore: APIKeyStore
    private let scanner: DocxTemplatePlaceholderScanner
    private let replacer: DocxPlaceholderReplacer
    private let googleSheetsRowBuilder: GoogleSheetsRowBuilding
    private let extractorService: DocumentTextExtractorService
    
    // MARK: - State (paths)
    
    var templatePath: String = ""
    
    var detailsPath: String = ""
    
    // MARK: - State (data)
    
    private(set) var details: CompanyDetails?
    var documentData: DocumentData?
    private(set) var templatePlaceholders: [String] = []
    private(set) var googleSheetsRow: String?
    
    // MARK: - State (UI)
    
    private(set) var isLoading: Bool = false
    var isDataApproved: Bool = false
    
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
    
    // MARK: - Init
    
    init(
        apiKeyStore: APIKeyStore,
        scanner: DocxTemplatePlaceholderScanner = DocxTemplatePlaceholderScanner(),
        replacer: DocxPlaceholderReplacer = DocxPlaceholderReplacer(),
        googleSheetsRowBuilder: GoogleSheetsRowBuilding = GoogleSheetsRowBuilder(),
        extractorService: DocumentTextExtractorService = DocumentTextExtractorService()
    ) {
        self.apiKeyStore = apiKeyStore
        self.scanner = scanner
        self.replacer = replacer
        self.googleSheetsRowBuilder = googleSheetsRowBuilder
        self.extractorService = extractorService
    }
    
    // MARK: - Actions
    
    func handleTemplateDrop(_ urls: [URL]) {
        isDataApproved = false
        if let url = urls.first { templatePath = url.path }
        scanPlaceholders()
    }
    
    func handleDetailsDrop(_ urls: [URL]) {
        isDataApproved = false
        details = nil
        googleSheetsRow = nil
        if let url = urls.first { detailsPath = url.path }
        extractDetails()
    }
    
    func applyDocumentData(_ updated: DocumentData) {
        details = updated.companyDetails
        documentData = updated
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
    
    // MARK: - Scan placeholders
    
    func scanPlaceholders() {
        guard let templateURL else { return }
        do {
            templatePlaceholders = try scanner.scanKeys(template: templateURL)
        } catch {
            print("Scan failed:", error)
        }
    }
    
    // MARK: - Extract details (text → OpenAI → CompanyDetails)
    
    func extractDetails() {
        guard let detailsURL else { return }
        
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                let extractedDetails = try extractorService.extract(from: detailsURL)
                //let companyDetails = try await callOpenAI(extractedDetails: extractedDetails)
                let companyDetails = try await fakeOpenAICall(extractedDetails: extractedDetails)
                details = companyDetails
                print("DTO:", companyDetails.toMultilineString())
            } catch {
                print("Extraction failed:", error)
            }
        }
    }
    
    // MARK: - Fill template
    
    func runFill() async {
        guard let templateURL else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let values = documentData?.asDictionary() else { return }
            
            let tempOutURL = makeTempOutputURL(from: templateURL)
            
            let report = try replacer.fill(
                template: templateURL,
                output: tempOutURL,
                values: values
            )
            
            exportDocument = try DocxFileDocument(fileURL: tempOutURL)
            exportDefaultFilename = "\(templateURL.deletingPathExtension().lastPathComponent)_filled"
            
            showExporter = true
            
            if let documentData {
                let row = googleSheetsRowBuilder.makeRow(from: documentData)
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
        // симуляция
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // MARK: valid test data
        return CompanyDetails(companyName: "Тест компания", legalForm: LegalForm.parse("ЗАО"), ceoFullName: "Тест Тестович Тестов", ceoShortenName: "Тестов Т. Т.", ogrn: "1187746707280", inn: "9731007287", kpp: "773101001", email: "test_test@test.com", address: "город Москва, ул Горбунова, д. 2 стр. 3", phone: "+79991234567")
        
        
        //MARK: invalid test data
        // return CompanyDetails(companyName: "Тест компания", legalForm: "ТЕСТ_ЗАО", ceoFullName: "Тест Тестович Тестов", ceoShortenName: "Тестов Т. Т.", ogrn: "11877467072801", inn: "97310107287", kpp: "7731010101", email: "test_test@test.com", address: "Город, ул. Улица, д. 8")
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
