import Foundation

/// Текущее состояние одного поля placeholder-формы.
struct PlaceholderFieldState: Sendable, Equatable {
    var value: String
    var issue: FieldIssue?
}

/// UI-модель формы редактирования плейсхолдеров.
///
/// Это промежуточный слой между SwiftUI и placeholder-domain.
/// Модель не знает про конкретные SwiftUI-элементы, но знает:
/// - какие built-in placeholder'ы редактируемы,
/// - как нормализовать ввод,
/// - как валидировать поле,
/// - как собрать актуальные значения для дальнейшего резолва.
///
/// Благодаря этому `DocumentDataFormView` остаётся в основном декларативным UI,
/// а правила поведения формы не размазываются по binding'ам и callback'ам.
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
        // Нормализация и валидация живут в registry, чтобы форма не дублировала domain-правила.
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
        // Custom field пока хранится как локальное runtime-расширение формы.
        // Если позже появится persistent store, он должен поставлять такие descriptor'ы в registry/catalog.
        // Пока это компромисс в пользу простоты: custom поля существуют в рамках текущей сессии редактирования.
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
        // Внешняя reference-validation может добавлять предупреждения,
        // но не должна безусловно перетирать локальные blocking-errors формы.
        for (key, issue) in issues {
            guard var state = fieldStates[key] else { continue }
            if state.issue == nil || state.issue?.severity == .warning {
                state.issue = issue
                fieldStates[key] = state
            }
        }
    }
}
