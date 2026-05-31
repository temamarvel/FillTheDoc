import Foundation

/// Текущее состояние одного поля placeholder-формы.
struct PlaceholderFieldState: Hashable, Sendable {
    var value: PlaceholderFieldValue
    var localIssue: FieldIssue?
    var externalIssue: FieldIssue?
    
    var displayIssue: FieldIssue? {
        localIssue ?? externalIssue
    }
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
    private var placeholderRegistry: PlaceholderRegistryProtocol
    
    init(
        descriptors: [PlaceholderDescriptor],
        extractedDescriptorValues: [PlaceholderKey: String] = [:],
        placeholderRegistry: PlaceholderRegistryProtocol
    ) {
        self.editableDescriptors = descriptors
        self.fieldStates = [:]
        self.placeholderRegistry = placeholderRegistry
        
        syncDescriptors(descriptors: descriptors, extractedValues: extractedDescriptorValues)
    }
    
    // MARK: - Access
    
    func fieldValue(for key: PlaceholderKey) -> PlaceholderFieldValue {
        fieldStates[key]?.value ?? .empty
    }
    
    func value(for key: PlaceholderKey) -> String {
        fieldStates[key]?.value.replacementString ?? ""
    }
    
    func issue(for key: PlaceholderKey) -> FieldIssue? {
        fieldStates[key]?.displayIssue
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
        let externalIssue = fieldStates[key]?.externalIssue
        fieldStates[key] = PlaceholderFieldState(
            value: normalizedValue,
            localIssue: validate(normalizedValue, for: descriptor),
            externalIssue: externalIssue
        )
    }
    
    func descriptors(in section: PlaceholderSection) -> [PlaceholderDescriptor] {
        editableDescriptors.filter { $0.section == section }
    }
    
    // MARK: - Sync
    
    func syncDescriptors(
        descriptors: [PlaceholderDescriptor],
        extractedValues: [PlaceholderKey: String] = [:],
        placeholderRegistry: PlaceholderRegistryProtocol? = nil
    ) {
        if let placeholderRegistry {
            self.placeholderRegistry = placeholderRegistry
        }
        
        self.editableDescriptors = descriptors
        
        let allowedKeys = Set(editableDescriptors.map(\.key))
        var nextStates = fieldStates.filter { allowedKeys.contains($0.key) }
        
        for descriptor in editableDescriptors {
            if let existingState = nextStates[descriptor.key] {
                let value = existingState.value
                nextStates[descriptor.key] = PlaceholderFieldState(
                    value: value,
                    localIssue: validate(value, for: descriptor),
                    externalIssue: existingState.externalIssue
                )
            } else {
                let initial = initialValue(for: descriptor, extractedText: extractedValues[descriptor.key])
                nextStates[descriptor.key] = PlaceholderFieldState(
                    value: initial,
                    localIssue: validate(initial, for: descriptor),
                    externalIssue: nil
                )
            }
        }
        
        fieldStates = nextStates
    }
    
    // MARK: - Bulk
    
    func makeApprovedValues() -> [PlaceholderKey: String] {
        Dictionary(uniqueKeysWithValues: editableDescriptors.map { descriptor in
            let value = fieldStates[descriptor.key]?.value ?? initialValue(for: descriptor)
            return (descriptor.key, value.replacementString)
        })
    }
    
    func makeApprovedValues(in section: PlaceholderSection) -> [PlaceholderKey: String] {
        Dictionary(uniqueKeysWithValues: descriptors(in: section).map { descriptor in
            let value = fieldStates[descriptor.key]?.value ?? initialValue(for: descriptor)
            return (descriptor.key, value.replacementString)
        })
    }
    
    var companyReferenceValidationValues: [PlaceholderKey: String] {
        makeApprovedValues(in: .company)
            .compactMapValues { $0.trimmedNilIfEmpty }
    }
    
    var referenceValidationTrigger: String {
        companyReferenceValidationValues
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.rawValue)=\($0.value)" }
            .joined(separator: "|")
    }
    
    var hasErrors: Bool {
        fieldStates.values.contains { $0.displayIssue?.severity == .error }
    }
    
    // MARK: - External issues (e.g. from DaData reference validation)
    
    func applyExternalIssues(_ issues: [PlaceholderKey: FieldIssue]) {
        for key in companyReferenceFieldKeys {
            guard var state = fieldStates[key] else { continue }
            state.externalIssue = issues[key]
            fieldStates[key] = state
        }
    }
}

private extension DocumentDataFormViewModel {
    var companyReferenceFieldKeys: Set<PlaceholderKey> {
        Set(
            editableDescriptors
                .filter { $0.section == .company }
                .map(\.key)
        )
    }
    
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
                let policy = placeholderRegistry.fieldPolicy(for: descriptor.key)
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
                let policy = placeholderRegistry.fieldPolicy(for: descriptor.key)
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
        let policy = placeholderRegistry.fieldPolicy(for: descriptor.key)
        
        switch (value, descriptor.kind) {
            case (.value(let text), .editable(_, .text)):
                return policy.validate(text)
            case (_, .editable(_, .choice)):
                // Choice-валидация работает на уровне PlaceholderFieldValue,
                // чтобы различать .empty (не выбрано) и .value (конкретный выбор).
                if let fieldValueValidator = policy.validateFieldValue {
                    return fieldValueValidator(value)
                }
                // Fallback для встроенных choice без validateFieldValue
                return policy.validate(value.replacementString)
            case (.empty, .editable(_, .text)):
                return policy.validate("")
            case (_, .derived):
                return nil
        }
    }
}
