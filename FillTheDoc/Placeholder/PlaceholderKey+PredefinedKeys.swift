//
//  PlaceholderKey+PredefinedKeys.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//

// MARK: Predefined placeholder keys
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
    nonisolated static let paymentMethod: Self = "payment_method"
    
    // MARK: Computed
    
    nonisolated static let dateLong: Self = "date_long"
    nonisolated static let dateShort: Self = "date_short"
    nonisolated static let ceoRole: Self = "ceo_role"
    nonisolated static let fullCompanyName: Self = "full_company_name"
    nonisolated static let fullCompanyNameExpanded: Self = "full_company_name_expanded"
    nonisolated static let rules: Self = "rules"
}

extension String {
    /// Лёгкий мост из raw string в доменный `PlaceholderKey`.
    ///
    /// Используется там, где приложение уже работает с текстовыми ключами
    /// (JSON keys, scanner output, пользовательский ввод), но хочет быстрее перейти
    /// к type-safe placeholder-domain.
    nonisolated var placeholderKey: PlaceholderKey {
        PlaceholderKey(rawValue: self)
    }
}

extension Dictionary where Key == PlaceholderKey, Value == String {
    /// Мостик из type-safe placeholder-domain в string-keyed формат,
    /// который ожидает нижележащий DOCX-template engine.
    var stringKeyed: [String: String] {
        self.reduce(into: [String: String]()) { result, entry in
            result[entry.key.rawValue] = entry.value
        }
    }
}
