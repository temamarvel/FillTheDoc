import Foundation

/// Текущее состояние одного поля placeholder-формы.
struct PlaceholderFieldState: Sendable, Equatable {
    var value: PlaceholderFieldValue
    var issue: FieldIssue?
}

/// UI-модель формы редактирования плейсхолдеров.
///
/// Форма хранит typed `PlaceholderFieldValue`, а строковое представление для шаблона
/// строится отдельно как approved values.
///
/// Это важно для choice-плейсхолдеров:
/// - UI хранит стабильный `optionID`;
/// - документ получает `replacementValue`;
/// - конкретная editing session работает на snapshot-е descriptors/value policy.
@MainActor
@Observable
final class DocumentDataFormViewModel {
    private(set) var editableDescriptors: [PlaceholderDescriptor]
    private(set) var fieldStates: [PlaceholderKey: PlaceholderFieldState]
    private let valueResolver: PlaceholderValueResolver
    
    init(
        descriptors: [PlaceholderDescriptor],
        initialValues: [PlaceholderKey: String] = [:],
        valueResolver: PlaceholderValueResolver
    ) {
        self.editableDescriptors = descriptors
        self.fieldStates = [:]
        self.valueResolver = valueResolver
        syncDescriptors(descriptors, extractedValues: initialValues)
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
    
    func syncDescriptors(
        _ descriptors: [PlaceholderDescriptor],
        extractedValues: [PlaceholderKey: String] = [:]
    ) {
        self.editableDescriptors = descriptors
        
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
    }
    
    // MARK: - Bulk
    
    func makeApprovedValues() -> [PlaceholderKey: String] {
        Dictionary(uniqueKeysWithValues: editableDescriptors.map { descriptor in
            let value = fieldStates[descriptor.key]?.value ?? initialValue(for: descriptor)
            return (descriptor.key, valueResolver.replacementValue(for: value, definition: descriptor))
        })
    }
    
    func makeApprovedValues(in section: PlaceholderSection) -> [PlaceholderKey: String] {
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

private extension DocumentDataFormViewModel {
    func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor? {
        editableDescriptors.first { $0.key == key }
    }
    
    func initialValue(
        for descriptor: PlaceholderDescriptor,
        extractedText: String? = nil
    ) -> PlaceholderFieldValue {
        switch descriptor.kind {
            case .editable(_, .text):
                return .text(extractedText ?? "")
            case .editable(_, .choice(let configuration)):
                return configuration.normalizedFieldValue(for: nil)
            case .derived:
                return .empty
        }
    }
    
    func normalize(_ value: PlaceholderFieldValue, for descriptor: PlaceholderDescriptor) -> PlaceholderFieldValue {
        switch (value, descriptor.kind) {
            case (.text(let text), .editable(_, .text(let configuration))):
                let normalizedText = configuration.trimOnCommit
                ? valueResolver.normalize(text, for: descriptor.key)
                : text
                return .text(normalizedText)
            case (.choice(let optionID), .editable(_, .choice(let configuration))):
                return configuration.normalizedFieldValue(for: optionID)
            case (.empty, .editable(_, .choice(let configuration))):
                return configuration.normalizedFieldValue(for: nil)
            case (.empty, _):
                return .empty
            default:
                return initialValue(for: descriptor)
        }
    }
    
    func validate(_ value: PlaceholderFieldValue, for descriptor: PlaceholderDescriptor) -> FieldIssue? {
        switch (value, descriptor.kind) {
            case (.text(let text), .editable(_, .text)):
                return valueResolver.validate(text, for: descriptor.key)
            case (.choice(let optionID), .editable(_, .choice(let configuration))):
                if configuration.option(withID: optionID) != nil {
                    return nil
                }
                return .error("Выбран неизвестный вариант.")
            case (.empty, .editable(_, .choice(let configuration))):
                if configuration.allowsEmptySelection {
                    return nil
                }
                return .error("Поле обязательно для выбора.")
            case (.empty, .editable(_, .text)):
                return valueResolver.validate("", for: descriptor.key)
            case (_, .derived):
                return nil
            default:
                return .error("Некорректное значение поля.")
        }
    }
}
