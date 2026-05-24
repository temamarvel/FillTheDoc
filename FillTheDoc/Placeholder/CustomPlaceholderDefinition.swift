import Foundation

/// Пользовательский JSON-файл хранит только актуальную runtime-модель
/// пользовательских плейсхолдеров без миграций и fallback-конвертеров.
nonisolated struct CustomPlaceholdersFile: Codable, Hashable, Sendable {
    var placeholders: [PlaceholderDescriptor]
    
    init(placeholders: [PlaceholderDescriptor]) {
        self.placeholders = placeholders
    }
}
