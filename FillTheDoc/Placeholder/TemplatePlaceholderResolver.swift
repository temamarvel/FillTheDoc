import Foundation

/// Фасад для построения словаря значений, пригодного для подстановки в DOCX.
///
/// Сам resolver не содержит domain-правил — он только собирает `PlaceholderResolutionContext`
/// из текущего состояния формы и делегирует вычисление значений в реестр.
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
        
        return registry.resolveAll(context: context)
    }
}
