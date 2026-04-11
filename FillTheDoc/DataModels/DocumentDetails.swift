//
//  DocumentData.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 18.03.2026.
//

import Foundation

struct DocumentDetails: Codable {
    let documentNumber: String?
    let fee: String?
    let minFee: String?
    let companyDetails: CompanyDetails?
    
    var dateLong: String {
        Self.dateFormatterLong.string(from: .now)
    }
    var dateShort: String {
        Self.dateFormatterShort.string(from: .now)
    }
    
    var ceoRole: String {
        companyDetails?.legalForm == .ip ? "Индивидуальный предприниматель" : "Генеральный директор"
    }
    
    enum DocumentDetailsKeys: String, CodingKey, CaseIterable {
        case documentNumber = "document_number"
        case fee = "fee"
        case minFee = "min_fee"
        case dateShort = "date_short"
        case dateLong = "date_long"
        case ceoRole = "ceoRole"
        case rules
        case fullCompanyName = "full_company_name"
        case fullCompanyNameExpanded = "full_company_name_expanded"
    }
    
    func asDictionary() -> [String: String] {
        var dict = companyDetails?.asDictionary() ?? [:]
        
        for key in DocumentDetailsKeys.allCases {
            dict[key.rawValue] = value(for: key) ?? ""
        }
        
        return dict
    }
    
    func value(for key: DocumentDetailsKeys) -> String? {
        switch key {
            case .documentNumber:
                documentNumber
            case .fee:
                fee
            case .minFee:
                minFee
            case .dateShort:
                dateShort
            case .dateLong:
                dateLong
            case .ceoRole:
                ceoRole
            case .rules:
                companyDetails?.legalForm == .ip ? "Листа  записи в Едином государственном реестре индивидуальных предпринимателей (ЕГРИП)" : "Устава"
            case .fullCompanyName:
                companyDetails?.fullCompanyName
            case .fullCompanyNameExpanded:
                companyDetails?.fullCompanyNameExpanded
        }
    }
}

private extension DocumentDetails {
    static let dateFormatterLong: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "«dd» MMMM yyyy 'г.'"
        return formatter
    }()
    
    static let dateFormatterShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}
