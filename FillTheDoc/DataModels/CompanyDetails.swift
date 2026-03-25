import Foundation

public struct CompanyDetails: Decodable, LLMExtractable, Sendable {
    public let companyName: String?
    public let legalForm: LegalForm?
    public let ceoFullName: String?
    public let ceoShortenName: String?
    public let ogrn: String?
    public let inn: String?
    public let kpp: String?
    public let email: String?
    public let address: String?
    public let phone: String?
    
    public init(
        companyName: String?,
        legalForm: LegalForm?,
        ceoFullName: String?,
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
        self.ceoShortenName = ceoShortenName
        self.ogrn = ogrn
        self.inn = inn
        self.kpp = kpp
        self.email = email
        self.address = address
        self.phone = phone
    }
    
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case companyName = "company_name"
        case legalForm = "legal_form"
        case ceoFullName = "ceo_full_name"
        case ceoShortenName = "ceo_shorten_name"
        case ogrn
        case inn
        case kpp
        case email
        case address
        case phone
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.companyName = try container.decodeIfPresent(String.self, forKey: .companyName)?.trimmedNilIfEmpty
        self.ceoFullName = try container.decodeIfPresent(String.self, forKey: .ceoFullName)?.trimmedNilIfEmpty
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

public extension CompanyDetails {
    var fullCompanyName: String {
        [
            legalForm?.shortName,
            companyName?.trimmedNilIfEmpty
        ]
            .compactMap { $0 }
            .joined(separator: " ")
    }
    
    var fullCompanyNameExpanded: String {
        [
            legalForm?.fullName,
            companyName?.trimmedNilIfEmpty
        ]
            .compactMap { $0 }
            .joined(separator: " ")
    }
    
    subscript(key: CodingKeys) -> String? {
        switch key {
            case .companyName:
                return companyName
            case .legalForm:
                return legalForm?.shortName
            case .ceoFullName:
                return ceoFullName
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
    
    func value(for key: CodingKeys, expandedLegalForm: Bool) -> String? {
        switch key {
            case .companyName:
                return companyName
            case .legalForm:
                return expandedLegalForm ? legalForm?.fullName : legalForm?.shortName
            case .ceoFullName:
                return ceoFullName
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
    
    func asDictionary(expandedLegalForm: Bool = false) -> [String: String] {
        var result: [String: String] = [:]
        
        for key in CodingKeys.allCases {
            if let value = value(for: key, expandedLegalForm: expandedLegalForm)?
                .trimmedNilIfEmpty {
                result[key.rawValue] = value
            }
        }
        
        return result
    }
}


