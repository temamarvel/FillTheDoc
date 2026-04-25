import Foundation

/// Канонический идентификатор плейсхолдера в приложении.
///
/// Важно, что `PlaceholderKey` описывает только identity (`company_name`, `date_short` и т.п.)
/// и не знает ничего про UI, валидацию или способ вычисления значения.
struct PlaceholderKey: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    let rawValue: String
    
    nonisolated init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    nonisolated init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
    
    /// Returns `true` for keys that are conditional-assembly control tokens
    /// (e.g. `switch_start:legal_form`, `case_end`, `default_start`),
    /// not regular replacement placeholders.
    nonisolated var isControlToken: Bool {
        // Control tokens either contain a colon (switch_start:key, case_start:value)
        // or match one of the fixed service keywords.
        if rawValue.contains(":") { return true }
        switch rawValue {
            case "switch_end", "case_end", "default_start", "default_end":
                return true
            default:
                return false
        }
    }
}

extension PlaceholderKey {
    // MARK: Company
    
    nonisolated static let companyName: Self = "company_name"
    nonisolated static let legalForm: Self = "legal_form"
    nonisolated static let ceoFullName: Self = "ceo_full_name"
    nonisolated static let ceoFullGenitiveName: Self = "ceo_full_genitive_name"
    nonisolated static let ceoShortenName: Self = "ceo_shorten_name"
    nonisolated static let ogrn: Self = "ogrn"
    nonisolated static let inn: Self = "inn"
    nonisolated static let kpp: Self = "kpp"
    nonisolated static let email: Self = "email"
    nonisolated static let address: Self = "address"
    nonisolated static let phone: Self = "phone"
    
    // MARK: Document
    
    nonisolated static let documentNumber: Self = "document_number"
    nonisolated static let fee: Self = "fee"
    nonisolated static let minFee: Self = "min_fee"
    
    // MARK: Computed
    
    nonisolated static let dateLong: Self = "date_long"
    nonisolated static let dateShort: Self = "date_short"
    nonisolated static let ceoRole: Self = "ceo_role"
    nonisolated static let fullCompanyName: Self = "full_company_name"
    nonisolated static let fullCompanyNameExpanded: Self = "full_company_name_expanded"
    nonisolated static let rules: Self = "rules"
}

extension Dictionary where Key == PlaceholderKey, Value == String {
    var stringKeyed: [String: String] {
        self.reduce(into: [String: String]()) { result, entry in
            result[entry.key.rawValue] = entry.value
        }
    }
}
