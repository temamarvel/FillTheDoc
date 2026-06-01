//
//  BuiltInPlaceholderDescriptors.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//

extension PlaceholderRegistry {
    /// Канонический каталог встроенных placeholder-definition'ов.
    /// Это единый источник описаний для формы, библиотеки плейсхолдеров и LLM-схемы extraction.
    nonisolated static let builtInDescriptors: [PlaceholderDescriptor] = [
        .init(
            key: .companyName,
            title: "Название компании",
            description: "Краткое наименование организации без указания правовой формы.",
            section: .company,
            order: 10,
            kind: .editable(
                source: .extracted,
                inputKind: .text
            ),
            exampleValue: "Ромашка",
            isRequired: true
        ),
        .init(
            key: .legalForm,
            title: "Правовая форма",
            description: "Аббревиатура правовой формы: ООО, АО, ИП и т.д.",
            section: .company,
            order: 20,
            kind: .editable(
                source: .extracted,
                inputKind: .text
            ),
            exampleValue: "ООО",
            isRequired: true
        ),
        .init(
            key: .ceoFullName,
            title: "Руководитель (полное имя)",
            description: "Фамилия Имя Отчество руководителя в именительном падеже.",
            section: .company,
            order: 30,
            kind: .editable(
                source: .extracted,
                inputKind: .text
            ),
            exampleValue: "Иванов Иван Иванович",
            isRequired: true
        ),
        .init(
            key: .ceoFullGenitiveName,
            title: "Руководитель (родительный падеж)",
            description: "Фамилия Имя Отчество руководителя в родительном падеже.",
            section: .company,
            order: 40,
            kind: .editable(
                source: .extracted,
                inputKind: .text
            ),
            exampleValue: "Иванова Ивана Ивановича",
            isRequired: true
        ),
        .init(
            key: .ceoShortenName,
            title: "Руководитель (кратко)",
            description: "Фамилия с инициалами руководителя.",
            section: .company,
            order: 50,
            kind: .editable(
                source: .extracted,
                inputKind: .text
            ),
            exampleValue: "Иванов И.И.",
            isRequired: true
        ),
        .init(
            key: .ogrn,
            title: "ОГРН / ОГРНИП",
            description: "Основной государственный регистрационный номер. 13 цифр для юрлиц, 15 для ИП.",
            section: .company,
            order: 60,
            kind: .editable(
                source: .extracted,
                inputKind: .text
            ),
            exampleValue: "1187746707280",
            isRequired: true
        ),
        .init(
            key: .inn,
            title: "ИНН",
            description: "Идентификационный номер налогоплательщика. 10 цифр для юрлиц, 12 для ИП.",
            section: .company,
            order: 70,
            kind: .editable(
                source: .extracted,
                inputKind: .text
            ),
            exampleValue: "9731007287",
            isRequired: true
        ),
        .init(
            key: .kpp,
            title: "КПП",
            description: "Код причины постановки на учёт. 9 цифр. Только для юрлиц.",
            section: .company,
            order: 80,
            kind: .editable(
                source: .extracted,
                inputKind: .text
            ),
            exampleValue: "773101001",
            isRequired: false
        ),
        .init(
            key: .email,
            title: "Email",
            description: "Электронная почта организации.",
            section: .company,
            order: 90,
            kind: .editable(
                source: .extracted,
                inputKind: .text
            ),
            exampleValue: "info@romashka.ru",
            isRequired: false
        ),
        .init(
            key: .address,
            title: "Адрес",
            description: "Юридический или фактический адрес.",
            section: .company,
            order: 100,
            kind: .editable(
                source: .extracted,
                inputKind: .text
            ),
            exampleValue: "г. Москва, ул. Ленина, д. 1",
            isRequired: false
        ),
        .init(
            key: .phone,
            title: "Телефон",
            description: "Контактный телефон в международном формате.",
            section: .company,
            order: 110,
            kind: .editable(
                source: .extracted,
                inputKind: .text
            ),
            exampleValue: "+79991234567",
            isRequired: false
        ),
        .init(
            key: .documentNumber,
            title: "Номер документа",
            description: "Номер договора или иного документа.",
            section: .document,
            order: 120,
            kind: .editable(
                source: .manual,
                inputKind: .text
            ),
            exampleValue: "2024-01-001",
            isRequired: false
        ),
        .init(
            key: .fee,
            title: "Комиссия, %",
            description: "Размер комиссионного вознаграждения в процентах.",
            section: .document,
            order: 130,
            kind: .editable(
                source: .manual,
                inputKind: .text
            ),
            exampleValue: "1",
            isRequired: true
        ),
        .init(
            key: .minFee,
            title: "Мин. комиссия, руб",
            description: "Минимальный размер комиссионного вознаграждения в рублях.",
            section: .document,
            order: 140,
            kind: .editable(
                source: .manual,
                inputKind: .text
            ),
            exampleValue: "10",
            isRequired: true
        ),
        .init(
            key: .paymentMethod,
            title: "Способ оплаты",
            description: "Выбирается пользователем вручную и не участвует в LLM extraction.",
            section: .document,
            order: 150,
            kind: .editable(
                source: .manual,
                inputKind: .choice(
                    .init(
                        options: [
                            "счет",
                            "сбп"
                        ],
                        allowsEmptyValue: false,
                        emptyTitle: "Не выбрано"
                    )
                )
            ),
            exampleValue: "счет",
            isRequired: true
        ),
        .init(
            key: .dateLong,
            title: "Дата (полная)",
            description: "Текущая дата в формате «dd» MMMM yyyy г.",
            section: .computed,
            order: 210,
            kind: .derived,
            exampleValue: "«22» апреля 2026 г.",
            isRequired: false
        ),
        .init(
            key: .dateShort,
            title: "Дата (краткая)",
            description: "Текущая дата в формате dd.MM.yyyy.",
            section: .computed,
            order: 220,
            kind: .derived,
            exampleValue: "22.04.2026",
            isRequired: false
        ),
        .init(
            key: .ceoRole,
            title: "Должность руководителя",
            description: "«Генеральный директор» для юрлиц или «Индивидуальный предприниматель» для ИП.",
            section: .computed,
            order: 230,
            kind: .derived,
            exampleValue: "Генеральный директор",
            isRequired: false
        ),
        .init(
            key: .fullCompanyName,
            title: "Полное наименование компании",
            description: "Наименование компании с правовой формой в краткой форме, например ООО «Ромашка».",
            section: .computed,
            order: 240,
            kind: .derived,
            exampleValue: "ООО «Ромашка»",
            isRequired: false
        ),
        .init(
            key: .fullCompanyNameExpanded,
            title: "Полное наименование (развёрнуто)",
            description: "Наименование компании с расшифровкой правовой формы, например Общество с ограниченной ответственностью «Ромашка».",
            section: .computed,
            order: 250,
            kind: .derived,
            exampleValue: "Общество с ограниченной ответственностью «Ромашка»",
            isRequired: false
        ),
        .init(
            key: .rules,
            title: "Основание деятельности",
            description: "Документ, на основании которого действует руководитель: Устав для юрлиц или выписка ЕГРИП для ИП.",
            section: .computed,
            order: 260,
            kind: .derived,
            exampleValue: "Устава",
            isRequired: false
        ),
    ]
    
    /// Индекс встроенных descriptor'ов по ключу для быстрых lookup-операций.
    nonisolated static let builtInDescriptorIndex: [PlaceholderKey: PlaceholderDescriptor] = Dictionary(
        uniqueKeysWithValues: builtInDescriptors.map { ($0.key, $0) }
    )
}
