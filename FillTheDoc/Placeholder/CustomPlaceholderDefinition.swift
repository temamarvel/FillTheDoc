import Foundation

/// Пользовательский плейсхолдер в runtime-модели ничем не отличается от обычного
/// `PlaceholderDescriptor`: он отличается только секцией, флагом `isUserDefined`
/// и тем, что хранится в пользовательском JSON-файле.

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
