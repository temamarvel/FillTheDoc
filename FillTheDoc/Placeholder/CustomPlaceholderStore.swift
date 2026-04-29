import Foundation

protocol CustomPlaceholderStore: Sendable {
    func load() async throws -> [CustomPlaceholderDefinition]
    func save(_ definitions: [CustomPlaceholderDefinition]) async throws
}

enum CustomPlaceholderStoreError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    
    var errorDescription: String? {
        switch self {
            case .unsupportedSchemaVersion(let version):
                return "Неподдерживаемая версия файла пользовательских плейсхолдеров: \(version)."
        }
    }
}

actor FileCustomPlaceholderStore: CustomPlaceholderStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }
    
    func load() async throws -> [CustomPlaceholderDefinition] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: fileURL)
        let file = try decoder.decode(CustomPlaceholdersFile.self, from: data)
        switch file.schemaVersion {
            case 1, 2:
                return file.placeholders
            default:
                throw CustomPlaceholderStoreError.unsupportedSchemaVersion(file.schemaVersion)
        }
    }
    
    func save(_ definitions: [CustomPlaceholderDefinition]) async throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        
        let file = CustomPlaceholdersFile(
            schemaVersion: 2,
            placeholders: definitions
        )
        let data = try encoder.encode(file)
        try data.write(to: fileURL, options: [.atomic])
    }
}
