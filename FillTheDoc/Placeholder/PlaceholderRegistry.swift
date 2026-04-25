import Foundation

// MARK: - Protocol

/// Единая точка доступа к placeholder-domain.
///
/// Реестр объединяет три типа знаний о плейсхолдере:
/// - метаданные (`PlaceholderDescriptor`),
/// - нормализацию и валидацию вводимых значений,
/// - резолв итогового значения для шаблона.
protocol PlaceholderRegistryProtocol: Sendable {
    var allDescriptors: [PlaceholderDescriptor] { get }
    func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor?
    func contains(_ key: PlaceholderKey) -> Bool
    func descriptors(in section: PlaceholderSection) -> [PlaceholderDescriptor]
    func normalizer(for key: PlaceholderKey) -> (@Sendable (String) -> String)
    func validator(for key: PlaceholderKey) -> (@Sendable (String) -> FieldIssue?)
    func resolve(_ key: PlaceholderKey, context: PlaceholderResolutionContext) -> String?
    func resolveAll(context: PlaceholderResolutionContext) -> [String: String]
}

// MARK: - Default implementation

/// Стандартная built-in реализация реестра плейсхолдеров.
///
/// Это основной «источник истины» для встроенных ключей приложения.
/// Именно здесь собраны:
/// - список известных плейсхолдеров,
/// - правила нормализации и валидации полей формы,
/// - вычисление derived/system значений.
///
/// За счёт этого UI, библиотека плейсхолдеров и DOCX-resolver
/// работают на одном и том же наборе определений.
final class DefaultPlaceholderRegistry: PlaceholderRegistryProtocol, @unchecked Sendable {
    
    let allDescriptors: [PlaceholderDescriptor]
    
    private let index: [PlaceholderKey: PlaceholderDescriptor]
    private let normalizers: [PlaceholderKey: @Sendable (String) -> String]
    private let validators: [PlaceholderKey: @Sendable (String) -> FieldIssue?]
    private let resolvers: [PlaceholderKey: @Sendable (PlaceholderResolutionContext) -> String?]
    
    private enum BuiltInKey {
        static let companyName: PlaceholderKey = "company_name"
        static let legalForm: PlaceholderKey = "legal_form"
        static let ceoFullName: PlaceholderKey = "ceo_full_name"
        static let ceoFullGenitiveName: PlaceholderKey = "ceo_full_genitive_name"
        static let ceoShortenName: PlaceholderKey = "ceo_shorten_name"
        static let ogrn: PlaceholderKey = "ogrn"
        static let inn: PlaceholderKey = "inn"
        static let kpp: PlaceholderKey = "kpp"
        static let email: PlaceholderKey = "email"
        static let address: PlaceholderKey = "address"
        static let phone: PlaceholderKey = "phone"
        static let documentNumber: PlaceholderKey = "document_number"
        static let fee: PlaceholderKey = "fee"
        static let minFee: PlaceholderKey = "min_fee"
        static let dateLong: PlaceholderKey = "date_long"
        static let dateShort: PlaceholderKey = "date_short"
        static let ceoRole: PlaceholderKey = "ceo_role"
        static let fullCompanyName: PlaceholderKey = "full_company_name"
        static let fullCompanyNameExpanded: PlaceholderKey = "full_company_name_expanded"
        static let rules: PlaceholderKey = "rules"
    }
    
