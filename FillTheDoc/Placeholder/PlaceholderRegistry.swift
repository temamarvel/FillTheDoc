import Foundation

// MARK: - Protocol

/// Единая точка доступа к placeholder-domain.
///
/// Реестр хранит одновременно два вида знаний:
/// - каталог всех известных placeholder'ов для UI/scanner/documentation;
/// - правила получения итоговых строк для шаблона.
///
/// Важный архитектурный сдвиг этой версии: input-поля теперь описываются не как
/// «просто строка с placeholder'ом», а как полноценные runtime-definition'ы
/// с `valueSource` и `inputKind`. Это позволяет безопасно добавлять choice-поля,
/// не ломая ни LLM-схему, ни DOCX fill.
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
    nonisolated func resolve(_ key: PlaceholderKey, context: PlaceholderResolutionContext) -> String?
    nonisolated func resolveAll(context: PlaceholderResolutionContext) -> [PlaceholderKey: String]
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
    
    nonisolated func resolve(_ key: PlaceholderKey, context: PlaceholderResolutionContext) -> String? {
        if let resolver = behaviors[key]?.resolver {
            return resolver(context)
        }
        return context.editableValues[key] ?? context.customValues[key]
    }
    
    nonisolated func resolveAll(context: PlaceholderResolutionContext) -> [PlaceholderKey: String] {
        var result: [PlaceholderKey: String] = [:]
        
        for descriptor in allDescriptors {
            if let value = resolve(descriptor.key, context: context) {
                result[descriptor.key] = value
            }
        }
        
        for (key, value) in context.customValues where result[key] == nil {
            result[key] = value
        }
        
        return result
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
                    validator = Validators.nonEmpty
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
    
   
    
    nonisolated static func formatDateLong(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .current
        formatter.dateFormat = "«dd» MMMM yyyy 'г.'"
        return formatter.string(from: date)
    }
    
    nonisolated static func formatDateShort(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .current
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
    
}

