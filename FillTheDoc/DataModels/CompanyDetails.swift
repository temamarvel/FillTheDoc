import Foundation

/// Структурированная модель реквизитов компании/ИП.
///
/// Это центральный DTO проекта на границе между несколькими слоями сразу:
/// - LLM возвращает JSON именно в эту структуру;
/// - форма подтверждения редактирует значения, совместимые с этой структурой;
/// - placeholder-domain вычисляет derived-поля уже из подтверждённого `CompanyDetails`.
///
/// Важно понимать жизненный цикл этой модели:
/// 1. сначала она появляется как черновик после ответа модели;
/// 2. затем пользователь может исправить поля через форму;
/// 3. после подтверждения обновлённый `CompanyDetails` используется как источник истины
///    для вычисляемых плейсхолдеров и финального export.
///
/// Поэтому тип должен быть одновременно:
/// - удобным для JSON-декодирования;
/// - понятным для формы;
/// - достаточно стабильным как публичный внутренний контракт проекта.
struct CompanyDetails: Decodable, LLMExtractable, Sendable {
    typealias SchemaKeys = CompanyDetailsKeys
    
    let companyName: String?
    let legalForm: LegalForm?
    let ceoFullName: String?
    let ceoShortenName: String?
    let ceoFullGenitiveName: String?
    let ogrn: String?
    let inn: String?
    let kpp: String?
    let email: String?
    let address: String?
    let phone: String?
    
    nonisolated init(
        companyName: String?,
        legalForm: LegalForm?,
        ceoFullName: String?,
        ceoFullGenitiveName: String?,
        ceoShortenName: String?,
        ogrn: String?,
        inn: String?,
        kpp: String?,
        email: String?,
        address: String?,
        phone: String?
    ) {
        self.companyName = companyName
        self.legalForm = legalForm
        self.ceoFullName = ceoFullName
        self.ceoFullGenitiveName = ceoFullGenitiveName
        self.ceoShortenName = ceoShortenName
        self.ogrn = ogrn
        self.inn = inn
        self.kpp = kpp
        self.email = email
        self.address = address
        self.phone = phone
    }
    
    enum CompanyDetailsKeys: String, CodingKey, CaseIterable {
        // Ключи совпадают с placeholder-key naming, чтобы снижать количество маппингов
        // между LLM JSON, формой, placeholder-domain и шаблоном.
        // Это осознанный компромисс: naming становится более важной частью архитектуры,
        // зато проект избегает нескольких хрупких слоёв преобразования одних и тех же полей.
        case companyName = "company_name"
        case legalForm = "legal_form"
        case ceoFullName = "ceo_full_name"
        case ceoFullGenitiveName = "ceo_full_genitive_name"
        case ceoShortenName = "ceo_shorten_name"
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
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CompanyDetailsKeys.self)
        
        self.companyName = try container.decodeIfPresent(String.self, forKey: .companyName)?.trimmedNilIfEmpty
        self.ceoFullName = try container.decodeIfPresent(String.self, forKey: .ceoFullName)?.trimmedNilIfEmpty
        self.ceoFullGenitiveName = try container.decodeIfPresent(String.self, forKey: .ceoFullGenitiveName)?.trimmedNilIfEmpty
        self.ceoShortenName = try container.decodeIfPresent(String.self, forKey: .ceoShortenName)?.trimmedNilIfEmpty
        self.ogrn = try container.decodeIfPresent(String.self, forKey: .ogrn)?.trimmedNilIfEmpty
        self.inn = try container.decodeIfPresent(String.self, forKey: .inn)?.trimmedNilIfEmpty
        self.kpp = try container.decodeIfPresent(String.self, forKey: .kpp)?.trimmedNilIfEmpty
        self.email = try container.decodeIfPresent(String.self, forKey: .email)?.trimmedNilIfEmpty
        self.address = try container.decodeIfPresent(String.self, forKey: .address)?.trimmedNilIfEmpty
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone)?.trimmedNilIfEmpty
        
        if let rawLegalForm = try container.decodeIfPresent(String.self, forKey: .legalForm) {
            self.legalForm = LegalForm.parse(rawLegalForm)
        } else {
            self.legalForm = nil
        }
    }
}

extension CompanyDetails {
    /// Краткое полное имя, пригодное для договоров: например `ООО «Ромашка»`.
    ///
    /// Это derived presentation-value: он не хранится в исходном DTO как отдельное поле,
    /// а строится детерминированно из `legalForm` + `companyName`.
    nonisolated var fullCompanyName: String {
        let name = companyName?.trimmed ?? ""
        guard let legalForm else { return name }
        
        if legalForm == .ip {
            return [legalForm.shortName, name]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        
        guard !name.isEmpty else { return legalForm.shortName }
        return "\(legalForm.shortName) «\(name)»"
    }
    
    /// Расширенное полное имя: например `Общество с ограниченной ответственностью «Ромашка»`.
    ///
    /// Используется там, где шаблон требует юридически более развёрнутую форму наименования.
    nonisolated var fullCompanyNameExpanded: String {
        let name = companyName?.trimmed ?? ""
        guard let legalForm else { return name }
        
        if legalForm == .ip {
            return [legalForm.fullName, name]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        
        guard !name.isEmpty else { return legalForm.fullName }
        return "\(legalForm.fullName) «\(name)»"
    }
    
    /// Удобный доступ по schema-key для мостика между DTO и placeholder-domain.
    ///
    /// Этот subscript нужен в основном `CompanyDetailsAssembler`, чтобы не размазывать
    /// логику маппинга по коду и не дублировать список полей вручную в нескольких местах.
    nonisolated subscript(key: CompanyDetailsKeys) -> String? {
        switch key {
            case .companyName:
                return companyName
            case .legalForm:
                return legalForm?.shortName
            case .ceoFullName:
                return ceoFullName
            case .ceoFullGenitiveName:
                return ceoFullGenitiveName
            case .ceoShortenName:
                return ceoShortenName
            case .ogrn:
                return ogrn
            case .inn:
                return inn
            case .kpp:
                return kpp
            case .email:
                return email
            case .address:
                return address
            case .phone:
                return phone
        }
    }
}


