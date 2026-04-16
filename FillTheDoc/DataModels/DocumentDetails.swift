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
    
    var fullCompanyName: String {
        companyDetails?.fullCompanyName ?? ""
    }
    
    var fullCompanyNameExpanded: String {
        companyDetails?.fullCompanyNameExpanded ?? ""
    }
    
    var rules: String {
        companyDetails?.legalForm == .ip ? "Листа  записи в Едином государственном реестре индивидуальных предпринимателей (ЕГРИП)" : "Устава"
    }
    
    init(documentNumber: String? = "", fee: String? = "", minFee: String? = "", companyDetails: CompanyDetails? = nil) {
        self.documentNumber = documentNumber
        self.fee = fee
        self.minFee = minFee
        self.companyDetails = companyDetails
    }
    
    enum DocumentDetailsKeys: String, CodingKey, CaseIterable {
        case documentNumber = "document_number"
        case fee = "fee"
        case minFee = "min_fee"
//        case dateShort = "date_short"
//        case dateLong = "date_long"
//        case ceoRole = "ceoRole"
//        case rules
//        case fullCompanyName = "full_company_name"
//        case fullCompanyNameExpanded = "full_company_name_expanded"
    }
    
    func asDictionary() -> [String: String] {
        var dict = companyDetails?.asDictionary() ?? [:]
        
        for key in DocumentDetailsKeys.allCases {
            dict[key.rawValue] = value(for: key) ?? ""
        }
        
        dict["date_short"] = dateShort
        dict["date_long"] = dateLong
        dict["ceo_role"] = ceoRole
        dict["rules"] = rules
        dict["full_company_name"] = fullCompanyName
        dict["full_company_name_expanded"] = fullCompanyNameExpanded
        
        return dict
    }
    
    subscript(key: DocumentDetailsKeys) -> String? {
        switch key {
            case .documentNumber:
                return documentNumber
//            case .ceoRole:
//                return ceoRole
//            case .dateLong:
//                return dateLong
//            case .dateShort:
//                return dateShort
            case .fee:
                return fee
            case .minFee:
                return minFee
//            case .fullCompanyName:
//                return fullCompanyName
//            case .fullCompanyNameExpanded:
//                return fullCompanyNameExpanded
//            case .rules:
//                return rules
        }
    }
    
    func value(for key: DocumentDetailsKeys) -> String? {
        switch key {
            case .documentNumber:
                documentNumber
            case .fee:
                fee
            case .minFee:
                minFee
//            case .dateShort:
//                dateShort
//            case .dateLong:
//                dateLong
//            case .ceoRole:
//                ceoRole
//            case .rules:
//                rules
//            case .fullCompanyName:
//                fullCompanyName
//            case .fullCompanyNameExpanded:
//                fullCompanyNameExpanded
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
