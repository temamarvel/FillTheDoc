import Foundation

// MARK: - PlaceholderSection

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

struct PlaceholderDescriptor: Identifiable, Hashable, Sendable {
    var id: PlaceholderKey { key }

    let key: PlaceholderKey
    let title: String
    let description: String
    let section: PlaceholderSection
    let kind: PlaceholderKind
    let exampleValue: String?
    let isRequired: Bool

    /// The token string to insert in a template, e.g. <!company_name!>
    var token: String { "<!\(key.rawValue)!>" }
}
