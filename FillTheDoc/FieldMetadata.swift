//
//  FieldMetadata.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 21.02.2026.
//


import Foundation

struct FieldMetadata {
    let title: String
    let placeholder: String
    let normalizer: (String) -> String
    let validator: (String) -> FieldValidationResult   // return error text or nil
}

enum FieldRules {
    
    // MARK: - Validators
    
    nonisolated static func optional(_ validate: @escaping (String) -> String?) -> (String) -> String? {
        { raw in
            let v = raw.trimmed
            guard !v.isEmpty else { return nil }
            return validate(v)
        }
    }
    
    static func lengthIn(_ allowed: Set<Int>, label: String) -> (String) -> String? {
        { value in
            guard allowed.contains(value.count) else {
                let list = allowed.sorted().map(String.init).joined(separator: " или ")
                return "\(label) должен содержать \(list) цифр"
            }
            return nil
        }
    }
    
    static func email() -> (String) -> String? {
        { value in
            // NSDataDetector на macOS работает нормально, быстрее и надёжнее большинства regex.
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = detector?.matches(in: value, options: [], range: range) ?? []
            
            let ok = matches.contains { m in
                guard m.resultType == .link, let url = m.url else { return false }
                return url.scheme == "mailto" && m.range.length == range.length
            }
            return ok ? nil : "Некорректный email"
        }
    }
    
    static func legalForm() -> (String) -> String? {
        { value in
            let allowed: Set<String> = ["ООО","ИП","АО","ПАО","НКО","ГУП","МУП"]
            return allowed.contains(value) ? nil : "Допустимые значения: \(allowed.sorted().joined(separator: ", "))"
        }
    }
}

extension CompanyDetails {
    static let fieldMetadata: [CodingKeys: FieldMetadata] = [
        .companyName: .init(
            title: "Название",
            placeholder: "ООО «Ромашка»",
            normalizer: { $0.trimmed },
            validator: { v in
                let t = v.trimmed
                return t.isEmpty ? FieldValidationResult(.error, "Поле не может быть пустым") : FieldValidationResult(.pass, "Название ок")
            }
        ),
        .inn: .init(
            title: "ИНН",
            placeholder: "10/12 цифр",
            normalizer: { $0.trimmed.digitsOnly },
            validator: { inn in FormatValidators.isValidINN(inn) }
        ),
        .kpp: .init(
            title: "КПП",
            placeholder: "9 цифр",
            normalizer: { $0.trimmed.digitsOnly },
            validator: { kpp in FormatValidators.isValidKPP(kpp) }
        ),
        .ogrn: .init(
            title: "ОГРН/ОГРНИП",
            placeholder: "13/15 цифр",
            normalizer: { $0.trimmed.digitsOnly },
            validator: { ogrn in FormatValidators.isValidOGRN(ogrn) }
        ),
        .ceoFullName: .init(
            title: "Руководитель",
            placeholder: "Иванов Иван Иванович",
            normalizer: { $0.trimmed },
            validator: { _ in FieldValidationResult(.pass, "ФИО ок") }
        ),
        .ceoShortenName: .init(
            title: "Руководитель (кратко)",
            placeholder: "Иванов И.И.",
            normalizer: { $0.trimmed },
            validator: { _ in FieldValidationResult(.pass, "Краткое ФИО ок") }
        ),
        .legalForm: .init(
            title: "Правовая форма",
            placeholder: "ООО / АО / ИП",
            normalizer: { $0.trimmed },
            validator: { _ in FieldValidationResult(.pass, "Правовая форма ок") }
        ),
        .email: .init(
            title: "Email",
            placeholder: "example@domain.com",
            normalizer: { $0.trimmed },
            validator: { _ in FieldValidationResult(.pass, "email ок") }
        ),
        .address: .init(
            title: "Адрес",
            placeholder: "город, улица, дом",
            normalizer: { $0.trimmed },
            validator: { _ in FieldValidationResult(.pass, "адрес ок") }
        ),
        .phone : .init(
            title: "Телефон",
            placeholder: "+79991234567",
            normalizer: { $0.trimmed },
            validator: { _ in FieldValidationResult(.pass, "Телефон ок") }
        )
    ]
}
