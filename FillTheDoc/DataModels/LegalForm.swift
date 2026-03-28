//
//  LegalForm.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.03.2026.
//


import Foundation
enum LegalForm: String, CaseIterable, Sendable {
    case ooo
    case zao
    case ao
    case ip
    case pao
}

extension LegalForm {
    var shortName: String {
        switch self {
            case .ooo: return "ООО"
            case .zao: return "ЗАО"
            case .ao: return "АО"
            case .ip: return "ИП"
            case .pao: return "ПАО"
        }
    }
    
    var fullName: String {
        switch self {
            case .ooo:
                return "Общество с ограниченной ответственностью"
            case .zao:
                return "Закрытое акционерное общество"
            case .ao:
                return "Акционерное общество"
            case .ip:
                return "Индивидуальный предприниматель"
            case .pao:
                return "Публичное акционерное общество"
        }
    }
    
    static func parse(_ raw: String) -> LegalForm? {
        let normalized = Normalizers.legalForm(raw)
        
        for form in Self.allCases {
            let aliases = aliases(for: form)
            if aliases.contains(normalized) {
                return form
            }
        }
        
        return nil
    }
}

private extension LegalForm {
    static func aliases(for form: LegalForm) -> Set<String> {
        switch form {
            case .ooo:
                return [
                    "ооо",
                    "ooo",
                    "общество с ограниченной ответственностью"
                ]
                
            case .zao:
                return [
                    "зао",
                    "zao",
                    "закрытое акционерное общество"
                ]
                
            case .ao:
                return [
                    "ао",
                    "ao",
                    "акционерное общество"
                ]
                
            case .ip:
                return [
                    "ип",
                    "ip",
                    "индивидуальный предприниматель"
                ]
                
            case .pao:
                return [
                    "пао",
                    "pao",
                    "публичное акционерное общество"
                ]
        }
    }
}

extension LegalForm: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        
        guard let value = Self.parse(raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported legal form: \(raw)"
            )
        }
        
        self = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(shortName)
    }
}
