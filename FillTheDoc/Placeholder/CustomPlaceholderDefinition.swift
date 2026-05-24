import Foundation

nonisolated struct CustomPlaceholdersFile: Codable, Hashable, Sendable {
    var schemaVersion: Int
    var placeholders: [PlaceholderDescriptor]
    
    init(
        schemaVersion: Int = 3,
        placeholders: [PlaceholderDescriptor]
    ) {
        self.schemaVersion = schemaVersion
        self.placeholders = placeholders
    }
}
