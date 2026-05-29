//
//  LegalForm.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.03.2026.
//


import Foundation

/// Нормализованный enum правовых форм, которые поддерживает приложение.
///
/// Здесь намеренно хранится не произвольная строка из документа, а ограниченный набор
/// значений, с которым дальше работают валидация, derived placeholders и шаблоны.
/// Если входное значение не удаётся надёжно свести к одному из поддерживаемых вариантов,
/// приложение предпочитает `nil`, а не неявное допущение.
enum LegalForm: String, CaseIterable, Sendable {
    case ooo
    case zao
    case ao
    case ip
    case pao
}

extension LegalForm {
    /// Краткая форма для шаблонов, UI и JSON-контракта с LLM.
    nonisolated var shortName: String {
        switch self {
            case .ooo: return "ООО"
            case .zao: return "ЗАО"
            case .ao: return "АО"
            case .ip: return "ИП"
            case .pao: return "ПАО"
        }
    }
    
    /// Полная юридическая форма, используемая в более официальных derived-полях.
    nonisolated var fullName: String {
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
    
    /// Приводит строку из LLM/пользовательского ввода/внешнего источника
    /// к одному из поддерживаемых canonical values.
    ///
    /// Метод intentionally tolerant к написанию и раскладке (`ООО`, `ooo`, полная форма),
    /// но intentionally strict к списку поддерживаемых форм.
    nonisolated static func parse(_ raw: String) -> LegalForm? {
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
    /// Алиасы нужны, чтобы отделить свободный внешний ввод от canonical enum values.
    /// Эта таблица — фактически словарь нормализации для legal-form domain.
    nonisolated static func aliases(for form: LegalForm) -> Set<String> {
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
    /// При декодировании принимаем строковое значение и нормализуем его через `parse`.
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
    
    /// При кодировании всегда отдаём короткую canonical форму,
    /// чтобы downstream-слои работали со стабильным представлением.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(shortName)
    }
}
