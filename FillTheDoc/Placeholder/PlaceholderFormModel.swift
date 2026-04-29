import Foundation

/// Текущее состояние одного поля placeholder-формы.
struct PlaceholderFieldState: Sendable, Equatable {
    var value: PlaceholderFieldValue
    var issue: FieldIssue?
}

/// UI-модель формы редактирования плейсхолдеров.
///
/// Главный architectural сдвиг этой версии: форма больше не хранит «всё как строки».
/// Вместо этого она держит typed `PlaceholderFieldValue`, а строки для DOCX строятся
/// отдельно через `PlaceholderValueResolver`.
///
/// Это важно для choice-плейсхолдеров:
/// - UI хранит стабильный `optionID`;
/// - документ получает `replacementValue`;
/// - повторная extraction обновляет только extracted-поля и не сбрасывает manual выбор.
@MainActor
@Observable
final class PlaceholderFormModel {
    private(set) var registry: PlaceholderRegistryProtocol
    private let valueResolver = PlaceholderValueResolver()
    
    private(set) var editableDescriptors: [PlaceholderDescriptor]
    private(set) var fieldStates: [PlaceholderKey: PlaceholderFieldState]
    
    init(
        registry: PlaceholderRegistryProtocol,
        initialValues: [PlaceholderKey: String] = [:]
    ) {
        self.registry = registry
        self.editableDescriptors = registry.inputDescriptors
        self.fieldStates = [:]
        syncDefinitions(with: registry, extractedValues: initialValues)
    }
    
    // MARK: - Access
    
    func fieldValue(for key: PlaceholderKey) -> PlaceholderFieldValue {
        fieldStates[key]?.value ?? .empty
    }
    
    func value(for key: PlaceholderKey) -> String {
        fieldStates[key]?.value.textValue ?? ""
    }
    
    func choiceSelection(for key: PlaceholderKey) -> String? {
        fieldStates[key]?.value.choiceOptionID
    }
    
    func issue(for key: PlaceholderKey) -> FieldIssue? {
        fieldStates[key]?.issue
    }
    
    func setValue(_ newValue: String, for key: PlaceholderKey) {
        setFieldValue(.text(newValue), for: key)
    }
    
    func setChoiceSelection(_ optionID: String?, for key: PlaceholderKey) {
        if let optionID {
            setFieldValue(.choice(optionID: optionID), for: key)
        } else {
            setFieldValue(.empty, for: key)
        }
    }
    
    func setFieldValue(_ newValue: PlaceholderFieldValue, for key: PlaceholderKey) {
        guard let descriptor = descriptor(for: key) else { return }
        let normalizedValue = normalize(newValue, for: descriptor)
        fieldStates[key] = PlaceholderFieldState(
            value: normalizedValue,
            issue: validate(normalizedValue, for: descriptor)
        )
    }
    
    func descriptors(in section: PlaceholderSection) -> [PlaceholderDescriptor] {
        editableDescriptors.filter { $0.section == section }
    }
    
    // MARK: - Sync
    
    func syncDefinitions(
        with registry: PlaceholderRegistryProtocol,
        extractedValues: [PlaceholderKey: String] = [:]
    ) {
        self.registry = registry
        self.editableDescriptors = registry.inputDescriptors
        
        let allowedKeys = Set(editableDescriptors.map(\.key))
        var nextStates = fieldStates.filter { allowedKeys.contains($0.key) }
        
        for descriptor in editableDescriptors {
            if let existingState = nextStates[descriptor.key] {
                let normalized = normalize(existingState.value, for: descriptor)
                nextStates[descriptor.key] = PlaceholderFieldState(
                    value: normalized,
                    issue: validate(normalized, for: descriptor)
                )
            } else {
                let initial = initialValue(for: descriptor, extractedText: extractedValues[descriptor.key])
                nextStates[descriptor.key] = PlaceholderFieldState(
                    value: initial,
                    issue: validate(initial, for: descriptor)
                )
            }
        }
        
        fieldStates = nextStates
        applyExtractedValues(extractedValues)
    }
    
    func applyExtractedValues(_ extractedValues: [PlaceholderKey: String]) {
        for descriptor in editableDescriptors where descriptor.valueSource == .extracted {
            switch descriptor.inputKind {
                case .some(.text):
                    let value = extractedValues[descriptor.key] ?? ""
                    let fieldValue = normalize(.text(value), for: descriptor)
                    fieldStates[descriptor.key] = PlaceholderFieldState(
                        value: fieldValue,
                        issue: validate(fieldValue, for: descriptor)
                    )
                case .some(.choice):
                    assertionFailure("Choice placeholders must not be extracted.")
                case .none:
                    continue
            }
        }
        
        for descriptor in editableDescriptors where fieldStates[descriptor.key] == nil {
            let initial = initialValue(for: descriptor, extractedText: extractedValues[descriptor.key])
            fieldStates[descriptor.key] = PlaceholderFieldState(
                value: initial,
                issue: validate(initial, for: descriptor)
            )
        }
    }
    
