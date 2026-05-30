import Foundation

/// Текущее состояние одного поля placeholder-формы.
struct PlaceholderFieldState: Sendable, Equatable {
    var value: PlaceholderFieldValue
    var issue: FieldIssue?
}

/// UI-модель формы редактирования плейсхолдеров.
///
/// Форма хранит canonical typed `PlaceholderFieldValue`, а строковое представление
/// для шаблона строится отдельно как approved values.
///
/// Это важно для choice-плейсхолдеров:
/// - и текст, и choice хранят сразу replacement value;
/// - документ получает ту же самую строку без дополнительных преобразований;
/// - конкретная editing session работает на snapshot-е descriptors/value policy.
@MainActor
@Observable
final class DocumentDataFormViewModel {
    private(set) var editableDescriptors: [PlaceholderDescriptor]
    private(set) var fieldStates: [PlaceholderKey: PlaceholderFieldState]
    private let palaceholderRegistry: PlaceholderRegistryProtocol
    private let placeholderValueResolver: PlaceholderValueResolver
    
    init(
        descriptors: [PlaceholderDescriptor],
        extractedDescriptorValues: [PlaceholderKey: String] = [:],
        palaceholderRegistry: PlaceholderRegistryProtocol,
        placeholderValueResolver: PlaceholderValueResolver = PlaceholderValueResolver()
    ) {
        self.editableDescriptors = descriptors
        self.fieldStates = [:]
        self.palaceholderRegistry = palaceholderRegistry
        self.placeholderValueResolver = placeholderValueResolver
        syncDescriptors(descriptors: descriptors, extractedDescriptorValues: extractedDescriptorValues)
    }
    
    // MARK: - Access
    
    func fieldValue(for key: PlaceholderKey) -> PlaceholderFieldValue {
        fieldStates[key]?.value ?? .empty
    }
    
    func value(for key: PlaceholderKey) -> String {
        fieldStates[key]?.value.stringValue ?? ""
    }
    
    func issue(for key: PlaceholderKey) -> FieldIssue? {
        fieldStates[key]?.issue
    }
    
    func setValue(_ newValue: String, for key: PlaceholderKey) {
        if newValue.isEmpty {
            setFieldValue(.empty, for: key)
        } else {
            setFieldValue(.value(newValue), for: key)
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
        descriptors: [PlaceholderDescriptor],
        extractedDescriptorValues: [PlaceholderKey: String] = [:]
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
                let initial = initialValue(for: descriptor, extractedText: extractedDescriptorValues[descriptor.key])
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
            return (descriptor.key, placeholderValueResolver.replacementValue(for: value, descriptor: descriptor))
        })
    }
    
    func makeApprovedValues(in section: PlaceholderSection) -> [PlaceholderKey: String] {
        Dictionary(uniqueKeysWithValues: descriptors(in: section).map { descriptor in
            let value = fieldStates[descriptor.key]?.value ?? initialValue(for: descriptor)
            return (descriptor.key, placeholderValueResolver.replacementValue(for: value, descriptor: descriptor))
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
                let rawText = extractedText ?? ""
                let policy = palaceholderRegistry.fieldPolicy(for: descriptor.key)
                return .value(policy.normalize(rawText))
            case .editable(_, .choice(let configuration)):
                return configuration.normalizedFieldValue(for: extractedText)
            case .derived:
                return .empty
        }
    }
    
    func normalize(_ value: PlaceholderFieldValue, for descriptor: PlaceholderDescriptor) -> PlaceholderFieldValue {
        switch (value, descriptor.kind) {
            case (.value(let text), .editable(_, .text)):
                let policy = palaceholderRegistry.fieldPolicy(for: descriptor.key)
                return .value(policy.normalize(text))
            case (.value(let selectedValue), .editable(_, .choice(let configuration))):
                return configuration.normalizedFieldValue(for: selectedValue)
            case (.value, .derived):
                return .empty
            case (.empty, .editable(_, .choice(let configuration))):
                return configuration.normalizedFieldValue(for: nil)
            case (.empty, _):
                return .empty
        }
    }
    
    func validate(_ value: PlaceholderFieldValue, for descriptor: PlaceholderDescriptor) -> FieldIssue? {
        switch (value, descriptor.kind) {
            case (.value(let text), .editable(_, .text)):
                let policy = palaceholderRegistry.fieldPolicy(for: descriptor.key)
                return policy.validate(text)
            case (.value(let selectedValue), .editable(_, .choice(let configuration))):
                if configuration.options.contains(selectedValue) {
                    return nil
                }
                return .error("Выбрано неизвестное значение.")
            case (.empty, .editable(_, .choice(let configuration))):
                if configuration.allowsEmptyValue {
                    return nil
                }
                return .error("Поле обязательно для выбора.")
            case (.empty, .editable(_, .text)):
                let policy = palaceholderRegistry.fieldPolicy(for: descriptor.key)
                return policy.validate("")
            case (_, .derived):
                return nil
        }
    }
}
