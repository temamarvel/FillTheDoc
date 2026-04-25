import Foundation

/// Двусторонний mapper между `CompanyDetails` и placeholder-словарями формы.
///
/// Этот тип полезен как boundary helper: он не хранит состояние,
/// а только инкапсулирует преобразования между DTO и placeholder-domain.
enum CompanyDetailsAssembler {
    
    /// Извлекает начальные значения полей из CompanyDetails DTO → [PlaceholderKey: String].
    nonisolated static func initialValues(from company: CompanyDetails) -> [PlaceholderKey: String] {
        var result: [PlaceholderKey: String] = [:]
        for key in CompanyDetails.CompanyDetailsKeys.allCases {
            if let value = company[key] {
                result[PlaceholderKey(rawValue: key.rawValue)] = value
            }
        }
        return result
    }
    
    /// Собирает CompanyDetails из словаря placeholder-значений.
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
