import Foundation

nonisolated enum CustomPlaceholderDraftInputKind: Equatable, Sendable {
    case text(
        valueSource: PlaceholderValueSource,
        editorStyle: TextEditorStyle
    )
    case choice(
        options: [EditableChoiceOption]
    )
}

nonisolated struct CustomPlaceholderDraft: Equatable, Sendable {
    var title: String
    var key: String
    var description: String
    var inputKind: CustomPlaceholderDraftInputKind
    var isRequired: Bool
    var exampleValue: String?
    var displayOrder: Int
    
    nonisolated init(
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
    
    nonisolated init(descriptor: PlaceholderDescriptor) {
        title = descriptor.title
        key = descriptor.key.rawValue
        description = descriptor.description
        isRequired = descriptor.isRequired
        exampleValue = descriptor.exampleValue
        displayOrder = descriptor.order
        
        switch descriptor.kind {
            case .editable(let source, let inputKind):
                switch inputKind {
                    case .text(let editorStyle):
                        self.inputKind = .text(
                            valueSource: source,
                            editorStyle: editorStyle
                        )
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
    
    nonisolated static func new(displayOrder: Int = 0) -> CustomPlaceholderDraft {
        CustomPlaceholderDraft(
            title: "",
            key: "",
            description: "",
            inputKind: .text(
                valueSource: .extracted,
                editorStyle: .singleLine
            ),
            isRequired: false,
            exampleValue: nil,
            displayOrder: displayOrder
        )
    }
    
    nonisolated func makeDescriptor() -> PlaceholderDescriptor {
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
    nonisolated func makeKind() -> PlaceholderKind {
        switch inputKind {
            case .text(let valueSource, let editorStyle):
                return .editable(
                    source: valueSource,
                    inputKind: .text(editorStyle: editorStyle)
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
    
    nonisolated func normalizedChoiceOptions(from options: [EditableChoiceOption]) -> [String] {
        options
            .map(\.value)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

extension CustomPlaceholderDraft {
    nonisolated var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    nonisolated var normalizedKey: String {
        key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    nonisolated var normalizedDescription: String? {
        let value = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    
    nonisolated var normalizedExampleValue: String? {
        guard let exampleValue else { return nil }
        let value = exampleValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    
    nonisolated var isTextInput: Bool {
        if case .text = inputKind {
            return true
        }
        return false
    }
    
    nonisolated var isChoiceInput: Bool {
        if case .choice = inputKind {
            return true
        }
        return false
    }
}
