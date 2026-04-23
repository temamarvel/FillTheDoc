import Foundation

enum TemplatePlaceholderResolver {
    /// Resolves all placeholder values using the unified registry + form model.
    static func resolve(
        formModel: PlaceholderFormModel,
        registry: PlaceholderRegistryProtocol,
        now: Date = .now
    ) -> [String: String] {
        let allValues = formModel.editableValues()
        let customValues = formModel.editableValues(in: .custom)
        
        let context = PlaceholderResolutionContext(
            editableValues: allValues,
            customValues: customValues,
            now: now
        )
        
        if let defaultRegistry = registry as? DefaultPlaceholderRegistry {
            return defaultRegistry.resolveAll(context: context)
        }
        
        // Fallback: resolve through protocol
        var result: [String: String] = [:]
        for descriptor in registry.allDescriptors {
            if let value = registry.resolve(descriptor.key, context: context) {
                result[descriptor.key.rawValue] = value
            }
        }
        for (key, value) in customValues where result[key.rawValue] == nil {
            result[key.rawValue] = value
        }
        return result
    }
}
