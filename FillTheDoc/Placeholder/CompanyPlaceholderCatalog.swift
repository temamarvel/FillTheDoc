import Foundation

enum CompanyPlaceholderCatalog {
    static let editableDefinitions: [EditablePlaceholderDefinition] = [
        .init(
            id: "company_name", key: "company_name",
            title: "Название", placeholder: "ООО «Ромашка»",
            section: .company, isRequired: true,
            normalizer: { $0.trimmed },
            validator: Validators.nonEmpty
        ),
        .init(
            id: "legal_form", key: "legal_form",
            title: "Правовая форма", placeholder: "ООО / АО / ИП",
            section: .company, isRequired: true,
            normalizer: { $0.trimmed.uppercased() },
            validator: Validators.legalFormField
        ),
        .init(
            id: "ceo_full_name", key: "ceo_full_name",
            title: "Руководитель", placeholder: "Иванов Иван Иванович",
            section: .company, isRequired: true,
            normalizer: { $0.trimmed },
            validator: Validators.fullName
        ),
        .init(
            id: "ceo_full_genitive_name", key: "ceo_full_genitive_name",
            title: "Руководитель (в родительном падеже)", placeholder: "Иванова Ивана Ивановича",
            section: .company, isRequired: true,
            normalizer: { $0.trimmed },
            validator: Validators.fullName
        ),
        .init(
            id: "ceo_shorten_name", key: "ceo_shorten_name",
            title: "Руководитель (кратко)", placeholder: "Иванов И.И.",
            section: .company, isRequired: true,
            normalizer: { $0.trimmed },
            validator: Validators.shortenName
        ),
        .init(
            id: "ogrn", key: "ogrn",
            title: "ОГРН/ОГРНИП", placeholder: "13/15 цифр",
            section: .company, isRequired: true,
            normalizer: Normalizers.trimmedDigitsOnly,
            validator: Validators.ogrn
        ),
        .init(
            id: "inn", key: "inn",
            title: "ИНН", placeholder: "10/12 цифр",
            section: .company, isRequired: true,
            normalizer: Normalizers.trimmedDigitsOnly,
            validator: Validators.inn
        ),
        .init(
            id: "kpp", key: "kpp",
            title: "КПП", placeholder: "9 цифр",
            section: .company, isRequired: false,
            normalizer: Normalizers.trimmedDigitsOnly,
            validator: Validators.kpp
        ),
        .init(
            id: "email", key: "email",
            title: "Email", placeholder: "example@domain.com",
            section: .company, isRequired: false,
            normalizer: { $0.trimmed },
            validator: Validators.email
        ),
        .init(
            id: "address", key: "address",
            title: "Адрес", placeholder: "город, улица, дом",
            section: .company, isRequired: false,
            normalizer: { $0.trimmed },
            validator: Validators.address
        ),
        .init(
            id: "phone", key: "phone",
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
