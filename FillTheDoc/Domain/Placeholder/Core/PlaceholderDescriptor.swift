import Foundation

// MARK: - PlaceholderDescriptor

/// Каноническое описание плейсхолдера.
///
/// Через `PlaceholderDescriptor` приложение документирует только стабильные данные о плейсхолдере:
/// отображаемое имя, описание, секцию, вид плейсхолдера, token для шаблона
/// и пример итогового replacement value.
///
/// Важно: descriptor по-прежнему не содержит САМО значение поля. Он только описывает,
/// как это значение должно выглядеть и откуда берётся. Сами значения живут отдельно:
/// - в `PlaceholderFieldValue` внутри формы;
/// - в `[PlaceholderKey: String]` после финального resolve.
///
/// Если `PlaceholderKey` — это identity поля, то `PlaceholderDescriptor` — его паспорт
/// для UI, справочника плейсхолдеров и общей документации системы.
nonisolated struct PlaceholderDescriptor: Identifiable, Hashable, Codable, Sendable {
    var id: PlaceholderKey { key }
    
    let key: PlaceholderKey
    let title: String
    let description: String
    let section: PlaceholderSection
    let order: Int
    let kind: PlaceholderKind
    let isUserDefined: Bool
    let exampleValue: String?
    let isRequired: Bool
    
    /// Строка токена, которую пользователь вставляет в Word-шаблон, например `<!company_name!>`.
    var token: String { "<!\(key.rawValue)!>" }
    
    /// `true` для полей, которые пользователь видит и может редактировать в форме.
    var acceptsUserInput: Bool {
        if case .editable = kind {
            return true
        }
        return false
    }
    
    var inputKindLabel: String? {
        guard case .editable(_, let inputKind) = kind else { return nil }
        return inputKind.label
    }
    
    var inputKind: PlaceholderInputKind? {
        guard case .editable(_, let inputKind) = kind else { return nil }
        return inputKind
    }
    
    var textEditorStyleLabel: String? {
        guard case .editable(_, .text(let editorStyle)) = kind else { return nil }
        return editorStyle.label
    }
    
    var valueSourceLabel: String? {
        guard case .editable(let source, _) = kind else { return nil }
        return source.label
    }
    
    var metadataLabels: [String] {
        [valueSourceLabel, inputKindLabel, textEditorStyleLabel].compactMap { $0 }
    }
    
    var searchableTextFragments: [String] {
        [title, key.rawValue, description] + metadataLabels
    }
    
    /// Строковая сигнатура помогает SwiftUI понять, что definition реально поменялся
    /// и форму нужно синхронизировать с новым registry (например после редактирования custom placeholder).
    var signature: String {
        [
            key.rawValue,
            title,
            description,
            section.rawValue,
            String(order),
            kind.signatureFragment,
            String(isUserDefined),
            exampleValue ?? "",
            String(isRequired)
        ].joined(separator: "|")
    }
    
    nonisolated init(
        key: PlaceholderKey,
        title: String,
        description: String,
        section: PlaceholderSection,
        order: Int,
        kind: PlaceholderKind,
        isUserDefined: Bool = false,
        exampleValue: String? = nil,
        isRequired: Bool
    ) {
        self.key = key
        self.title = title
        self.description = description
        self.section = section
        self.order = order
        self.kind = kind
        self.isUserDefined = isUserDefined
        self.exampleValue = exampleValue
        self.isRequired = isRequired
    }
}