    init(
        customDescriptors: [PlaceholderDescriptor] = [],
        customNormalizers: [PlaceholderKey: @Sendable (String) -> String] = [:],
        customValidators: [PlaceholderKey: @Sendable (String) -> FieldIssue?] = [:],
        customResolvers: [PlaceholderKey: @Sendable (PlaceholderResolutionContext) -> String?] = [:]
    ) {
        // Custom placeholders проектируются как расширение built-in каталога,
        // а не как отдельная параллельная система.
        let all = Self.builtInDescriptors + customDescriptors
        self.allDescriptors = all
        self.index = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })
        self.normalizers = Self.builtInNormalizers.merging(customNormalizers) { _, new in new }
        self.validators = Self.builtInValidators.merging(customValidators) { _, new in new }
        self.resolvers = Self.builtInResolvers.merging(customResolvers) { _, new in new }
    }
    
    func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor? {
        index[key]
    }
    
    func contains(_ key: PlaceholderKey) -> Bool {
        index[key] != nil
    }
    
    func descriptors(in section: PlaceholderSection) -> [PlaceholderDescriptor] {
        allDescriptors.filter { $0.section == section }
    }
    
    func normalizer(for key: PlaceholderKey) -> (@Sendable (String) -> String) {
        normalizers[key] ?? { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    func validator(for key: PlaceholderKey) -> (@Sendable (String) -> FieldIssue?) {
        validators[key] ?? { _ in nil }
    }
    
    func resolve(_ key: PlaceholderKey, context: PlaceholderResolutionContext) -> String? {
        // Derived placeholders use resolvers
        if let resolver = resolvers[key] {
            return resolver(context)
        }
        // Editable/custom placeholders use values from context
        return context.editableValues[key] ?? context.customValues[key]
    }
    
    // MARK: - Convenience: resolve all
    
    func resolveAll(context: PlaceholderResolutionContext) -> [String: String] {
        // Возвращаем словарь, непосредственно пригодный для шаблонизатора DOCX.
        var result: [String: String] = [:]
        for descriptor in allDescriptors {
            if let value = resolve(descriptor.key, context: context) {
                result[descriptor.key.rawValue] = value
            }
        }
        // Also include custom values not in registry
        for (key, value) in context.customValues where result[key.rawValue] == nil {
            result[key.rawValue] = value
        }
        return result
    }
    
    // MARK: - Built-in descriptors
    
    // Ниже встроенный каталог плейсхолдеров приложения.
    // Он определяет пользовательский контракт системы: какие ключи приложение знает,
    // как их показывает и какие из них требуют ручного ввода.
    private static let builtInDescriptors: [PlaceholderDescriptor] = [
        // MARK: Company — editable
        .init(
            key: BuiltInKey.companyName,
            title: "Название компании",
            description: "Краткое наименование организации без указания правовой формы.",
            placeholder: "ООО «Ромашка»",
            section: .company, kind: .editable,
            exampleValue: "Ромашка",
            isRequired: true
        ),
        .init(
            key: BuiltInKey.legalForm,
            title: "Правовая форма",
            description: "Аббревиатура правовой формы: ООО, АО, ИП и т.д.",
            placeholder: "ООО / АО / ИП",
            section: .company, kind: .editable,
            exampleValue: "ООО",
            isRequired: true
        ),
        .init(
            key: BuiltInKey.ceoFullName,
            title: "Руководитель (полное имя)",
            description: "Фамилия Имя Отчество руководителя в именительном падеже.",
            placeholder: "Иванов Иван Иванович",
            section: .company, kind: .editable,
            exampleValue: "Иванов Иван Иванович",
            isRequired: true
        ),
        .init(
            key: BuiltInKey.ceoFullGenitiveName,
            title: "Руководитель (родительный падеж)",
            description: "Фамилия Имя Отчество руководителя в родительном падеже.",
            placeholder: "Иванова Ивана Ивановича",
            section: .company, kind: .editable,
            exampleValue: "Иванова Ивана Ивановича",
            isRequired: true
        ),
        .init(
            key: BuiltInKey.ceoShortenName,
            title: "Руководитель (кратко)",
            description: "Фамилия с инициалами руководителя.",
            placeholder: "Иванов И.И.",
            section: .company, kind: .editable,
            exampleValue: "Иванов И.И.",
            isRequired: true
        ),
        .init(
            key: BuiltInKey.ogrn,
            title: "ОГРН / ОГРНИП",
            description: "Основной государственный регистрационный номер. 13 цифр для юрлиц, 15 для ИП.",
            placeholder: "13/15 цифр",
            section: .company, kind: .editable,
            exampleValue: "1187746707280",
            isRequired: true
        ),
        .init(
            key: BuiltInKey.inn,
            title: "ИНН",
            description: "Идентификационный номер налогоплательщика. 10 цифр для юрлиц, 12 для ИП.",
            placeholder: "10/12 цифр",
            section: .company, kind: .editable,
            exampleValue: "9731007287",
            isRequired: true
        ),
        .init(
            key: BuiltInKey.kpp,
            title: "КПП",
            description: "Код причины постановки на учёт. 9 цифр. Только для юрлиц.",
            placeholder: "9 цифр",
            section: .company, kind: .editable,
            exampleValue: "773101001",
            isRequired: false
        ),
        .init(
            key: BuiltInKey.email,
            title: "Email",
            description: "Электронная почта организации.",
            placeholder: "example@domain.com",
            section: .company, kind: .editable,
            exampleValue: "info@romashka.ru",
            isRequired: false
        ),
        .init(
            key: BuiltInKey.address,
            title: "Адрес",
            description: "Юридический или фактический адрес.",
            placeholder: "город, улица, дом",
            section: .company, kind: .editable,
            exampleValue: "г. Москва, ул. Ленина, д. 1",
            isRequired: false
        ),
        .init(
            key: BuiltInKey.phone,
            title: "Телефон",
            description: "Контактный телефон в международном формате.",
            placeholder: "+79991234567",
            section: .company, kind: .editable,
            exampleValue: "+79991234567",
            isRequired: false
        ),
        // MARK: Document — editable
        .init(
            key: BuiltInKey.documentNumber,
            title: "Номер документа",
            description: "Номер договора или иного документа.",
            placeholder: "yyyy-mm-#",
            section: .document, kind: .editable,
            exampleValue: "2024-01-001",
            isRequired: false
        ),
        .init(
            key: BuiltInKey.fee,
            title: "Комиссия, %",
            description: "Размер комиссионного вознаграждения в процентах.",
            placeholder: "10",
            section: .document, kind: .editable,
            exampleValue: "10",
            isRequired: true
        ),
        .init(
            key: BuiltInKey.minFee,
            title: "Мин. комиссия, руб",
            description: "Минимальный размер комиссионного вознаграждения в рублях.",
            placeholder: "5000",
            section: .document, kind: .editable,
            exampleValue: "5000",
            isRequired: true
        ),
        // MARK: Computed — derived
        .init(
            key: BuiltInKey.dateLong,
            title: "Дата (полная)",
            description: "Текущая дата в формате «dd» MMMM yyyy г.",
            section: .computed, kind: .derived,
            exampleValue: "«22» апреля 2026 г.",
            isRequired: false
        ),
        .init(
            key: BuiltInKey.dateShort,
            title: "Дата (краткая)",
            description: "Текущая дата в формате dd.MM.yyyy.",
            section: .computed, kind: .derived,
            exampleValue: "22.04.2026",
            isRequired: false
        ),
        .init(
            key: BuiltInKey.ceoRole,
            title: "Должность руководителя",
            description: "«Генеральный директор» для юрлиц или «Индивидуальный предприниматель» для ИП.",
            section: .computed, kind: .derived,
            exampleValue: "Генеральный директор",
            isRequired: false
        ),
        .init(
            key: BuiltInKey.fullCompanyName,
            title: "Полное наименование компании",
            description: "Наименование компании с правовой формой в краткой форме, например ООО «Ромашка».",
            section: .computed, kind: .derived,
            exampleValue: "ООО «Ромашка»",
            isRequired: false
        ),
        .init(
            key: BuiltInKey.fullCompanyNameExpanded,
            title: "Полное наименование (развёрнуто)",
            description: "Наименование компании с расшифровкой правовой формы, например Общество с ограниченной ответственностью «Ромашка».",
            section: .computed, kind: .derived,
            exampleValue: "Общество с ограниченной ответственностью «Ромашка»",
            isRequired: false
        ),
        .init(
            key: BuiltInKey.rules,
            title: "Основание деятельности",
            description: "Документ, на основании которого действует руководитель: Устав для юрлиц или выписка ЕГРИП для ИП.",
            section: .computed, kind: .derived,
            exampleValue: "Устава",
            isRequired: false
        ),
    ]
    
    // MARK: - Built-in normalizers
    
    // Эти правила применяются в форме до валидации и до построения итогового context.
    private static let builtInNormalizers: [PlaceholderKey: @Sendable (String) -> String] = [
        BuiltInKey.companyName: { $0.trimmed },
        BuiltInKey.legalForm: { $0.trimmed.uppercased() },
        BuiltInKey.ceoFullName: { $0.trimmed },
        BuiltInKey.ceoFullGenitiveName: { $0.trimmed },
        BuiltInKey.ceoShortenName: { $0.trimmed },
        BuiltInKey.ogrn: Normalizers.trimmedDigitsOnly,
        BuiltInKey.inn: Normalizers.trimmedDigitsOnly,
        BuiltInKey.kpp: Normalizers.trimmedDigitsOnly,
        BuiltInKey.email: { $0.trimmed },
        BuiltInKey.address: { $0.trimmed },
        BuiltInKey.phone: Normalizers.phone,
        BuiltInKey.documentNumber: { $0.trimmed },
        BuiltInKey.fee: { $0.trimmed },
        BuiltInKey.minFee: { $0.trimmed },
    ]
    
    // MARK: - Built-in validators
    
    // Валидаторы возвращают `FieldIssue`, чтобы UI мог показывать как ошибки,
    // так и мягкие предупреждения, не блокирующие весь сценарий.
    private static let builtInValidators: [PlaceholderKey: @Sendable (String) -> FieldIssue?] = [
        BuiltInKey.companyName: Validators.nonEmpty,
        BuiltInKey.legalForm: Validators.legalFormField,
        BuiltInKey.ceoFullName: Validators.fullName,
        BuiltInKey.ceoFullGenitiveName: Validators.fullName,
        BuiltInKey.ceoShortenName: Validators.shortenName,
        BuiltInKey.ogrn: Validators.ogrn,
        BuiltInKey.inn: Validators.inn,
        BuiltInKey.kpp: Validators.kpp,
        BuiltInKey.email: Validators.email,
        BuiltInKey.address: Validators.address,
        BuiltInKey.phone: Validators.phone,
        BuiltInKey.documentNumber: { _ in nil },
        BuiltInKey.fee: Validators.percentage,
        BuiltInKey.minFee: Validators.percentage,
    ]
    
    // MARK: - Built-in resolvers (for derived placeholders)
    
    // Derived placeholders рассчитываются из уже подтверждённых данных пользователя.
    // Благодаря этому docx fill, preview и отладка могут использовать один и тот же механизм.
    private static let dateFormatterLong: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = .current
        f.dateFormat = "«dd» MMMM yyyy 'г.'"
        return f
    }()
    
    private static let dateFormatterShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = .current
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()
    
    private static let builtInResolvers: [PlaceholderKey: @Sendable (PlaceholderResolutionContext) -> String?] = [
        BuiltInKey.dateLong: { ctx in
            dateFormatterLong.string(from: ctx.now)
        },
        BuiltInKey.dateShort: { ctx in
            dateFormatterShort.string(from: ctx.now)
        },
        BuiltInKey.ceoRole: { ctx in
            ctx.companyDetails.legalForm == .ip ? "Индивидуальный предприниматель" : "Генеральный директор"
        },
        BuiltInKey.fullCompanyName: { ctx in
            ctx.companyDetails.fullCompanyName
        },
        BuiltInKey.fullCompanyNameExpanded: { ctx in
            ctx.companyDetails.fullCompanyNameExpanded
        },
        BuiltInKey.rules: { ctx in
            ctx.companyDetails.legalForm == .ip
            ? "Листа  записи в Едином государственном реестре индивидуальных предпринимателей (ЕГРИП)"
            : "Устава"
        },
    ]
}

// MARK: - Backward compatibility

extension PlaceholderRegistryProtocol {
    /// Legacy accessor for views that used `allPlaceholders`
    var allPlaceholders: [PlaceholderDescriptor] { allDescriptors }
    
    /// Базовая реализация сборки полного словаря значений.
    ///
    /// Кастомные реестры могут переопределить её, если им нужен более
    /// эффективный способ или особая логика для неизвестных custom-ключей.
    func resolveAll(context: PlaceholderResolutionContext) -> [String: String] {
        var result: [String: String] = [:]
        
        for descriptor in allDescriptors {
            if let value = resolve(descriptor.key, context: context) {
                result[descriptor.key.rawValue] = value
            }
        }
        
        for (key, value) in context.customValues where result[key.rawValue] == nil {
            result[key.rawValue] = value
        }
        
        return result
    }
}