    // MARK: - Bulk
    
    func editableValues() -> [PlaceholderKey: String] {
        Dictionary(uniqueKeysWithValues: editableDescriptors.map { descriptor in
            let value = fieldStates[descriptor.key]?.value ?? initialValue(for: descriptor)
            return (descriptor.key, valueResolver.replacementValue(for: value, definition: descriptor))
        })
    }
    
    func editableValues(in section: PlaceholderSection) -> [PlaceholderKey: String] {
        Dictionary(uniqueKeysWithValues: descriptors(in: section).map { descriptor in
            let value = fieldStates[descriptor.key]?.value ?? initialValue(for: descriptor)
            return (descriptor.key, valueResolver.replacementValue(for: value, definition: descriptor))
        })
    }
    
    var hasErrors: Bool {
        fieldStates.values.contains { $0.issue?.severity == .error }
    }
    
    // MARK: - External issues (e.g. from DaData reference validation)
    
    func applyExternalIssues(_ issues: [PlaceholderKey: FieldIssue]) {
        for (key, issue) in issues {
            guard var state = fieldStates[key] else { continue }
            if state.issue == nil || state.issue?.severity == .warning {
                state.issue = issue
                fieldStates[key] = state
            }
        }
    }
}

private extension PlaceholderFormModel {
    func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor? {
        editableDescriptors.first { $0.key == key }
    }
    
    func initialValue(
        for descriptor: PlaceholderDescriptor,
        extractedText: String? = nil
    ) -> PlaceholderFieldValue {
        switch descriptor.inputKind {
            case .some(.text):
                return .text(extractedText ?? "")
            case .some(.choice(let configuration)):
                if let defaultOptionID = configuration.defaultOptionID,
                   configuration.options.contains(where: { $0.id == defaultOptionID }) {
                    return .choice(optionID: defaultOptionID)
                }
                if !configuration.allowsEmptySelection,
                   let firstOptionID = configuration.options.first?.id {
                    return .choice(optionID: firstOptionID)
                }
                return .empty
            case .none:
                return .empty
        }
    }
    
    func normalize(_ value: PlaceholderFieldValue, for descriptor: PlaceholderDescriptor) -> PlaceholderFieldValue {
        switch (value, descriptor.inputKind) {
            case (.text(let text), .some(.text(let configuration))):
                return .text(configuration.trimOnCommit ? descriptor.normalizer(text) : text)
            case (.choice(let optionID), .some(.choice(let configuration))):
                if configuration.options.contains(where: { $0.id == optionID }) {
                    return .choice(optionID: optionID)
                }
                if let defaultOptionID = configuration.defaultOptionID,
                   configuration.options.contains(where: { $0.id == defaultOptionID }) {
                    return .choice(optionID: defaultOptionID)
                }
                if !configuration.allowsEmptySelection,
                   let firstOptionID = configuration.options.first?.id {
                    return .choice(optionID: firstOptionID)
                }
                return .empty
            case (.empty, .some(.choice(let configuration))):
                if let defaultOptionID = configuration.defaultOptionID,
                   configuration.options.contains(where: { $0.id == defaultOptionID }) {
                    return .choice(optionID: defaultOptionID)
                }
                if !configuration.allowsEmptySelection,
                   let firstOptionID = configuration.options.first?.id {
                    return .choice(optionID: firstOptionID)
                }
                return .empty
            case (.empty, _):
                return .empty
            default:
                return initialValue(for: descriptor)
        }
    }
    
    func validate(_ value: PlaceholderFieldValue, for descriptor: PlaceholderDescriptor) -> FieldIssue? {
        switch (value, descriptor.inputKind) {
            case (.text(let text), .some(.text)):
                return descriptor.validator(text)
            case (.choice(let optionID), .some(.choice(let configuration))):
                if configuration.options.contains(where: { $0.id == optionID }) {
                    return nil
                }
                return .error("Выбран неизвестный вариант.")
            case (.empty, .some(.choice(let configuration))):
                if configuration.allowsEmptySelection {
                    return nil
                }
                return .error("Поле обязательно для выбора.")
            case (.empty, .some(.text)):
                return descriptor.validator("")
            case (_, nil):
                return nil
            default:
                return .error("Некорректное значение поля.")
        }
    }
}
