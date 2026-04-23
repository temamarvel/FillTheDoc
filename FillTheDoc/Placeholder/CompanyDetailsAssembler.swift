import Foundation

enum CompanyDetailsAssembler {
    
    /// Извлекает начальные значения полей из CompanyDetails DTO → [PlaceholderKey: String].
    static func initialValues(from company: CompanyDetails) -> [PlaceholderKey: String] {
        var result: [PlaceholderKey: String] = [:]
        for key in CompanyDetails.CompanyDetailsKeys.allCases {
            if let value = company[key] {
                result[PlaceholderKey(rawValue: key.rawValue)] = value
            }
        }
        return result
    }
    
    /// Собирает CompanyDetails из словаря placeholder-значений.
    static func makeCompanyDetails(from values: [PlaceholderKey: String]) -> CompanyDetails {
        CompanyDetails(
            companyName: values["company_name"]?.trimmedNilIfEmpty,
            legalForm: values["legal_form"].flatMap { LegalForm.parse($0) },
            ceoFullName: values["ceo_full_name"]?.trimmedNilIfEmpty,
            ceoFullGenitiveName: values["ceo_full_genitive_name"]?.trimmedNilIfEmpty,
            ceoShortenName: values["ceo_shorten_name"]?.trimmedNilIfEmpty,
            ogrn: values["ogrn"]?.trimmedNilIfEmpty,
            inn: values["inn"]?.trimmedNilIfEmpty,
            kpp: values["kpp"]?.trimmedNilIfEmpty,
            email: values["email"]?.trimmedNilIfEmpty,
            address: values["address"]?.trimmedNilIfEmpty,
            phone: values["phone"]?.trimmedNilIfEmpty
        )
    }
}
