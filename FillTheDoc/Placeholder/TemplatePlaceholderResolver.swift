import Foundation

/// Фасад для построения словаря значений, пригодного для подстановки в DOCX.
///
/// Это единственное место, где pipeline собирает финальный словарь для шаблона:
/// 1. берёт approved значения, подтверждённые пользователем;
/// 2. фильтрует их до допустимых input placeholder'ов;
/// 3. добавляет derived/system placeholders;
/// 4. возвращает `resolvedValues`.
enum TemplatePlaceholderResolver {
    /// Собирает подтверждённые пользователем данные в sourceValues.
    ///
    /// Здесь остаются только пользовательские/extracted/custom поля:
    /// без derived/system значений и без дополнительной логики вычисления.
    static func makeSourceValues(
        approvedValues: [PlaceholderKey: String],
        registry: PlaceholderRegistryProtocol
    ) -> [PlaceholderKey: String] {
        let allowedKeys = Set(registry.inputDescriptors.map(\.key))
        return approvedValues.filter { allowedKeys.contains($0.key) }
    }
    
    /// Собирает полный набор значений для шаблона.
    ///
    /// `resolvedValues = sourceValues + derived/system values`.
    static func resolve(
        approvedValues: [PlaceholderKey: String],
        registry: PlaceholderRegistryProtocol,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [PlaceholderKey: String] {
        let sourceValues = makeSourceValues(
            approvedValues: approvedValues,
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
