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
    private enum CoreCompanyField: CaseIterable, Sendable {
        case companyName
        case legalForm
        case ceoFullName
        case ceoFullGenitiveName
        case ceoShortenName
        case ogrn
        case inn
        case kpp
        case email
        case address
        case phone
        
        nonisolated var placeholderKey: PlaceholderKey {
            switch self {
                case .companyName: return .companyName
                case .legalForm: return .legalForm
                case .ceoFullName: return .ceoFullName
                case .ceoFullGenitiveName: return .ceoFullGenitiveName
                case .ceoShortenName: return .ceoShortenName
                case .ogrn: return .ogrn
                case .inn: return .inn
                case .kpp: return .kpp
                case .email: return .email
                case .address: return .address
                case .phone: return .phone
            }
        }
        
        nonisolated func value(from company: CompanyDetails) -> String? {
            switch self {
                case .companyName: return company.companyName
                case .legalForm: return company.legalForm?.shortName
                case .ceoFullName: return company.ceoFullName
                case .ceoFullGenitiveName: return company.ceoFullGenitiveName
                case .ceoShortenName: return company.ceoShortenName
                case .ogrn: return company.ogrn
                case .inn: return company.inn
                case .kpp: return company.kpp
                case .email: return company.email
                case .address: return company.address
                case .phone: return company.phone
            }
        }
    }
    
    
    /// Извлекает начальные значения полей из `CompanyDetails` в placeholder-словарь.
    ///
    /// Используется, когда LLM уже вернул DTO, а форма должна получить стартовые значения
    /// для редактирования пользователем.
    nonisolated static func initialValues(from company: CompanyDetails) -> [PlaceholderKey: String] {
        var result: [PlaceholderKey: String] = [:]
        for field in CoreCompanyField.allCases {
            if let value = field.value(from: company) {
                result[field.placeholderKey] = value
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
