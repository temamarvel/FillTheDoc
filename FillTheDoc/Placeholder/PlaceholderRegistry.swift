import Foundation

// MARK: - Protocol

/// Единая точка доступа к placeholder-domain.
///
/// Реестр хранит стабильные знания о плейсхолдерах:
/// - каталог всех известных placeholder'ов для UI/scanner/documentation;
/// - runtime-policy для пользовательского ввода.
///
/// Итоговый `resolvedValues` больше не собирается внутри registry:
/// это делает `TemplatePlaceholderResolver`, чтобы flow оставался линейным:
/// form state → sourceValues → derived/system values → resolvedValues.
protocol PlaceholderRegistryProtocol: Sendable {
    nonisolated var allDescriptors: [PlaceholderDescriptor] { get }
    nonisolated var inputDescriptors: [PlaceholderDescriptor] { get }
    nonisolated var extractedDescriptors: [PlaceholderDescriptor] { get }
    nonisolated var manualDescriptors: [PlaceholderDescriptor] { get }
    nonisolated var customDescriptors: [PlaceholderDescriptor] { get }
    
    nonisolated func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor?
    nonisolated func contains(_ key: PlaceholderKey) -> Bool
    nonisolated func descriptors(in section: PlaceholderSection) -> [PlaceholderDescriptor]
    nonisolated func normalizer(for key: PlaceholderKey) -> FieldNormalizer
    nonisolated func validator(for key: PlaceholderKey) -> FieldValidator
}

// MARK: - Default implementation

final class PlaceholderRegistry: PlaceholderRegistryProtocol, @unchecked Sendable {
    nonisolated let allDescriptors: [PlaceholderDescriptor]
    
    nonisolated private let index: [PlaceholderKey: PlaceholderDescriptor]
    nonisolated private let behaviors: [PlaceholderKey: PlaceholderBehavior]
    
    nonisolated var inputDescriptors: [PlaceholderDescriptor] {
        allDescriptors
            .filter(\.acceptsUserInput)
            .sorted(by: Self.sortDescriptors)
    }
    
    nonisolated var extractedDescriptors: [PlaceholderDescriptor] {
        inputDescriptors.filter {
            if case .editable(source: .extracted, inputKind: _) = $0.kind {
                return true
            }
            return false
        }
    }
    
    nonisolated var manualDescriptors: [PlaceholderDescriptor] {
        inputDescriptors.filter {
            if case .editable(source: .manual, inputKind: _) = $0.kind {
                return true
            }
            return false
        }
    }
    
    nonisolated var customDescriptors: [PlaceholderDescriptor] {
        inputDescriptors.filter(\.isUserDefined)
    }
    
    nonisolated init(customDefinitions: [PlaceholderDescriptor] = []) {
        let customDescriptors = customDefinitions
            .filter(\.isUserDefined)
            .filter { $0.section == .custom }
            .filter { !Self.builtInDescriptorIndex.keys.contains($0.key) }
        
        let all = (Self.builtInDescriptors + customDescriptors)
            .sorted(by: Self.sortDescriptors)
        
        self.allDescriptors = all
        self.index = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })
        var behaviors = Self.builtInBehaviors
        for descriptor in customDescriptors {
            behaviors[descriptor.key] = Self.defaultCustomBehavior(for: descriptor)
        }
        self.behaviors = behaviors
    }
    
    nonisolated func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor? {
        index[key]
    }
    
    nonisolated func contains(_ key: PlaceholderKey) -> Bool {
        index[key] != nil
    }
    
    nonisolated func descriptors(in section: PlaceholderSection) -> [PlaceholderDescriptor] {
        allDescriptors
            .filter { $0.section == section }
            .sorted(by: Self.sortDescriptors)
    }
    
    nonisolated func normalizer(for key: PlaceholderKey) -> FieldNormalizer {
        behaviors[key]?.normalizer ?? Self.defaultBehavior.normalizer
    }
    
    nonisolated func validator(for key: PlaceholderKey) -> FieldValidator {
        behaviors[key]?.validator ?? Self.defaultBehavior.validator
    }
}

// MARK: - Built-ins

extension PlaceholderRegistry {
    nonisolated static let defaultBehavior = PlaceholderBehavior()
    
    nonisolated static func sortDescriptors(_ lhs: PlaceholderDescriptor, _ rhs: PlaceholderDescriptor) -> Bool {
        if lhs.section == rhs.section {
            if lhs.order == rhs.order {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.order < rhs.order
        }
        return lhs.section.rawValue < rhs.section.rawValue
    }
    
    nonisolated static func defaultCustomBehavior(
        for descriptor: PlaceholderDescriptor
    ) -> PlaceholderBehavior {
        let validator: FieldValidator
        
        switch descriptor.kind {
            case .editable(_, .text(let configuration)):
                if configuration.isRequired {
                    validator = { Validators.nonEmpty($0) }
                } else {
                    validator = { _ in nil }
                }
            case .editable(_, .choice(let configuration)):
                validator = { value in
                    if configuration.allowsEmptySelection || !value.isEmpty {
                        return nil
                    }
                    return .error("Поле обязательно для выбора.")
                }
            case .derived:
                validator = { _ in nil }
        }
        
        return PlaceholderBehavior(
            normalizer: { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            validator: validator
        )
    }
}
