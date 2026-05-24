import Foundation

protocol CustomPlaceholderStore: Sendable {
    func load() async throws -> [PlaceholderDescriptor]
    func save(_ descriptors: [PlaceholderDescriptor]) async throws
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
        return try decoder.decode([PlaceholderDescriptor].self, from: data)
    }
    
    func save(_ definitions: [PlaceholderDescriptor]) async throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        
        let data = try encoder.encode(definitions)
        try data.write(to: fileURL, options: [.atomic])
    }
}
