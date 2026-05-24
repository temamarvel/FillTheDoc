import Foundation

// MARK: - Protocol

/// Единая точка доступа к placeholder-domain.
///
/// Реестр хранит одновременно два вида знаний:
/// - каталог всех известных placeholder'ов для UI/scanner/documentation;
/// - правила получения итоговых строк для шаблона.
///
/// Важный архитектурный сдвиг этой версии: input-поля теперь описываются не как
/// «просто строка с placeholder'ом», а как полноценные runtime-definition'ы
/// с `valueSource` и `inputKind`. Это позволяет безопасно добавлять choice-поля,
/// не ломая ни LLM-схему, ни DOCX fill.
protocol PlaceholderRegistryProtocol: Sendable {
    nonisolated var allDescriptors: [PlaceholderDescriptor] { get }
    nonisolated var inputDescriptors: [PlaceholderDescriptor] { get }
    nonisolated var extractedDescriptors: [PlaceholderDescriptor] { get }
    nonisolated var manualDescriptors: [PlaceholderDescriptor] { get }
    nonisolated var customDescriptors: [PlaceholderDescriptor] { get }
    
    nonisolated func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor?
    nonisolated func contains(_ key: PlaceholderKey) -> Bool
    nonisolated func descriptors(in section: PlaceholderSection) -> [PlaceholderDescriptor]
    nonisolated func normalizer(for key: PlaceholderKey) -> FieldNormalizer
    nonisolated func validator(for key: PlaceholderKey) -> FieldValidator
    nonisolated func resolve(_ key: PlaceholderKey, context: PlaceholderResolutionContext) -> String?
    nonisolated func resolveAll(context: PlaceholderResolutionContext) -> [PlaceholderKey: String]
}

// MARK: - Default implementation

final class DefaultPlaceholderRegistry: PlaceholderRegistryProtocol, @unchecked Sendable {
    nonisolated let allDescriptors: [PlaceholderDescriptor]
    
    nonisolated private let index: [PlaceholderKey: PlaceholderDescriptor]
    nonisolated private let behaviors: [PlaceholderKey: PlaceholderBehavior]
    
    nonisolated var inputDescriptors: [PlaceholderDescriptor] {
        allDescriptors
            .filter(\.acceptsUserInput)
            .sorted(by: Self.sortDescriptors)
    }
    
    nonisolated var extractedDescriptors: [PlaceholderDescriptor] {
        inputDescriptors.filter { $0.valueSource == .extracted }
    }
    
    nonisolated var manualDescriptors: [PlaceholderDescriptor] {
        inputDescriptors.filter { $0.valueSource == .manual }
    }
    
    nonisolated var customDescriptors: [PlaceholderDescriptor] {
        inputDescriptors.filter(\.isUserDefined)
    }
    
    nonisolated init(customDefinitions: [CustomPlaceholderDefinition] = []) {
        let customDescriptors = customDefinitions
            .filter(\.isUserDefined)
            .filter { $0.section == .custom }
            .filter { !Self.builtInDescriptorIndex.keys.contains($0.key) }
        
        let all = (Self.builtInDescriptors + customDescriptors)
            .sorted(by: Self.sortDescriptors)
        
        self.allDescriptors = all
        self.index = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })
        var behaviors = Self.builtInBehaviors
        for descriptor in customDescriptors {
            behaviors[descriptor.key] = Self.defaultCustomBehavior(for: descriptor)
        }
        self.behaviors = behaviors
    }
    
    nonisolated func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor? {
        index[key]
    }
    
    nonisolated func contains(_ key: PlaceholderKey) -> Bool {
        index[key] != nil
    }
    
    nonisolated func descriptors(in section: PlaceholderSection) -> [PlaceholderDescriptor] {
        allDescriptors
            .filter { $0.section == section }
            .sorted(by: Self.sortDescriptors)
    }
    
    nonisolated func normalizer(for key: PlaceholderKey) -> FieldNormalizer {
        behaviors[key]?.normalizer ?? Self.defaultBehavior.normalizer
    }
    
    nonisolated func validator(for key: PlaceholderKey) -> FieldValidator {
        behaviors[key]?.validator ?? Self.defaultBehavior.validator
    }
    
    nonisolated func resolve(_ key: PlaceholderKey, context: PlaceholderResolutionContext) -> String? {
        if let resolver = behaviors[key]?.resolver {
            return resolver(context)
        }
        return context.editableValues[key] ?? context.customValues[key]
    }
    
    nonisolated func resolveAll(context: PlaceholderResolutionContext) -> [PlaceholderKey: String] {
        var result: [PlaceholderKey: String] = [:]
        
        for descriptor in allDescriptors {
            if let value = resolve(descriptor.key, context: context) {
                result[descriptor.key] = value
            }
        }
        
        for (key, value) in context.customValues where result[key] == nil {
            result[key] = value
        }
        
        return result
    }
}

