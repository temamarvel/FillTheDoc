//
//  DocumentData.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 18.03.2026.
//

import Foundation

struct DocumentData: Codable {
    let docNumber: String?
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
    
    func asDictionary() -> [String: String] {
        var dict = companyDetails?.asDictionary() ?? [:]
        
        if let docNumber = docNumber?.trimmedNilIfEmpty {
            dict["doc_number"] = docNumber
        }
        
        if let fee = fee?.trimmedNilIfEmpty {
            dict["fee"] = fee
        }
        
        if let minFee = minFee?.trimmedNilIfEmpty {
            dict["min_fee"] = minFee
        }
        
        dict["full_company_name"] = companyDetails?.fullCompanyName
        dict["full_company_name_expanded"] = companyDetails?.fullCompanyNameExpanded
        dict["date_long"] = dateLong
        dict["ceo_role"] = ceoRole
        dict["rules"] = companyDetails?.legalForm == .ip ? "Листа  записи в Едином государственном реестре индивидуальных предпринимателей (ЕГРИП)" : "Устава"
        
        return dict
    }
}

private extension DocumentData {
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
