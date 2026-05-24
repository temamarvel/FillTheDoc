//
//  BuiltInPlaceholderBehaviours.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//

extension PlaceholderRegistry {
    nonisolated static let builtInBehaviors: [PlaceholderKey: PlaceholderBehavior] = [
        .companyName: .init(
            normalizer: { $0.trimmed },
            validator: Validators.nonEmpty
        ),
        .legalForm: .init(
            normalizer: { $0.trimmed.uppercased() },
            validator: Validators.legalFormField
        ),
        .ceoFullName: .init(
            normalizer: { $0.trimmed },
            validator: Validators.fullName
        ),
        .ceoFullGenitiveName: .init(
            normalizer: { $0.trimmed },
            validator: Validators.fullName
        ),
        .ceoShortenName: .init(
            normalizer: { $0.trimmed },
            validator: Validators.shortenName
        ),
        .ogrn: .init(
            normalizer: Normalizers.trimmedDigitsOnly,
            validator: Validators.ogrn
        ),
        .inn: .init(
            normalizer: Normalizers.trimmedDigitsOnly,
            validator: Validators.inn
        ),
        .kpp: .init(
            normalizer: Normalizers.trimmedDigitsOnly,
            validator: Validators.kpp
        ),
        .email: .init(
            normalizer: { $0.trimmed.lowercased() },
            validator: Validators.email
        ),
        .address: .init(
            normalizer: { $0.trimmed },
            validator: Validators.address
        ),
        .phone: .init(
            normalizer: Normalizers.phone,
            validator: Validators.phone
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
        .dateLong: .init(
            resolver: { ctx in
                formatDateLong(ctx.now, locale: ctx.locale)
            }
        ),
        .dateShort: .init(
            resolver: { ctx in
                formatDateShort(ctx.now, locale: ctx.locale)
            }
        ),
        .ceoRole: .init(
            resolver: { ctx in
                ctx.companyDetails.legalForm == .ip ? "Индивидуальный предприниматель" : "Генеральный директор"
            }
        ),
        .fullCompanyName: .init(
            resolver: { ctx in
                ctx.companyDetails.fullCompanyName
            }
        ),
        .fullCompanyNameExpanded: .init(
            resolver: { ctx in
                ctx.companyDetails.fullCompanyNameExpanded
            }
        ),
        .rules: .init(
            resolver: { ctx in
                ctx.companyDetails.legalForm == .ip
                ? "Листа  записи в Едином государственном реестре индивидуальных предпринимателей (ЕГРИП)"
                : "Устава"
            }
        ),
    ]
}
