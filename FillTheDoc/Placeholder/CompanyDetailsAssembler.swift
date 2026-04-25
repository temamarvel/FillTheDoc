import Foundation

/// Двусторонний mapper между `CompanyDetails` и placeholder-словарями формы.
///
/// Это boundary helper между двумя представлениями одних и тех же данных:
/// - DTO-моделью, удобной для LLM и derived-логики;
/// - словарём `[PlaceholderKey: String]`, удобным для формы и registry.
///
/// Тип не хранит состояние и не принимает решений — он только гарантирует,
/// что переход между этими представлениями остаётся централизованным и симметричным.
enum CompanyDetailsAssembler {
    
    /// Извлекает начальные значения полей из `CompanyDetails` в placeholder-словарь.
    ///
    /// Используется, когда LLM уже вернул DTO, а форма должна получить стартовые значения
    /// для редактирования пользователем.
    nonisolated static func initialValues(from company: CompanyDetails) -> [PlaceholderKey: String] {
        var result: [PlaceholderKey: String] = [:]
        for key in CompanyDetails.CompanyDetailsKeys.allCases {
            if let value = company[key] {
                result[key.placeholderKey] = value
            }
        }
        return result
    }
    
    /// Собирает `CompanyDetails` из словаря placeholder-значений.
    ///
    /// Обратное преобразование нужно в тот момент, когда пользователь уже подправил форму,
    /// и приложению снова нужен структурированный DTO для derived-полей и export pipeline.
    nonisolated static func makeCompanyDetails(from values: [PlaceholderKey: String]) -> CompanyDetails {
        CompanyDetails(
            companyName: values[.companyName]?.trimmedNilIfEmpty,
            legalForm: values[.legalForm].flatMap { LegalForm.parse($0) },
            ceoFullName: values[.ceoFullName]?.trimmedNilIfEmpty,
            ceoFullGenitiveName: values[.ceoFullGenitiveName]?.trimmedNilIfEmpty,
            ceoShortenName: values[.ceoShortenName]?.trimmedNilIfEmpty,
            ogrn: values[.ogrn]?.trimmedNilIfEmpty,
            inn: values[.inn]?.trimmedNilIfEmpty,
            kpp: values[.kpp]?.trimmedNilIfEmpty,
            email: values[.email]?.trimmedNilIfEmpty,
            address: values[.address]?.trimmedNilIfEmpty,
            phone: values[.phone]?.trimmedNilIfEmpty
        )
    }
}
