//
//  Requisites.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 20.02.2026.
//

//TODO: add address
public struct CompanyDetails: Decodable, LLMExtractable {
    let companyName: String?
    let legalForm: String?
    let ceoFullName: String?
    let ceoShortenName: String?
    let ogrn: String?
    let inn: String?
    let kpp: String?
    let email: String?
    let address: String?
    
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
    }
    
    subscript(key: CodingKeys) -> String? {
        switch key {
            case .companyName: return companyName
            case .legalForm: return legalForm
            case .ceoFullName: return ceoFullName
            case .ceoShortenName: return ceoShortenName
            case .ogrn: return ogrn
            case .inn: return inn
            case .kpp: return kpp
            case .email: return email
            case .address: return address
        }
    }
}
