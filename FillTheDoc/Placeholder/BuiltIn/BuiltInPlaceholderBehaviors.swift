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
    nonisolated static let builtInBehaviors: [PlaceholderKey: PlaceholderBehavior] = [
        .companyName: .init(
            normalizer: { $0.trimmed },
            validator: { Validators.nonEmpty($0) }
        ),
        .legalForm: .init(
            normalizer: { $0.trimmed.uppercased() },
            validator: { Validators.legalFormField($0) }
        ),
        .ceoFullName: .init(
            normalizer: { $0.trimmed },
            validator: { Validators.fullName($0) }
        ),
        .ceoFullGenitiveName: .init(
            normalizer: { $0.trimmed },
            validator: { Validators.fullName($0) }
        ),
        .ceoShortenName: .init(
            normalizer: { $0.trimmed },
            validator: { Validators.shortenName($0) }
        ),
        .ogrn: .init(
            normalizer: { Normalizers.trimmedDigitsOnly($0) },
            validator: { Validators.ogrn($0) }
        ),
        .inn: .init(
            normalizer: { Normalizers.trimmedDigitsOnly($0) },
            validator: { Validators.inn($0) }
        ),
        .kpp: .init(
            normalizer: { Normalizers.trimmedDigitsOnly($0) },
            validator: { Validators.kpp($0) }
        ),
        .email: .init(
            normalizer: { $0.trimmed.lowercased() },
            validator: { Validators.email($0) }
        ),
        .address: .init(
            normalizer: { $0.trimmed },
            validator: { Validators.address($0) }
        ),
        .phone: .init(
            normalizer: { Normalizers.phone($0) },
            validator: { Validators.phone($0) }
        ),
        .documentNumber: .init(
            normalizer: { $0.trimmed }
        ),
        .fee: .init(
            normalizer: { $0.trimmed },
            validator: { Validators.isInRange($0, 0...100) }
        ),
        .minFee: .init(
            normalizer: { $0.trimmed },
            validator: { Validators.isInRange($0, 10...1000) }
        ),
    ]
}
