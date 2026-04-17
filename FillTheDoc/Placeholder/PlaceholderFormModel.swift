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
            id: placeholderKey,
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

    // MARK: - Reference validation (company-specific)

    private var validationTask: Task<Void, Never>?
    private var lastLookupKey: String?

    func scheduleReferenceValidation(using validator: CompanyDetailsValidator) {
        let ogrn = fieldStates[PlaceholderKey(rawValue: "ogrn")]?.value.trimmedNilIfEmpty
        let inn = fieldStates[PlaceholderKey(rawValue: "inn")]?.value.trimmedNilIfEmpty
        let lookupKey = ogrn ?? inn
        guard let lookupKey, !lookupKey.isEmpty else { return }
        if lookupKey == lastLookupKey { return }

        validationTask?.cancel()
        validationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                await self.applyReferenceValidation(using: validator)
                self.lastLookupKey = lookupKey
            } catch {}
        }
    }

    func applyReferenceValidation(using validator: CompanyDetailsValidator) async {
        // Convert to old-style FieldState dict for the validator
        let companyDefs = definitions(in: .company)
        var oldFields: [CompanyDetails.CompanyDetailsKeys: FieldState] = [:]
        for def in companyDefs {
            guard let codingKey = CompanyDetails.CompanyDetailsKeys(rawValue: def.key.rawValue) else { continue }
            let state = fieldStates[def.key]
            oldFields[codingKey] = FieldState(value: state?.value, issue: state?.issue)
        }

        let result = await validator.validateFieldsWithReference(fields: oldFields)

        // Write back
        for (codingKey, fieldState) in result {
            let pk = PlaceholderKey(rawValue: codingKey.rawValue)
            if var current = fieldStates[pk] {
                // Only overwrite if reference found an issue and local didn't have error
                if fieldState.issue != nil && (current.issue == nil || current.issue?.severity == .warning) {
                    current.issue = fieldState.issue
                    fieldStates[pk] = current
                }
            }
        }
    }
}
