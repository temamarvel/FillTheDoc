import Foundation

// MARK: - PlaceholderDescriptor

/// Каноническое описание плейсхолдера.
///
/// Через `PlaceholderDescriptor` приложение документирует только стабильные данные о плейсхолдере:
/// отображаемое имя, описание, секцию, тип ввода, источник значения и token для шаблона.
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
    let valueSource: PlaceholderValueSource?
    let inputKind: PlaceholderInputKind?
    let isUserDefined: Bool
    let exampleValue: String?
    let isRequired: Bool
    
    /// Строка токена, которую пользователь вставляет в Word-шаблон, например `<!company_name!>`.
    var token: String { "<!\(key.rawValue)!>" }
    
    /// Удобный presentation helper для UI формы и библиотеки.
    var placeholder: String { inputKind?.placeholderText ?? "" }
    
    /// `true` для полей, которые пользователь видит и может редактировать в форме.
    var acceptsUserInput: Bool { inputKind != nil }
    
    /// `true` для вычисляемых системных полей вроде `date_short`.
    var isDerived: Bool { inputKind == nil }
    
    var inputKindLabel: String? { inputKind?.label }
    var textEditorStyleLabel: String? { inputKind?.textEditorStyleLabel }
    var valueSourceLabel: String? { valueSource?.label }
    
    /// Строковая сигнатура помогает SwiftUI понять, что definition реально поменялся
    /// и форму нужно синхронизировать с новым registry (например после редактирования custom placeholder).
    var signature: String {
        [
            key.rawValue,
            title,
            description,
            section.rawValue,
            String(order),
            valueSource?.rawValue ?? "derived",
            inputKind?.signatureFragment ?? "no-input",
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
        valueSource: PlaceholderValueSource? = nil,
        inputKind: PlaceholderInputKind? = nil,
        isUserDefined: Bool = false,
        exampleValue: String? = nil,
        isRequired: Bool
    ) {
        if let inputKind, inputKind.isChoice {
            precondition(
                valueSource == .manual,
                "Choice placeholders must be manual. They must not be extracted from LLM."
            )
        }
        
        self.key = key
        self.title = title
        self.description = description
        self.section = section
        self.order = order
        self.valueSource = valueSource
        self.inputKind = inputKind
        self.isUserDefined = isUserDefined
        self.exampleValue = exampleValue
        self.isRequired = isRequired
    }
}
