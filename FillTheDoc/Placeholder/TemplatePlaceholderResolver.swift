import Foundation

/// Фасад для построения словаря значений, пригодного для подстановки в DOCX.
///
/// Сам resolver не содержит domain-правил — он только собирает `PlaceholderResolutionContext`
/// из текущего состояния формы и делегирует вычисление значений в реестр.
///
/// Его смысл в том, чтобы orchestration/UI-слой не занимался вручную:
/// - сборкой editable и custom значений;
/// - созданием context-объекта;
/// - вызовом множества отдельных resolver'ов.
enum TemplatePlaceholderResolver {
    /// Собирает полный набор значений для шаблона на основе текущего состояния формы.
    ///
    /// На выходе получается словарь, в котором уже смешаны:
    /// - подтверждённые пользователем editable значения;
    /// - custom поля;
    /// - derived/system placeholders, вычисленные реестром.
    static func resolve(
        formModel: PlaceholderFormModel,
        registry: PlaceholderRegistryProtocol,
        now: Date = .now
    ) -> [PlaceholderKey: String] {
        let allValues = formModel.editableValues()
        // Custom values выделяются отдельно, потому что registry может трактовать их иначе,
        // чем встроенные поля, и должен иметь возможность сохранить их даже без built-in descriptor'а.
        let customValues = formModel.editableValues(in: .custom)
        
        let context = PlaceholderResolutionContext(
            editableValues: allValues,
            customValues: customValues,
            now: now
        )
        
        return registry.resolveAll(context: context)
    }
}