// MARK: - Built-ins

private extension DefaultPlaceholderRegistry {
    nonisolated static let defaultBehavior = PlaceholderBehavior()
    
    nonisolated static func sortDescriptors(_ lhs: PlaceholderDescriptor, _ rhs: PlaceholderDescriptor) -> Bool {
        if lhs.section == rhs.section {
            if lhs.order == rhs.order {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.order < rhs.order
        }
        return lhs.section.rawValue < rhs.section.rawValue
    }
    
    nonisolated static func defaultCustomBehavior(
        for descriptor: PlaceholderDescriptor
    ) -> PlaceholderBehavior {
        let validator: FieldValidator
        
        switch descriptor.inputKind {
            case .some(.text(let configuration)):
                if configuration.isRequired {
                    validator = Validators.nonEmpty
                } else {
                    validator = { _ in nil }
                }
            case .some(.choice(let configuration)):
                validator = { value in
                    if configuration.allowsEmptySelection || !value.isEmpty {
                        return nil
                    }
                    return .error("Поле обязательно для выбора.")
                }
            case .none:
                validator = { _ in nil }
        }
        
        return PlaceholderBehavior(
            normalizer: { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            validator: validator
        )
    }
    
    nonisolated static let builtInDescriptors: [PlaceholderDescriptor] = [
        .init(
            key: .companyName,
            title: "Название компании",
            description: "Краткое наименование организации без указания правовой формы.",
            section: .company,
            order: 10,
            valueSource: .extracted,
            inputKind: .text(.init(placeholder: "ООО «Ромашка»", isRequired: true)),
            exampleValue: "Ромашка",
            isRequired: true
        ),
        .init(
            key: .legalForm,
            title: "Правовая форма",
            description: "Аббревиатура правовой формы: ООО, АО, ИП и т.д.",
            section: .company,
            order: 20,
            valueSource: .extracted,
            inputKind: .text(.init(placeholder: "ООО / АО / ИП", isRequired: true)),
            exampleValue: "ООО",
            isRequired: true
        ),
        .init(
            key: .ceoFullName,
            title: "Руководитель (полное имя)",
            description: "Фамилия Имя Отчество руководителя в именительном падеже.",
            section: .company,
            order: 30,
            valueSource: .extracted,
            inputKind: .text(.init(placeholder: "Иванов Иван Иванович", isRequired: true)),
            exampleValue: "Иванов Иван Иванович",
            isRequired: true
        ),
        .init(
            key: .ceoFullGenitiveName,
            title: "Руководитель (родительный падеж)",
            description: "Фамилия Имя Отчество руководителя в родительном падеже.",
            section: .company,
            order: 40,
            valueSource: .extracted,
            inputKind: .text(.init(placeholder: "Иванова Ивана Ивановича", isRequired: true)),
            exampleValue: "Иванова Ивана Ивановича",
            isRequired: true
        ),
        .init(
            key: .ceoShortenName,
            title: "Руководитель (кратко)",
            description: "Фамилия с инициалами руководителя.",
            section: .company,
            order: 50,
            valueSource: .extracted,
            inputKind: .text(.init(placeholder: "Иванов И.И.", isRequired: true)),
            exampleValue: "Иванов И.И.",
            isRequired: true
        ),
        .init(
            key: .ogrn,
            title: "ОГРН / ОГРНИП",
            description: "Основной государственный регистрационный номер. 13 цифр для юрлиц, 15 для ИП.",
            section: .company,
            order: 60,
            valueSource: .extracted,
            inputKind: .text(.init(placeholder: "13/15 цифр", isRequired: true)),
            exampleValue: "1187746707280",
            isRequired: true
        ),
        .init(
            key: .inn,
            title: "ИНН",
            description: "Идентификационный номер налогоплательщика. 10 цифр для юрлиц, 12 для ИП.",
            section: .company,
            order: 70,
            valueSource: .extracted,
            inputKind: .text(.init(placeholder: "10/12 цифр", isRequired: true)),
            exampleValue: "9731007287",
            isRequired: true
        ),
        .init(
            key: .kpp,
            title: "КПП",
            description: "Код причины постановки на учёт. 9 цифр. Только для юрлиц.",
            section: .company,
            order: 80,
            valueSource: .extracted,
            inputKind: .text(.init(placeholder: "9 цифр", isRequired: false)),
            exampleValue: "773101001",
            isRequired: false
        ),
        .init(
            key: .email,
            title: "Email",
            description: "Электронная почта организации.",
            section: .company,
            order: 90,
            valueSource: .extracted,
            inputKind: .text(.init(placeholder: "example@domain.com", isRequired: false)),
            exampleValue: "info@romashka.ru",
            isRequired: false
        ),
        .init(
            key: .address,
            title: "Адрес",
            description: "Юридический или фактический адрес.",
            section: .company,
            order: 100,
            valueSource: .extracted,
            inputKind: .text(
                .init(
                    placeholder: "город, улица, дом",
                    isRequired: false,
                    editorStyle: .multiline(minLines: 1, maxLines: 8)
                )
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
            valueSource: .extracted,
            inputKind: .text(.init(placeholder: "+79991234567", isRequired: false)),
            exampleValue: "+79991234567",
            isRequired: false
        ),
        .init(
            key: .documentNumber,
            title: "Номер документа",
            description: "Номер договора или иного документа.",
            section: .document,
            order: 120,
            valueSource: .manual,
            inputKind: .text(.init(placeholder: "yyyy-mm-#", isRequired: false)),
            exampleValue: "2024-01-001",
            isRequired: false
        ),
        .init(
            key: .fee,
            title: "Комиссия, %",
            description: "Размер комиссионного вознаграждения в процентах.",
            section: .document,
            order: 130,
            valueSource: .manual,
            inputKind: .text(.init(placeholder: "1", isRequired: true)),
            exampleValue: "1",
            isRequired: true
        ),
        .init(
            key: .minFee,
            title: "Мин. комиссия, руб",
            description: "Минимальный размер комиссионного вознаграждения в рублях.",
            section: .document,
            order: 140,
            valueSource: .manual,
            inputKind: .text(.init(placeholder: "10", isRequired: true)),
            exampleValue: "10",
            isRequired: true
        ),
        .init(
            key: .paymentMethod,
            title: "Способ оплаты",
            description: "Выбирается пользователем вручную и не участвует в LLM extraction.",
            section: .document,
            order: 150,
            valueSource: .manual,
            inputKind: .choice(
                .init(
                    options: [
                        .init(id: "invoice", title: "счет", replacementValue: "счет"),
                        .init(id: "sbp", title: "сбп", replacementValue: "сбп")
                    ],
                    defaultOptionID: nil,
                    allowsEmptySelection: false,
                    emptyTitle: "Не выбрано",
                    presentationStyle: .segmented
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
            exampleValue: "«22» апреля 2026 г.",
            isRequired: false
        ),
        .init(
            key: .dateShort,
            title: "Дата (краткая)",
            description: "Текущая дата в формате dd.MM.yyyy.",
            section: .computed,
            order: 220,
            exampleValue: "22.04.2026",
            isRequired: false
        ),
        .init(
            key: .ceoRole,
            title: "Должность руководителя",
            description: "«Генеральный директор» для юрлиц или «Индивидуальный предприниматель» для ИП.",
            section: .computed,
            order: 230,
            exampleValue: "Генеральный директор",
            isRequired: false
        ),
        .init(
            key: .fullCompanyName,
            title: "Полное наименование компании",
            description: "Наименование компании с правовой формой в краткой форме, например ООО «Ромашка».",
            section: .computed,
            order: 240,
            exampleValue: "ООО «Ромашка»",
            isRequired: false
        ),
        .init(
            key: .fullCompanyNameExpanded,
            title: "Полное наименование (развёрнуто)",
            description: "Наименование компании с расшифровкой правовой формы, например Общество с ограниченной ответственностью «Ромашка».",
            section: .computed,
            order: 250,
            exampleValue: "Общество с ограниченной ответственностью «Ромашка»",
            isRequired: false
        ),
        .init(
            key: .rules,
            title: "Основание деятельности",
            description: "Документ, на основании которого действует руководитель: Устав для юрлиц или выписка ЕГРИП для ИП.",
            section: .computed,
            order: 260,
            exampleValue: "Устава",
            isRequired: false
        ),
    ]
    
    nonisolated static let builtInDescriptorIndex: [PlaceholderKey: PlaceholderDescriptor] = Dictionary(
        uniqueKeysWithValues: builtInDescriptors.map { ($0.key, $0) }
    )
    
    nonisolated static func formatDateLong(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .current
        formatter.dateFormat = "«dd» MMMM yyyy 'г.'"
        return formatter.string(from: date)
    }
    
    nonisolated static func formatDateShort(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .current
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
    
    nonisolated static let builtInBehaviors: [PlaceholderKey: PlaceholderBehavior] = [
        .companyName: .init(
            normalizer: { $0.trimmed },
            validator: Validators.nonEmpty
        ),
        .legalForm: .init(
            normalizer: { $0.trimmed.uppercased() },
            validator: Validators.legalFormField
        ),
        .ceoFullName: .init(
            normalizer: { $0.trimmed },
            validator: Validators.fullName
        ),
        .ceoFullGenitiveName: .init(
            normalizer: { $0.trimmed },
            validator: Validators.fullName
        ),
        .ceoShortenName: .init(
            normalizer: { $0.trimmed },
            validator: Validators.shortenName
        ),
        .ogrn: .init(
            normalizer: Normalizers.trimmedDigitsOnly,
            validator: Validators.ogrn
        ),
        .inn: .init(
            normalizer: Normalizers.trimmedDigitsOnly,
            validator: Validators.inn
        ),
        .kpp: .init(
            normalizer: Normalizers.trimmedDigitsOnly,
            validator: Validators.kpp
        ),
        .email: .init(
            normalizer: { $0.trimmed.lowercased() },
            validator: Validators.email
        ),
        .address: .init(
            normalizer: { $0.trimmed },
            validator: Validators.address
        ),
        .phone: .init(
            normalizer: Normalizers.phone,
            validator: Validators.phone
        ),
        .documentNumber: .init(
            normalizer: { $0.trimmed }
        ),
        .fee: .init(
            normalizer: { $0.trimmed },
            validator: { Validators.isInRange($0, 0...100) }
        ),
        .minFee: .init(
            normalizer: { $0.trimmed },
            validator: { Validators.isInRange($0, 10...1000) }
        ),
        .dateLong: .init(
            resolver: { ctx in
                formatDateLong(ctx.now, locale: ctx.locale)
            }
        ),
        .dateShort: .init(
            resolver: { ctx in
                formatDateShort(ctx.now, locale: ctx.locale)
            }
        ),
        .ceoRole: .init(
            resolver: { ctx in
                ctx.companyDetails.legalForm == .ip ? "Индивидуальный предприниматель" : "Генеральный директор"
            }
        ),
        .fullCompanyName: .init(
            resolver: { ctx in
                ctx.companyDetails.fullCompanyName
            }
        ),
        .fullCompanyNameExpanded: .init(
            resolver: { ctx in
                ctx.companyDetails.fullCompanyNameExpanded
            }
        ),
        .rules: .init(
            resolver: { ctx in
                ctx.companyDetails.legalForm == .ip
                ? "Листа  записи в Едином государственном реестре индивидуальных предпринимателей (ЕГРИП)"
                : "Устава"
            }
        ),
    ]
}

// MARK: - Backward compatibility helpers

extension PlaceholderRegistryProtocol {
    nonisolated var allPlaceholders: [PlaceholderDescriptor] { allDescriptors }
}
