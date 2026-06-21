//
//  PlaceholderKey+PredefinedKeys.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//

// MARK: Predefined placeholder keys
nonisolated extension PlaceholderKey {
    // MARK: Company
    
    static let companyName: Self = "company_name"
    static let legalForm: Self = "legal_form"
    static let ceoFullName: Self = "ceo_full_name"
    static let ceoFullGenitiveName: Self = "ceo_full_genitive_name"
    static let ceoShortenName: Self = "ceo_shorten_name"
    static let ogrn: Self = "ogrn"
    static let inn: Self = "inn"
    static let kpp: Self = "kpp"
    static let email: Self = "email"
    static let address: Self = "address"
    static let phone: Self = "phone"
    
    // MARK: Document
    
    static let documentNumber: Self = "document_number"
    static let fee: Self = "fee"
    static let minFee: Self = "min_fee"
    static let paymentMethod: Self = "payment_method"
    
    // MARK: Computed
    
    static let dateLong: Self = "date_long"
    static let dateShort: Self = "date_short"
    static let ceoRole: Self = "ceo_role"
    static let fullCompanyName: Self = "full_company_name"
    static let fullCompanyNameExpanded: Self = "full_company_name_expanded"
    static let rules: Self = "rules"
}

nonisolated extension String {
    /// Лёгкий мост из raw string в доменный `PlaceholderKey`.
    ///
    /// Используется там, где приложение уже работает с текстовыми ключами
    /// (JSON keys, scanner output, пользовательский ввод), но хочет быстрее перейти
    /// к type-safe placeholder-domain.
    var placeholderKey: PlaceholderKey {
        PlaceholderKey(rawValue: self)
    }
}

nonisolated extension Dictionary where Key == PlaceholderKey, Value == String {
    /// Мостик из type-safe placeholder-domain в string-keyed формат,
    /// который ожидает нижележащий DOCX-template engine.
    var stringKeyed: [String: String] {
        self.reduce(into: [String: String]()) { result, entry in
            result[entry.key.rawValue] = entry.value
        }
    }
}
