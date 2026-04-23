import Foundation

struct PlaceholderFieldState: Sendable, Equatable {
    var value: String
    var issue: FieldIssue?
}

@MainActor
@Observable
final class PlaceholderFormModel {
    private let registry: PlaceholderRegistryProtocol
    private(set) var editableDescriptors: [PlaceholderDescriptor]
    private(set) var fieldStates: [PlaceholderKey: PlaceholderFieldState]
    
    init(
        registry: PlaceholderRegistryProtocol,
        initialValues: [PlaceholderKey: String] = [:]
    ) {
        self.registry = registry
        let editable = registry.allDescriptors.filter { $0.kind == .editable }
        self.editableDescriptors = editable
        
        var states: [PlaceholderKey: PlaceholderFieldState] = [:]
        for descriptor in editable {
            let initial = initialValues[descriptor.key] ?? ""
            let normalized = registry.normalizer(for: descriptor.key)(initial)
            states[descriptor.key] = PlaceholderFieldState(
                value: normalized,
                issue: registry.validator(for: descriptor.key)(normalized)
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
        let normalized = registry.normalizer(for: key)(newValue)
        fieldStates[key] = PlaceholderFieldState(
            value: normalized,
            issue: registry.validator(for: key)(normalized)
        )
    }
    
    func descriptors(in section: PlaceholderSection) -> [PlaceholderDescriptor] {
        editableDescriptors.filter { $0.section == section }
    }
    
    // MARK: - Custom fields
    
    func addCustomField(title: String, key: String, placeholder: String = "") {
        let placeholderKey = PlaceholderKey(rawValue: key)
        let descriptor = PlaceholderDescriptor(
            key: placeholderKey,
            title: title,
            description: "",
            placeholder: placeholder,
            section: .custom,
            kind: .custom,
            isRequired: false
        )
        editableDescriptors.append(descriptor)
        fieldStates[placeholderKey] = PlaceholderFieldState(value: "", issue: nil)
    }
    
    func removeCustomField(key: PlaceholderKey) {
        editableDescriptors.removeAll { $0.key == key && $0.section == .custom }
        fieldStates.removeValue(forKey: key)
    }
    
    // MARK: - Bulk
    
    func editableValues() -> [PlaceholderKey: String] {
        Dictionary(uniqueKeysWithValues: editableDescriptors.map { ($0.key, value(for: $0.key)) })
    }
    
    func editableValues(in section: PlaceholderSection) -> [PlaceholderKey: String] {
        Dictionary(uniqueKeysWithValues: descriptors(in: section).map { ($0.key, value(for: $0.key)) })
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
