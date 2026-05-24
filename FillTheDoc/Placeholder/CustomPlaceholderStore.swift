import Foundation

protocol CustomPlaceholderStore: Sendable {
    func load() async throws -> [PlaceholderDescriptor]
    func save(_ definitions: [PlaceholderDescriptor]) async throws
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
    
    func load() async throws -> [PlaceholderDescriptor] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: fileURL)
        let schemaVersion = try decoder.decode(CustomPlaceholdersSchemaProbe.self, from: data).schemaVersion
        
        switch schemaVersion {
            case 3:
                return try decoder.decode(CustomPlaceholdersFile.self, from: data).placeholders
            case 1, 2:
                let legacyFile = try decoder.decode(LegacyCustomPlaceholdersFile.self, from: data)
                return legacyFile.placeholders.compactMap { placeholder in
                    guard placeholder.isEnabled else { return nil }
                    return PlaceholderDescriptor(
                        key: placeholder.key,
                        title: placeholder.title,
                        description: placeholder.description ?? "",
                        section: .custom,
                        order: placeholder.order,
                        valueSource: .manual,
                        inputKind: placeholder.inputKind,
                        isUserDefined: true,
                        exampleValue: nil,
                        isRequired: placeholder.inputKind.isRequired
                    )
                }
            default:
                throw CustomPlaceholderStoreError.unsupportedSchemaVersion(schemaVersion)
        }
    }
    
    func save(_ definitions: [PlaceholderDescriptor]) async throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        
        let file = CustomPlaceholdersFile(
            schemaVersion: 3,
            placeholders: definitions
        )
        let data = try encoder.encode(file)
        try data.write(to: fileURL, options: [.atomic])
    }
}

nonisolated private struct CustomPlaceholdersSchemaProbe: Decodable {
    let schemaVersion: Int
}

nonisolated private struct LegacyCustomPlaceholdersFile: Decodable {
    let schemaVersion: Int
    let placeholders: [LegacyCustomPlaceholderDefinition]
}

nonisolated private struct LegacyCustomPlaceholderDefinition: Decodable {
    let key: PlaceholderKey
    let title: String
    let description: String?
    let inputKind: PlaceholderInputKind
    let order: Int
    let isEnabled: Bool
    
    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case description
        case inputKind
        case order
        case isEnabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try container.decode(PlaceholderKey.self, forKey: .key)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.inputKind = try container.decode(PlaceholderInputKind.self, forKey: .inputKind)
        self.order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 500
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}
