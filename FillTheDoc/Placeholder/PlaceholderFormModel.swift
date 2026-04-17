import Foundation

struct PlaceholderFieldState: Sendable, Equatable {
    var value: String
    var issue: FieldIssue?
}

@MainActor
@Observable
final class PlaceholderFormModel {
    private(set) var editableDefinitions: [EditablePlaceholderDefinition]
    private(set) var fieldStates: [PlaceholderKey: PlaceholderFieldState]
    
    init(
        editableDefinitions: [EditablePlaceholderDefinition],
        initialValues: [PlaceholderKey: String] = [:]
    ) {
        self.editableDefinitions = editableDefinitions
        var states: [PlaceholderKey: PlaceholderFieldState] = [:]
        
        for definition in editableDefinitions {
            let initial = initialValues[definition.key] ?? ""
            let normalized = definition.normalizer(initial)
            states[definition.key] = PlaceholderFieldState(
                value: normalized,
                issue: definition.validator(normalized)
            )
        }
        self.fieldStates = states
    }
    
    // MARK: - Access
    
    func value(for key: PlaceholderKey) -> String {
        fieldStates[key]?.value ?? ""
    }
    
    func issue(for key: PlaceholderKey) -> FieldIssue? {
        fieldStates[key]?.issue
    }
    
    func setValue(_ newValue: String, for key: PlaceholderKey) {
        guard let definition = editableDefinitions.first(where: { $0.key == key }) else { return }
        let normalized = definition.normalizer(newValue)
        fieldStates[key] = PlaceholderFieldState(
            value: normalized,
            issue: definition.validator(normalized)
        )
    }
    
    func definitions(in section: EditablePlaceholderDefinition.Section) -> [EditablePlaceholderDefinition] {
        editableDefinitions.filter { $0.section == section }
    }
    
    // MARK: - Custom fields
    
    func addCustomField(title: String, key: String, placeholder: String = "") {
        let placeholderKey = PlaceholderKey(rawValue: key)
        let definition = EditablePlaceholderDefinition(
            key: placeholderKey,
            title: title,
            placeholder: placeholder,
            section: .custom,
            isRequired: false,
            normalizer: { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            validator: { _ in nil }
        )
        editableDefinitions.append(definition)
        fieldStates[placeholderKey] = PlaceholderFieldState(value: "", issue: nil)
    }
    
    func removeCustomField(key: PlaceholderKey) {
        editableDefinitions.removeAll { $0.key == key && $0.section == .custom }
        fieldStates.removeValue(forKey: key)
    }
    
    // MARK: - Bulk
    
    func editableValues() -> [PlaceholderKey: String] {
        Dictionary(uniqueKeysWithValues: editableDefinitions.map { ($0.key, value(for: $0.key)) })
    }
    
    func editableValues(in section: EditablePlaceholderDefinition.Section) -> [PlaceholderKey: String] {
        Dictionary(uniqueKeysWithValues: definitions(in: section).map { ($0.key, value(for: $0.key)) })
    }
    
    var hasErrors: Bool {
        fieldStates.values.contains { $0.issue?.severity == .error }
    }
    
    // MARK: - External issues (e.g. from DaData reference validation)
    
    /// Применяет внешние issues к полям. Не перезаписывает локальные error-ы.
    func applyExternalIssues(_ issues: [PlaceholderKey: FieldIssue]) {
        for (key, issue) in issues {
            guard var state = fieldStates[key] else { continue }
            // Не перезаписываем error от локальной валидации warning-ом от внешнего источника
            if state.issue == nil || state.issue?.severity == .warning {
                state.issue = issue
                fieldStates[key] = state
            }
        }
    }
}
