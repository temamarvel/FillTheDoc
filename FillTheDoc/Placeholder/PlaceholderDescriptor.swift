import Foundation

typealias FieldNormalizer = @Sendable (String) -> String
typealias FieldValidator = @Sendable (String) -> FieldIssue?

// MARK: - PlaceholderSection

/// UI- и каталог-ориентированная группировка плейсхолдеров.
///
/// `section` не определяет, КАК считается значение, а только помогает
/// показывать плейсхолдеры пользователю и группировать форму/библиотеку.
/// Это presentation-классификация, а не вычислительная.
nonisolated enum PlaceholderSection: String, Hashable, Sendable, CaseIterable {
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

// MARK: - PlaceholderValueSource

/// Источник значения для полей, которые пользователь может редактировать.
///
/// `derived`-плейсхолдеры в эту модель не входят: они не редактируются и
/// вычисляются отдельными resolver'ами внутри registry.
nonisolated enum PlaceholderValueSource: String, Codable, Hashable, Sendable {
    /// Значение приходит из LLM extraction и затем может быть отредактировано человеком.
    case extracted
    /// Значение задаётся пользователем вручную в UI и никогда не должно прилетать из LLM.
    case manual
    
    var label: String {
        switch self {
            case .extracted: return "Извлекается"
            case .manual: return "Заполняется вручную"
        }
    }
}

// MARK: - Input configuration

nonisolated struct TextInputConfiguration: Hashable, Codable, Sendable {
    var placeholder: String
    var isRequired: Bool
    var trimOnCommit: Bool
    
    init(
        placeholder: String = "",
        isRequired: Bool = false,
        trimOnCommit: Bool = true
    ) {
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.trimOnCommit = trimOnCommit
    }
}

nonisolated enum ChoicePresentationStyle: String, Codable, Hashable, Sendable {
    case menu
    case segmented
}

nonisolated struct PlaceholderOption: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var title: String
    var replacementValue: String
    var description: String?
    
    init(
        id: String,
        title: String,
        replacementValue: String,
        description: String? = nil
    ) {
        self.id = id
        self.title = title
        self.replacementValue = replacementValue
        self.description = description
    }
}

nonisolated struct ChoiceInputConfiguration: Hashable, Codable, Sendable {
    var options: [PlaceholderOption]
    var defaultOptionID: String?
    var allowsEmptySelection: Bool
    var emptyTitle: String
    var presentationStyle: ChoicePresentationStyle
    
    init(
        options: [PlaceholderOption],
        defaultOptionID: String? = nil,
        allowsEmptySelection: Bool = true,
        emptyTitle: String = "Не выбрано",
        presentationStyle: ChoicePresentationStyle = .menu
    ) {
        self.options = options
        self.defaultOptionID = defaultOptionID
        self.allowsEmptySelection = allowsEmptySelection
        self.emptyTitle = emptyTitle
        self.presentationStyle = presentationStyle
    }
}

nonisolated enum PlaceholderInputKind: Hashable, Sendable {
    case text(TextInputConfiguration)
    case multilineText(TextInputConfiguration)
    case choice(ChoiceInputConfiguration)
    
    var isChoice: Bool {
        if case .choice = self {
            return true
        }
        return false
    }
    
    var label: String {
        switch self {
            case .text:
                return "Текст"
            case .multilineText:
                return "Многострочный текст"
            case .choice:
                return "Выбор"
        }
    }
    
    var placeholderText: String {
        switch self {
            case .text(let configuration), .multilineText(let configuration):
                return configuration.placeholder
            case .choice:
                return ""
        }
    }
    
    var isRequired: Bool {
        switch self {
            case .text(let configuration), .multilineText(let configuration):
                return configuration.isRequired
            case .choice(let configuration):
                return !configuration.allowsEmptySelection
        }
    }
    
    var signatureFragment: String {
        switch self {
            case .text(let configuration):
                return "text|\(configuration.placeholder)|\(configuration.isRequired)|\(configuration.trimOnCommit)"
            case .multilineText(let configuration):
                return "multiline|\(configuration.placeholder)|\(configuration.isRequired)|\(configuration.trimOnCommit)"
            case .choice(let configuration):
                let optionsLine = configuration.options
                    .map { "\($0.id):\($0.title):\($0.replacementValue)" }
                    .joined(separator: ";")
                return "choice|\(optionsLine)|\(configuration.defaultOptionID ?? "")|\(configuration.allowsEmptySelection)|\(configuration.emptyTitle)|\(configuration.presentationStyle.rawValue)"
        }
    }
}

// MARK: - PlaceholderFieldValue

/// Типизированное runtime-состояние поля формы.
///
/// Для `choice` мы храним именно `optionID`, а не итоговую строку подстановки,
/// чтобы UI и persistence были устойчивы к изменению `title` и `replacementValue`.
nonisolated enum PlaceholderFieldValue: Hashable, Codable, Sendable {
    case text(String)
    case choice(optionID: String)
    case empty
    
    var textValue: String {
        guard case .text(let value) = self else { return "" }
        return value
    }
    
    var choiceOptionID: String? {
        guard case .choice(let optionID) = self else { return nil }
        return optionID
    }
}

// MARK: - PlaceholderDescriptor

/// Каноническое описание плейсхолдера.
///
/// Через `PlaceholderDescriptor` приложение документирует и исполняет всё, что относится
/// к runtime-описанию плейсхолдера: отображаемое имя, описание, секцию, тип ввода,
/// источник значения, правила нормализации/валидации и token для шаблона.
///
/// Важно: descriptor по-прежнему не содержит САМО значение поля. Он только описывает,
/// как это значение должно выглядеть и откуда берётся. Сами значения живут отдельно:
/// - в `PlaceholderFieldValue` внутри формы;
/// - в `[PlaceholderKey: String]` после финального resolve.
///
/// Если `PlaceholderKey` — это identity поля, то `PlaceholderDescriptor` — его паспорт
/// для UI, справочника плейсхолдеров и общей документации системы.
struct PlaceholderDescriptor: Identifiable, Sendable {
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
    let normalizer: FieldNormalizer
    let validator: FieldValidator
    
    /// Строка токена, которую пользователь вставляет в Word-шаблон, например `<!company_name!>`.
    var token: String { "<!\(key.rawValue)!>" }
    
    /// Удобный presentation helper для UI формы и библиотеки.
    var placeholder: String { inputKind?.placeholderText ?? "" }
    
    /// `true` для полей, которые пользователь видит и может редактировать в форме.
    var acceptsUserInput: Bool { inputKind != nil }
    
    /// `true` для вычисляемых системных полей вроде `date_short`.
    var isDerived: Bool { inputKind == nil }
    
    var inputKindLabel: String? { inputKind?.label }
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
        isRequired: Bool,
        normalizer: @escaping FieldNormalizer = { $0 },
        validator: @escaping FieldValidator = { _ in nil }
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
        self.normalizer = normalizer
        self.validator = validator
    }
}
