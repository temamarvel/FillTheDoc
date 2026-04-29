import Foundation

nonisolated struct CustomPlaceholdersFile: Codable, Hashable, Sendable {
    var schemaVersion: Int
    var placeholders: [CustomPlaceholderDefinition]
    
    init(
        schemaVersion: Int = 2,
        placeholders: [CustomPlaceholderDefinition]
    ) {
        self.schemaVersion = schemaVersion
        self.placeholders = placeholders
    }
}

nonisolated struct PersistedTextInputConfiguration: Codable, Hashable, Sendable {
    var placeholder: String
    var isRequired: Bool
    var editorStyle: TextEditorStyle
    
    init(
        placeholder: String = "",
        isRequired: Bool = false,
        editorStyle: TextEditorStyle = .singleLine
    ) {
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.editorStyle = editorStyle
    }
}

extension PersistedTextInputConfiguration {
    private enum CodingKeys: String, CodingKey {
        case placeholder
        case isRequired
        case editorStyle
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder) ?? ""
        self.isRequired = try container.decodeIfPresent(Bool.self, forKey: .isRequired) ?? false
        self.editorStyle = try container.decodeIfPresent(TextEditorStyle.self, forKey: .editorStyle) ?? .singleLine
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(placeholder, forKey: .placeholder)
        try container.encode(isRequired, forKey: .isRequired)
        try container.encode(editorStyle, forKey: .editorStyle)
    }
}

nonisolated struct PersistedChoiceInputConfiguration: Codable, Hashable, Sendable {
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

nonisolated enum PersistedPlaceholderInputKind: Hashable, Sendable {
    case text(PersistedTextInputConfiguration)
    case choice(PersistedChoiceInputConfiguration)
}

extension PersistedPlaceholderInputKind: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case configuration
    }
    
    private enum Kind: String, Codable {
        case text
        case multilineText
        case choice
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
            case .text:
                let configuration = try container.decode(PersistedTextInputConfiguration.self, forKey: .configuration)
                self = .text(configuration)
            case .multilineText:
                let configuration = try container.decode(PersistedTextInputConfiguration.self, forKey: .configuration)
                self = .text(
                    PersistedTextInputConfiguration(
                        placeholder: configuration.placeholder,
                        isRequired: configuration.isRequired,
                        editorStyle: .multiline()
                    )
                )
            case .choice:
                let configuration = try container.decode(PersistedChoiceInputConfiguration.self, forKey: .configuration)
                self = .choice(configuration)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .text(let configuration):
                try container.encode(Kind.text, forKey: .type)
                try container.encode(configuration, forKey: .configuration)
            case .choice(let configuration):
                try container.encode(Kind.choice, forKey: .type)
                try container.encode(configuration, forKey: .configuration)
        }
    }
}

nonisolated struct CustomPlaceholderDefinition: Identifiable, Codable, Hashable, Sendable {
    var id: PlaceholderKey { key }
    var key: PlaceholderKey
    var title: String
    var description: String?
    var inputKind: PersistedPlaceholderInputKind
    var order: Int
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(
        key: PlaceholderKey,
        title: String,
        description: String? = nil,
        inputKind: PersistedPlaceholderInputKind,
        order: Int,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.key = key
        self.title = title
        self.description = description
        self.inputKind = inputKind
        self.order = order
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension PersistedPlaceholderInputKind {
    nonisolated func makeRuntimeInputKind() -> PlaceholderInputKind {
        switch self {
            case .text(let configuration):
                return .text(
                    TextInputConfiguration(
                        placeholder: configuration.placeholder,
                        isRequired: configuration.isRequired,
                        editorStyle: configuration.editorStyle
                    )
                )
            case .choice(let configuration):
                return .choice(
                    ChoiceInputConfiguration(
                        options: configuration.options,
                        defaultOptionID: configuration.defaultOptionID,
                        allowsEmptySelection: configuration.allowsEmptySelection,
                        emptyTitle: configuration.emptyTitle,
                        presentationStyle: configuration.presentationStyle
                    )
                )
        }
    }
}

extension CustomPlaceholderDefinition {
    nonisolated func makeRuntimeDefinition() -> PlaceholderDescriptor {
        let runtimeInputKind = inputKind.makeRuntimeInputKind()
        let isRequired: Bool
        let validator: FieldValidator
        
        switch inputKind {
            case .text(let configuration):
                isRequired = configuration.isRequired
                if configuration.isRequired {
                    validator = Validators.nonEmpty
                } else {
                    validator = { _ in nil }
                }
            case .choice(let configuration):
                isRequired = !configuration.allowsEmptySelection
                validator = { _ in nil }
        }
        
        return PlaceholderDescriptor(
            key: key,
            title: title,
            description: description ?? "",
            section: .custom,
            order: order,
            valueSource: .manual,
            inputKind: runtimeInputKind,
            isUserDefined: true,
            isRequired: isRequired,
            normalizer: { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            validator: validator
        )
    }
}
