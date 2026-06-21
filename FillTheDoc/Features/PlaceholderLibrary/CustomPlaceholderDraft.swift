import Foundation

enum CustomPlaceholderDraftInputKind: Hashable, Sendable {
    case text(valueSource: PlaceholderValueSource)
    case choice(
        options: [EditableChoiceOption]
    )
}

struct CustomPlaceholderDraft: Equatable, Sendable {
    var title: String
    var key: String
    var description: String
    var inputKind: CustomPlaceholderDraftInputKind
    var isRequired: Bool
    var exampleValue: String?
    var displayOrder: Int
    
    init(
        title: String,
        key: String,
        description: String,
        inputKind: CustomPlaceholderDraftInputKind,
        isRequired: Bool,
        exampleValue: String?,
        displayOrder: Int
    ) {
        self.title = title
        self.key = key
        self.description = description
        self.inputKind = inputKind
        self.isRequired = isRequired
        self.exampleValue = exampleValue
        self.displayOrder = displayOrder
    }
    
    init(descriptor: PlaceholderDescriptor) {
        title = descriptor.title
        key = descriptor.key.rawValue
        description = descriptor.description
        isRequired = descriptor.isRequired
        exampleValue = descriptor.exampleValue
        displayOrder = descriptor.order
        
        switch descriptor.kind {
            case .editable(let source, let inputKind):
                switch inputKind {
                    case .text:
                        self.inputKind = .text(valueSource: source)
                    case .choice(let configuration):
                        self.inputKind = .choice(
                            options: configuration.options.map {
                                EditableChoiceOption(value: $0)
                            }
                        )
                }
            case .derived:
                preconditionFailure("Custom placeholder editor does not support computed placeholders.")
        }
    }
    
    static func new(displayOrder: Int = 0) -> CustomPlaceholderDraft {
        CustomPlaceholderDraft(
            title: "",
            key: "",
            description: "",
            inputKind: .text(valueSource: .extracted),
            isRequired: false,
            exampleValue: nil,
            displayOrder: displayOrder
        )
    }
    
    func makeDescriptor() -> PlaceholderDescriptor {
        PlaceholderDescriptor(
            key: PlaceholderKey(rawValue: normalizedKey),
            title: normalizedTitle,
            description: normalizedDescription ?? "",
            section: .custom,
            order: displayOrder,
            kind: makeKind(),
            isUserDefined: true,
            exampleValue: normalizedExampleValue,
            isRequired: isRequired
        )
    }
}

private extension CustomPlaceholderDraft {
    func makeKind() -> PlaceholderKind {
        switch inputKind {
            case .text(let valueSource):
                return .editable(
                    source: valueSource,
                    inputKind: .text
                )
            case .choice(let options):
                return .editable(
                    source: .manual,
                    inputKind: .choice(
                        ChoiceInputConfiguration(
                            options: normalizedChoiceOptions(from: options),
                            allowsEmptyValue: !isRequired,
                            emptyTitle: "Не выбрано"
                        )
                    )
                )
        }
    }
    
    func normalizedChoiceOptions(from options: [EditableChoiceOption]) -> [String] {
        options
            .map(\.value)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

extension CustomPlaceholderDraft {
    var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var normalizedKey: String {
        key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    var normalizedDescription: String? {
        let value = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    
    var normalizedExampleValue: String? {
        guard let exampleValue else { return nil }
        let value = exampleValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    
    var isTextInput: Bool {
        if case .text = inputKind {
            return true
        }
        return false
    }
    
    var isChoiceInput: Bool {
        if case .choice = inputKind {
            return true
        }
        return false
    }
}
