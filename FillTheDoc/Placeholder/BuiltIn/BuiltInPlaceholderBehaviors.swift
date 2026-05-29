//  BuiltInPlaceholderBehaviours.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//

extension PlaceholderRegistry {
    /// Runtime-policy для встроенных input-плейсхолдеров: normalizer и validator по ключу.
    ///
    /// Derived/system значения больше не вычисляются здесь и собираются централизованно
    /// в `TemplatePlaceholderResolver` через `BuiltInPlaceholderValueFactory`.
    nonisolated static let builtInFieldPolicies: [PlaceholderKey: PlaceholderFieldPolicy] = [
        .companyName: .init(
            normalize: { $0.trimmed },
            validate: { Validators.nonEmpty($0) }
        ),
        .legalForm: .init(
            normalize: { $0.trimmed.uppercased() },
            validate: { Validators.legalFormField($0) }
        ),
        .ceoFullName: .init(
            normalize: { $0.trimmed },
            validate: { Validators.fullName($0) }
        ),
        .ceoFullGenitiveName: .init(
            normalize: { $0.trimmed },
            validate: { Validators.fullName($0) }
        ),
        .ceoShortenName: .init(
            normalize: { $0.trimmed },
            validate: { Validators.shortenName($0) }
        ),
        .ogrn: .init(
            normalize: { Normalizers.trimmedDigitsOnly($0) },
            validate: { Validators.ogrn($0) }
        ),
        .inn: .init(
            normalize: { Normalizers.trimmedDigitsOnly($0) },
            validate: { Validators.inn($0) }
        ),
        .kpp: .init(
            normalize: { Normalizers.trimmedDigitsOnly($0) },
            validate: { Validators.kpp($0) }
        ),
        .email: .init(
            normalize: { $0.trimmed.lowercased() },
            validate: { Validators.email($0) }
        ),
        .address: .init(
            normalize: { $0.trimmed },
            validate: { Validators.address($0) }
        ),
        .phone: .init(
            normalize: { Normalizers.phone($0) },
            validate: { Validators.phone($0) }
        ),
        .documentNumber: .init(
            normalize: { $0.trimmed }
        ),
        .fee: .init(
            normalize: { $0.trimmed },
            validate: { Validators.isInRange($0, 0...100) }
        ),
        .minFee: .init(
            normalize: { $0.trimmed },
            validate: { Validators.isInRange($0, 10...1000) }
        ),
    ]
}
