import Foundation

/// Результат анализа ключей, найденных в шаблоне.
///
/// Это read-model поверх результатов scanner'а: она помогает UI понять,
/// какие placeholder'ы понятны приложению, какие будут заполнены автоматически,
/// а какие требуют внимания пользователя.
struct PlaceholderUsageReport: Sendable {
    /// Известные плейсхолдеры, которые приложение может заполнить
    let known: Set<PlaceholderKey>
    /// Неизвестные ключи — не зарегистрированы в реестре
    let unknown: Set<PlaceholderKey>
    /// Автоматически вычисляемые (derived)
    let autoFillable: Set<PlaceholderKey>
    /// Требуют ручного ввода (editable)
    let requiresInput: Set<PlaceholderKey>
}

/// Анализирует ключи, найденные сканером шаблона, относительно реестра.
enum PlaceholderUsageAnalyzer {
    
    static func analyze(
        templateKeys: Set<PlaceholderKey>,
        registry: PlaceholderRegistryProtocol
    ) -> PlaceholderUsageReport {
        var known = Set<PlaceholderKey>()
        var unknown = Set<PlaceholderKey>()
        var autoFillable = Set<PlaceholderKey>()
        var requiresInput = Set<PlaceholderKey>()
        
        for key in templateKeys where !key.isControlToken {
            guard let descriptor = registry.descriptor(for: key) else {
                unknown.insert(key)
                continue
            }
            known.insert(key)
            switch descriptor.kind {
                case .derived:
                    autoFillable.insert(key)
                case .editable, .custom:
                    requiresInput.insert(key)
            }
        }
        
        return PlaceholderUsageReport(
            known: known,
            unknown: unknown,
            autoFillable: autoFillable,
            requiresInput: requiresInput
        )
    }
}
