import Foundation

// MARK: - Protocol

protocol PlaceholderRegistryProtocol {
    var allPlaceholders: [PlaceholderDescriptor] { get }
    func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor?
    func contains(_ key: PlaceholderKey) -> Bool
    func placeholders(in section: PlaceholderSection) -> [PlaceholderDescriptor]
}

// MARK: - Default implementation

final class DefaultPlaceholderRegistry: PlaceholderRegistryProtocol {

    let allPlaceholders: [PlaceholderDescriptor]

    private let index: [PlaceholderKey: PlaceholderDescriptor]

    init(custom: [PlaceholderDescriptor] = []) {
        let builtIn = Self.builtIn
        let all = builtIn + custom
        self.allPlaceholders = all
        self.index = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })
    }

    func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor? {
        index[key]
    }

    func contains(_ key: PlaceholderKey) -> Bool {
        index[key] != nil
    }

    func placeholders(in section: PlaceholderSection) -> [PlaceholderDescriptor] {
        allPlaceholders.filter { $0.section == section }
    }

    // MARK: - Built-in descriptors

    private static let builtIn: [PlaceholderDescriptor] = [

        // MARK: Company — editable

        .init(
            key: "company_name",
            title: "Название компании",
            description: "Краткое наименование организации без указания правовой формы.",
            section: .company, kind: .editable,
            exampleValue: "Ромашка",
            isRequired: true
        ),
        .init(
            key: "legal_form",
            title: "Правовая форма",
            description: "Аббревиатура правовой формы: ООО, АО, ИП и т.д.",
            section: .company, kind: .editable,
            exampleValue: "ООО",
            isRequired: true
        ),
        .init(
            key: "ceo_full_name",
            title: "Руководитель (полное имя)",
            description: "Фамилия Имя Отчество руководителя в именительном падеже.",
            section: .company, kind: .editable,
            exampleValue: "Иванов Иван Иванович",
            isRequired: true
        ),
        .init(
            key: "ceo_full_genitive_name",
            title: "Руководитель (родительный падеж)",
            description: "Фамилия Имя Отчество руководителя в родительном падеже.",
            section: .company, kind: .editable,
            exampleValue: "Иванова Ивана Ивановича",
            isRequired: true
        ),
        .init(
            key: "ceo_shorten_name",
            title: "Руководитель (кратко)",
            description: "Фамилия с инициалами руководителя.",
            section: .company, kind: .editable,
            exampleValue: "Иванов И.И.",
            isRequired: true
        ),
        .init(
            key: "ogrn",
            title: "ОГРН / ОГРНИП",
            description: "Основной государственный регистрационный номер. 13 цифр для юрлиц, 15 для ИП.",
            section: .company, kind: .editable,
            exampleValue: "1187746707280",
            isRequired: true
        ),
        .init(
            key: "inn",
            title: "ИНН",
            description: "Идентификационный номер налогоплательщика. 10 цифр для юрлиц, 12 для ИП.",
            section: .company, kind: .editable,
            exampleValue: "9731007287",
            isRequired: true
        ),
        .init(
            key: "kpp",
            title: "КПП",
            description: "Код причины постановки на учёт. 9 цифр. Только для юрлиц.",
            section: .company, kind: .editable,
            exampleValue: "773101001",
            isRequired: false
        ),
        .init(
            key: "email",
            title: "Email",
            description: "Электронная почта организации.",
            section: .company, kind: .editable,
            exampleValue: "info@romashka.ru",
            isRequired: false
        ),
        .init(
            key: "address",
            title: "Адрес",
            description: "Юридический или фактический адрес.",
            section: .company, kind: .editable,
            exampleValue: "г. Москва, ул. Ленина, д. 1",
            isRequired: false
        ),
        .init(
            key: "phone",
            title: "Телефон",
            description: "Контактный телефон в международном формате.",
            section: .company, kind: .editable,
            exampleValue: "+79991234567",
            isRequired: false
        ),

        // MARK: Document — editable

        .init(
            key: "document_number",
            title: "Номер документа",
            description: "Номер договора или иного документа.",
            section: .document, kind: .editable,
            exampleValue: "2024-01-001",
            isRequired: false
        ),
        .init(
            key: "fee",
            title: "Комиссия, %",
            description: "Размер комиссионного вознаграждения в процентах.",
            section: .document, kind: .editable,
            exampleValue: "10",
            isRequired: true
        ),
        .init(
            key: "min_fee",
            title: "Мин. комиссия, руб",
            description: "Минимальный размер комиссионного вознаграждения в рублях.",
            section: .document, kind: .editable,
            exampleValue: "5000",
            isRequired: true
        ),

        // MARK: Computed — derived

        .init(
            key: "date_long",
            title: "Дата (полная)",
            description: "Текущая дата в формате «dd» MMMM yyyy г.",
            section: .computed, kind: .derived,
            exampleValue: "«22» апреля 2026 г.",
            isRequired: false
        ),
        .init(
            key: "date_short",
            title: "Дата (краткая)",
            description: "Текущая дата в формате dd.MM.yyyy.",
            section: .computed, kind: .derived,
            exampleValue: "22.04.2026",
            isRequired: false
        ),
        .init(
            key: "ceo_role",
            title: "Должность руководителя",
            description: "«Генеральный директор» для юрлиц или «Индивидуальный предприниматель» для ИП.",
            section: .computed, kind: .derived,
            exampleValue: "Генеральный директор",
            isRequired: false
        ),
        .init(
            key: "full_company_name",
            title: "Полное наименование компании",
            description: "Наименование компании с правовой формой в краткой форме, например ООО «Ромашка».",
            section: .computed, kind: .derived,
            exampleValue: "ООО «Ромашка»",
            isRequired: false
        ),
        .init(
            key: "full_company_name_expanded",
            title: "Полное наименование (развёрнуто)",
            description: "Наименование компании с расшифровкой правовой формы, например Общество с ограниченной ответственностью «Ромашка».",
            section: .computed, kind: .derived,
            exampleValue: "Общество с ограниченной ответственностью «Ромашка»",
            isRequired: false
        ),
        .init(
            key: "rules",
            title: "Основание деятельности",
            description: "Документ, на основании которого действует руководитель: Устав для юрлиц или выписка ЕГРИП для ИП.",
            section: .computed, kind: .derived,
            exampleValue: "Устава",
            isRequired: false
        ),
    ]
}
