import Foundation

/// Структурированная модель реквизитов компании/ИП.
///
/// Это центральный DTO на границе между LLM-извлечением и подтверждением пользователем:
/// - LLM возвращает JSON именно в эту структуру,
/// - форма редактирует значения, совместимые с этой структурой,
/// - derived placeholders вычисляются уже из подтверждённого `CompanyDetails`.
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
        // между LLM JSON, формой и шаблоном.
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


