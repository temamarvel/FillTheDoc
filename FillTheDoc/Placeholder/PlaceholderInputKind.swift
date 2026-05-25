//
//  PlaceholderInputKind.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


nonisolated enum PlaceholderInputKind: Hashable, Codable, Sendable {
    case text(TextInputConfiguration)
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
            case .choice:
                return "Выбор"
        }
    }
    
    var isRequired: Bool {
        switch self {
            case .text(let configuration):
                return configuration.isRequired
            case .choice(let configuration):
                return !configuration.allowsEmptySelection
        }
    }
    
    var textEditorStyle: TextEditorStyle? {
        guard case .text(let configuration) = self else { return nil }
        return configuration.editorStyle
    }
    
    var textEditorStyleLabel: String? {
        textEditorStyle?.label
    }
    
    var signatureFragment: String {
        switch self {
            case .text(let configuration):
                return "text|\(configuration.isRequired)|\(configuration.trimOnCommit)|\(configuration.editorStyle.signatureFragment)"
            case .choice(let configuration):
                let optionsLine = configuration.options
                    .map { "\($0.id):\($0.title):\($0.replacementValue)" }
                    .joined(separator: ";")
                return "choice|\(optionsLine)|\(configuration.defaultOptionID ?? "")|\(configuration.allowsEmptySelection)|\(configuration.emptyTitle)|\(configuration.presentationStyle.rawValue)"
        }
    }
    
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
                self = .text(try container.decode(TextInputConfiguration.self, forKey: .configuration))
            case .multilineText:
                let configuration = try container.decode(TextInputConfiguration.self, forKey: .configuration)
                self = .text(
                    TextInputConfiguration(
                        isRequired: configuration.isRequired,
                        trimOnCommit: configuration.trimOnCommit,
                        editorStyle: configuration.editorStyle == .singleLine ? .multiline() : configuration.editorStyle
                    )
                )
            case .choice:
                self = .choice(try container.decode(ChoiceInputConfiguration.self, forKey: .configuration))
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
