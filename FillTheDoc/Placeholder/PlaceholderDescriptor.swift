import Foundation

// MARK: - PlaceholderKind

/// Явно описывает жизненный цикл плейсхолдера.
///
/// - `editable` означает, что у плейсхолдера есть пользовательский ввод,
///   конкретный `inputKind` и понятный `valueSource`.
/// - `derived` означает, что значение вычисляется системой resolver'ов и
///   пользователь его не редактирует.
nonisolated enum PlaceholderKind: Hashable, Sendable {
    case editable(source: PlaceholderValueSource, inputKind: PlaceholderInputKind)
    case derived
    
    var acceptsUserInput: Bool {
        if case .editable = self {
            return true
        }
        return false
    }
    
    var isDerived: Bool { !acceptsUserInput }
    
    var valueSource: PlaceholderValueSource? {
        guard case .editable(let source, _) = self else { return nil }
        return source
    }
    
    var inputKind: PlaceholderInputKind? {
        guard case .editable(_, let inputKind) = self else { return nil }
        return inputKind
    }
    
    var inputKindLabel: String? { inputKind?.label }
    var textEditorStyleLabel: String? { inputKind?.textEditorStyleLabel }
    var valueSourceLabel: String? { valueSource?.label }
    
    var signatureFragment: String {
        switch self {
            case .editable(let source, let inputKind):
                return "editable|\(source.rawValue)|\(inputKind.signatureFragment)"
            case .derived:
                return "derived"
        }
    }
}

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
    let kind: PlaceholderKind
    let isUserDefined: Bool
    let exampleValue: String?
    let isRequired: Bool
    
    /// Строка токена, которую пользователь вставляет в Word-шаблон, например `<!company_name!>`.
    var token: String { "<!\(key.rawValue)!>" }
    
    /// Удобный presentation helper для UI формы и библиотеки.
    var placeholder: String { kind.inputKind?.placeholderText ?? "" }
    
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
        if case .editable(let source, let inputKind) = kind,
           inputKind.isChoice {
            precondition(
                source == .manual,
                "Choice placeholders must be manual. They must not be extracted from LLM."
            )
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
    
    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case description
        case section
        case order
        case valueSource
        case inputKind
        case isUserDefined
        case exampleValue
        case isRequired
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = try container.decode(PlaceholderKey.self, forKey: .key)
        let title = try container.decode(String.self, forKey: .title)
        let description = try container.decode(String.self, forKey: .description)
        let section = try container.decode(PlaceholderSection.self, forKey: .section)
        let order = try container.decode(Int.self, forKey: .order)
        let valueSource = try container.decodeIfPresent(PlaceholderValueSource.self, forKey: .valueSource)
        let inputKind = try container.decodeIfPresent(PlaceholderInputKind.self, forKey: .inputKind)
        let isUserDefined = try container.decodeIfPresent(Bool.self, forKey: .isUserDefined) ?? false
        let exampleValue = try container.decodeIfPresent(String.self, forKey: .exampleValue)
        let isRequired = try container.decodeIfPresent(Bool.self, forKey: .isRequired) ?? false
        
        self.init(
            key: key,
            title: title,
            description: description,
            section: section,
            order: order,
            kind: try Self.decodeKind(
                valueSource: valueSource,
                inputKind: inputKind,
                codingPath: container.codingPath
            ),
            isUserDefined: isUserDefined,
            exampleValue: exampleValue,
            isRequired: isRequired
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(section, forKey: .section)
        try container.encode(order, forKey: .order)
        try container.encode(isUserDefined, forKey: .isUserDefined)
        try container.encodeIfPresent(exampleValue, forKey: .exampleValue)
        try container.encode(isRequired, forKey: .isRequired)
        try container.encodeIfPresent(kind.valueSource, forKey: .valueSource)
        try container.encodeIfPresent(kind.inputKind, forKey: .inputKind)
    }
}

private extension PlaceholderDescriptor {
    nonisolated static func decodeKind(
        valueSource: PlaceholderValueSource?,
        inputKind: PlaceholderInputKind?,
        codingPath: [CodingKey]
    ) throws -> PlaceholderKind {
        switch (valueSource, inputKind) {
            case (.none, .none):
                return .derived
            case (.some(let source), .some(let inputKind)):
                return .editable(source: source, inputKind: inputKind)
            case (.none, .some):
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: codingPath + [CodingKeys.valueSource],
                        debugDescription: "Editable placeholder is missing valueSource."
                    )
                )
            case (.some, .none):
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: codingPath + [CodingKeys.inputKind],
                        debugDescription: "Editable placeholder is missing inputKind."
                    )
                )
        }
    }
}
