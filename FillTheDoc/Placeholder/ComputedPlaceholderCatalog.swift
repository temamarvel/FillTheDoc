import Foundation

enum ComputedPlaceholderCatalog {
    
    private static let dateFormatterLong: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = .current
        f.dateFormat = "«dd» MMMM yyyy 'г.'"
        return f
    }()
    
    private static let dateFormatterShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = .current
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()
    
    static let definitions: [ComputedPlaceholderDefinition] = [
        .init(key: "date_long") { ctx in
            dateFormatterLong.string(from: ctx.now)
        },
        .init(key: "date_short") { ctx in
            dateFormatterShort.string(from: ctx.now)
        },
        .init(key: "ceo_role") { ctx in
            ctx.company.legalForm == .ip ? "Индивидуальный предприниматель" : "Генеральный директор"
        },
        .init(key: "full_company_name") { ctx in
            ctx.company.fullCompanyName
        },
        .init(key: "full_company_name_expanded") { ctx in
            ctx.company.fullCompanyNameExpanded
        },
        .init(key: "rules") { ctx in
            ctx.company.legalForm == .ip
            ? "Листа  записи в Едином государственном реестре индивидуальных предпринимателей (ЕГРИП)"
            : "Устава"
        },
    ]
}
