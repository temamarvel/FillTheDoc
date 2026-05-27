import Foundation

/// Фасад для построения словаря значений, пригодного для подстановки в DOCX.
///
/// Это единственное место, где pipeline собирает финальный словарь для шаблона:
/// 1. берёт текущее состояние формы;
/// 2. превращает его в `sourceValues`;
/// 3. добавляет derived/system placeholders;
/// 4. возвращает `resolvedValues`.
@MainActor
enum TemplatePlaceholderResolver {
    /// Собирает значения, пришедшие из формы, в sourceValues.
    ///
    /// Здесь остаются только пользовательские/extracted/custom поля:
    /// без derived/system значений и без дополнительной логики вычисления.
    static func makeSourceValues(
        formModel: DocumentDataFormViewModel,
        registry: PlaceholderRegistryProtocol
    ) -> [PlaceholderKey: String] {
        let allowedKeys = Set(registry.inputDescriptors.map(\.key))
        return formModel.sourceValues().filter { allowedKeys.contains($0.key) }
    }
    
    /// Собирает полный набор значений для шаблона.
    ///
    /// `resolvedValues = sourceValues + derived/system values`.
    static func resolve(
        formModel: DocumentDataFormViewModel,
        registry: PlaceholderRegistryProtocol,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [PlaceholderKey: String] {
        let sourceValues = makeSourceValues(
            formModel: formModel,
            registry: registry
        )
        var resolvedValues = sourceValues
        
        resolvedValues[.fullCompanyName] = BuiltInPlaceholderValueFactory.companyNameWithLegalForm(
            companyName: sourceValues[.companyName],
            legalForm: sourceValues[.legalForm]
        )
        resolvedValues[.fullCompanyNameExpanded] = BuiltInPlaceholderValueFactory.fullCompanyNameExpanded(
            companyName: sourceValues[.companyName],
            legalForm: sourceValues[.legalForm]
        )
        resolvedValues[.ceoRole] = BuiltInPlaceholderValueFactory.ceoRole(
            legalForm: sourceValues[.legalForm]
        )
        resolvedValues[.rules] = BuiltInPlaceholderValueFactory.rules(
            legalForm: sourceValues[.legalForm]
        )
        resolvedValues[.dateShort] = BuiltInPlaceholderValueFactory.currentDate(
            now: now,
            calendar: calendar,
            locale: locale
        )
        resolvedValues[.dateLong] = BuiltInPlaceholderValueFactory.currentDateQuoted(
            now: now,
            calendar: calendar,
            locale: locale
        )
        
        return resolvedValues
    }
}
