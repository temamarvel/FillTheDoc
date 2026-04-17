import Foundation

enum CompanyPlaceholderCatalog {
    static let editableDefinitions: [EditablePlaceholderDefinition] = [
        .init(
            key: "company_name",
            title: "Название", placeholder: "ООО «Ромашка»",
            section: .company, isRequired: true,
            normalizer: { $0.trimmed },
            validator: Validators.nonEmpty
        ),
        .init(
            key: "legal_form",
            title: "Правовая форма", placeholder: "ООО / АО / ИП",
            section: .company, isRequired: true,
            normalizer: { $0.trimmed.uppercased() },
            validator: Validators.legalFormField
        ),
        .init(
            key: "ceo_full_name",
            title: "Руководитель", placeholder: "Иванов Иван Иванович",
            section: .company, isRequired: true,
            normalizer: { $0.trimmed },
            validator: Validators.fullName
        ),
        .init(
            key: "ceo_full_genitive_name",
            title: "Руководитель (в родительном падеже)", placeholder: "Иванова Ивана Ивановича",
            section: .company, isRequired: true,
            normalizer: { $0.trimmed },
            validator: Validators.fullName
        ),
        .init(
            key: "ceo_shorten_name",
            title: "Руководитель (кратко)", placeholder: "Иванов И.И.",
            section: .company, isRequired: true,
            normalizer: { $0.trimmed },
            validator: Validators.shortenName
        ),
        .init(
            key: "ogrn",
            title: "ОГРН/ОГРНИП", placeholder: "13/15 цифр",
            section: .company, isRequired: true,
            normalizer: Normalizers.trimmedDigitsOnly,
            validator: Validators.ogrn
        ),
        .init(
            key: "inn",
            title: "ИНН", placeholder: "10/12 цифр",
            section: .company, isRequired: true,
            normalizer: Normalizers.trimmedDigitsOnly,
            validator: Validators.inn
        ),
        .init(
            key: "kpp",
            title: "КПП", placeholder: "9 цифр",
            section: .company, isRequired: false,
            normalizer: Normalizers.trimmedDigitsOnly,
            validator: Validators.kpp
        ),
        .init(
            key: "email",
            title: "Email", placeholder: "example@domain.com",
            section: .company, isRequired: false,
            normalizer: { $0.trimmed },
            validator: Validators.email
        ),
        .init(
            key: "address",
            title: "Адрес", placeholder: "город, улица, дом",
            section: .company, isRequired: false,
            normalizer: { $0.trimmed },
            validator: Validators.address
        ),
        .init(
            key: "phone",
            title: "Телефон", placeholder: "+79991234567",
            section: .company, isRequired: false,
            normalizer: Normalizers.phone,
            validator: Validators.phone
        ),
    ]
    
    /// Initial values from a CompanyDetails DTO
    static func initialValues(from company: CompanyDetails) -> [PlaceholderKey: String] {
        var result: [PlaceholderKey: String] = [:]
        for key in CompanyDetails.CompanyDetailsKeys.allCases {
            if let value = company[key] {
                result[PlaceholderKey(rawValue: key.rawValue)] = value
            }
        }
        return result
    }
}
