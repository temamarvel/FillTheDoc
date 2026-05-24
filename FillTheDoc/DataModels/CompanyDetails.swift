import Foundation

/// Структурированная модель реквизитов компании/ИП.
///
/// Это центральный core-DTO проекта на границе между несколькими слоями:
/// - extracted placeholder values собираются в эту структуру только для системных полей компании;
/// - форма подтверждения использует её как typed-представление core-реквизитов;
/// - placeholder-domain вычисляет derived-поля уже из подтверждённого `CompanyDetails`.
///
/// Важно понимать жизненный цикл этой модели:
/// 1. сначала LLM возвращает динамический словарь extracted placeholder values;
/// 2. затем core-часть этого словаря собирается в `CompanyDetails`;
/// 3. затем пользователь может исправить поля через форму;
/// 4. после подтверждения обновлённый `CompanyDetails` используется как источник истины
///    для вычисляемых плейсхолдеров и финального export.
///
/// Поэтому тип должен быть одновременно:
/// - удобным для JSON-декодирования;
/// - понятным для формы;
/// - достаточно стабильным как публичный внутренний контракт проекта.
struct CompanyDetails: Decodable, Sendable {
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
    
    enum CodingKeys: String, CodingKey {
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
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
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
    
    /// Читабельное debug-представление core DTO.
    nonisolated func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        dict["company_name"] = companyName
        dict["legal_form"] = legalForm?.shortName
        dict["ceo_full_name"] = ceoFullName
        dict["ceo_full_genitive_name"] = ceoFullGenitiveName
        dict["ceo_shorten_name"] = ceoShortenName
        dict["ogrn"] = ogrn
        dict["inn"] = inn
        dict["kpp"] = kpp
        dict["email"] = email
        dict["address"] = address
        dict["phone"] = phone
        
        return dict
    }
    
    nonisolated func toMultilineString() -> String {
        let dict = asDictionary()
        
        return dict
            .compactMap { key, value in
                guard !(value is NSNull) else { return nil }
                return "\(key): \(value)"
            }
            .sorted()
            .joined(separator: "\n")
    }
}


