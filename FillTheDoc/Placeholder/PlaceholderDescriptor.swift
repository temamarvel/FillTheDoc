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
    var acceptsUserInput: Bool { kind.acceptsUserInput }
    
    /// `true` для вычисляемых системных полей вроде `date_short`.
    var isDerived: Bool { kind.isDerived }
    
    var inputKindLabel: String? { kind.inputKindLabel }
    var textEditorStyleLabel: String? { kind.textEditorStyleLabel }
    var valueSourceLabel: String? { kind.valueSourceLabel }
    
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
        if case .editable(let source, let inputKind) = kind, inputKind.isChoice {
            precondition(source == .manual, "Choice placeholders must be manual. They must not be extracted from LLM.")
        }
        
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
