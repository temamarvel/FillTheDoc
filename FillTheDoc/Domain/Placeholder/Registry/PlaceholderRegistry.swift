import Foundation

// MARK: - Protocol

/// Единая точка доступа к placeholder-domain.
///
/// Реестр хранит стабильные знания о плейсхолдерах:
/// - каталог всех известных placeholder'ов для UI/scanner/documentation;
/// - runtime-policy для пользовательского ввода.
///
/// Итоговый `resolvedValues` больше не собирается внутри registry:
/// это делает `PlaceholderValueAssembler`, чтобы flow оставался линейным:
/// form state → sourceValues → derived/system values → resolvedValues.
protocol PlaceholderRegistryProtocol: Sendable {
    var allDescriptors: [PlaceholderDescriptor] { get }
    var inputDescriptors: [PlaceholderDescriptor] { get }
    var extractedDescriptors: [PlaceholderDescriptor] { get }
    var manualDescriptors: [PlaceholderDescriptor] { get }
    var customDescriptors: [PlaceholderDescriptor] { get }
    
    func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor?
    func contains(_ key: PlaceholderKey) -> Bool
    func descriptors(in section: PlaceholderSection) -> [PlaceholderDescriptor]
    func fieldPolicy(for key: PlaceholderKey) -> PlaceholderFieldPolicy
}

// MARK: - Default implementation

struct PlaceholderRegistry: PlaceholderRegistryProtocol, Sendable {
    let allDescriptors: [PlaceholderDescriptor]
    
    private let index: [PlaceholderKey: PlaceholderDescriptor]
    private let fieldPolicies: [PlaceholderKey: PlaceholderFieldPolicy]
    
    var inputDescriptors: [PlaceholderDescriptor] {
        allDescriptors
            .filter(\.acceptsUserInput)
            .sortedCanonically()
    }
    
    var extractedDescriptors: [PlaceholderDescriptor] {
        inputDescriptors.filter {
            if case .editable(source: .extracted, inputKind: _) = $0.kind {
                return true
            }
            return false
        }
    }
    
    var manualDescriptors: [PlaceholderDescriptor] {
        inputDescriptors.filter {
            if case .editable(source: .manual, inputKind: _) = $0.kind {
                return true
            }
            return false
        }
    }
    
    var customDescriptors: [PlaceholderDescriptor] {
        inputDescriptors.filter(\.isUserDefined)
    }
    
    init(customDefinitions: [PlaceholderDescriptor] = []) {
        let customDescriptors = customDefinitions
            .filter(\.isUserDefined)
            .filter { $0.section == .custom }
            .filter { !Self.builtInDescriptorIndex.keys.contains($0.key) }
        
        let all = (Self.builtInDescriptors + customDescriptors)
            .sortedCanonically()
        
        self.allDescriptors = all
        self.index = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })
        
        var fieldPolicies = Self.builtInFieldPolicies
        
        // Для встроенных choice-дескрипторов без явной policy —
        // генерируем стандартную choice-policy с validateFieldValue.
        for descriptor in Self.builtInDescriptors {
            if fieldPolicies[descriptor.key] == nil,
               case .editable(_, .choice) = descriptor.kind {
                fieldPolicies[descriptor.key] = Self.defaultCustomFieldPolicy(for: descriptor)
            }
        }
        
        for descriptor in customDescriptors {
            fieldPolicies[descriptor.key] = Self.defaultCustomFieldPolicy(for: descriptor)
        }
        self.fieldPolicies = fieldPolicies
    }
    
    func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor? {
        index[key]
    }
    
    func contains(_ key: PlaceholderKey) -> Bool {
        index[key] != nil
    }
    
    func descriptors(in section: PlaceholderSection) -> [PlaceholderDescriptor] {
        allDescriptors
            .filter { $0.section == section }
            .sortedCanonically()
    }
    
    func fieldPolicy(for key: PlaceholderKey) -> PlaceholderFieldPolicy {
        fieldPolicies[key] ?? Self.defaultFieldPolicy
    }
}

// MARK: - Built-ins

extension PlaceholderRegistry {
    static let defaultFieldPolicy = PlaceholderFieldPolicy()
    
    static func defaultCustomFieldPolicy(
        for descriptor: PlaceholderDescriptor
    ) -> PlaceholderFieldPolicy {
        switch descriptor.kind {
            case .editable(_, .text):
                let isRequired = descriptor.isRequired
                return PlaceholderFieldPolicy(
                    normalize: { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                    validate: { value in
                        if isRequired {
                            if let issue = Validators.nonEmpty(value) { return issue }
                        }
                        if !value.isEmpty && value.count > PlaceholderFieldPolicy.maxCustomTextLength {
                            return .warning("Значение длиннее \(PlaceholderFieldPolicy.maxCustomTextLength) символов — возможны проблемы с отображением в документе.")
                        }
                        return nil
                    }
                )
                
            case .editable(_, .choice(let configuration)):
                return PlaceholderFieldPolicy(
                    normalize: { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                    validate: { value in
                        // String-level fallback (вызывается для .empty → "")
                        if value.isEmpty {
                            return configuration.allowsEmptyValue
                            ? nil
                            : .error("Поле обязательно для выбора.")
                        }
                        if !configuration.options.contains(value) {
                            return .error("Выбрано неизвестное значение.")
                        }
                        return nil
                    },
                    validateFieldValue: { fieldValue in
                        switch fieldValue {
                            case .empty:
                                return configuration.allowsEmptyValue
                                ? nil
                                : .error("Поле обязательно для выбора.")
                            case .value(let selected):
                                if !configuration.options.contains(selected) {
                                    return .error("Выбрано неизвестное значение.")
                                }
                                return nil
                        }
                    }
                )
                
            case .derived:
                return PlaceholderFieldPolicy()
        }
    }
}
