import Foundation

// MARK: - PlaceholderSection

/// UI- и каталог-ориентированная группировка плейсхолдеров.
///
/// `section` не определяет, КАК считается значение, а только помогает
/// показывать плейсхолдеры пользователю и группировать форму/библиотеку.
/// Это presentation-классификация, а не вычислительная.
enum PlaceholderSection: String, Hashable, Sendable, CaseIterable {
    case company
    case document
    case computed
    case custom
    
    var title: String {
        switch self {
            case .company: return "Реквизиты компании"
            case .document: return "Данные документа"
            case .computed: return "Вычисляемые"
            case .custom: return "Пользовательские"
        }
    }
}

// MARK: - PlaceholderKind

/// Способ происхождения значения плейсхолдера внутри приложения.
enum PlaceholderKind: String, Hashable, Sendable {
    /// Значение вводит пользователь вручную
    case editable
    /// Значение вычисляется приложением из других данных
    case derived
    /// Пользовательский ключ, не встроенный в приложение
    case custom
    
    var label: String {
        switch self {
            case .editable: return "Извлекаемый"
            case .derived: return "Вычисляемый"
            case .custom: return "Пользовательский"
        }
    }
}

// MARK: - PlaceholderDescriptor

/// Каноническое описание плейсхолдера.
///
/// Через `PlaceholderDescriptor` приложение документирует всё, что относится
/// к метаданным плейсхолдера: отображаемое имя, описание, секцию, пример,
/// обязательность и token для шаблона.
///
/// Важно: descriptor не содержит само значение. Значения получаются отдельно,
/// через `PlaceholderResolutionContext` + `PlaceholderRegistry`.
///
/// Если `PlaceholderKey` — это identity поля, то `PlaceholderDescriptor` — его паспорт
/// для UI, справочника плейсхолдеров и общей документации системы.
struct PlaceholderDescriptor: Identifiable, Hashable, Sendable {
    var id: PlaceholderKey { key }
    
    let key: PlaceholderKey
    let title: String
    let description: String
    let placeholder: String
    let section: PlaceholderSection
    let kind: PlaceholderKind
    let exampleValue: String?
    let isRequired: Bool
    
    /// Строка токена, которую пользователь вставляет в Word-шаблон, например `<!company_name!>`.
    var token: String { "<!\(key.rawValue)!>" }
    
    init(
        key: PlaceholderKey,
        title: String,
        description: String,
        placeholder: String = "",
        section: PlaceholderSection,
        kind: PlaceholderKind,
        exampleValue: String? = nil,
        isRequired: Bool
    ) {
        self.key = key
        self.title = title
        self.description = description
        self.placeholder = placeholder
        self.section = section
        self.kind = kind
        self.exampleValue = exampleValue
        self.isRequired = isRequired
    }
}
