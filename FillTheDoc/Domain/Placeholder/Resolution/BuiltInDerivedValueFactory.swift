import Foundation

/// Централизованный factory встроенных derived placeholder-значений.
///
/// Он не собирает весь словарь значений, а только вычисляет derived placeholders
/// из уже подтверждённых source values.
nonisolated struct BuiltInDerivedValueFactory: Sendable {
    nonisolated func makeValues(
        sourceValues: [PlaceholderKey: String],
        date: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [PlaceholderKey: String] {
        [
            .dateShort: Self.currentDate(
                now: date,
                calendar: calendar,
                locale: locale
            ),
            .dateLong: Self.currentDateQuoted(
                now: date,
                calendar: calendar,
                locale: locale
            ),
            .ceoRole: Self.ceoRole(
                legalForm: sourceValues[.legalForm]
            ),
            .fullCompanyName: Self.companyNameWithLegalForm(
                companyName: sourceValues[.companyName],
                legalForm: sourceValues[.legalForm]
            ),
            .fullCompanyNameExpanded: Self.fullCompanyNameExpanded(
                companyName: sourceValues[.companyName],
                legalForm: sourceValues[.legalForm]
            ),
            .rules: Self.rules(
                legalForm: sourceValues[.legalForm]
            )
        ]
    }
    
    nonisolated static func companyNameWithLegalForm(
        companyName: String?,
        legalForm: String?
    ) -> String {
        let normalizedCompanyName = companyName?.trimmed ?? ""
        guard let legalForm = parseLegalForm(legalForm) else {
            return normalizedCompanyName
        }
        
        if legalForm == .ip {
            return [legalForm.shortName, normalizedCompanyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        
        guard !normalizedCompanyName.isEmpty else {
            return legalForm.shortName
        }
        return "\(legalForm.shortName) «\(normalizedCompanyName)»"
    }
    
    nonisolated static func fullCompanyNameExpanded(
        companyName: String?,
        legalForm: String?
    ) -> String {
        let normalizedCompanyName = companyName?.trimmed ?? ""
        guard let legalForm = parseLegalForm(legalForm) else {
            return normalizedCompanyName
        }
        
        if legalForm == .ip {
            return [legalForm.fullName, normalizedCompanyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        
        guard !normalizedCompanyName.isEmpty else {
            return legalForm.fullName
        }
        return "\(legalForm.fullName) «\(normalizedCompanyName)»"
    }
    
    nonisolated static func ceoRole(
        legalForm: String?
    ) -> String {
        parseLegalForm(legalForm) == .ip
        ? "Индивидуальный предприниматель"
        : "Генеральный директор"
    }
    
    nonisolated static func rules(
        legalForm: String?
    ) -> String {
        parseLegalForm(legalForm) == .ip
        ? "Листа записи в Едином государственном реестре индивидуальных предпринимателей (ЕГРИП)"
        : "Устава"
    }
    
    nonisolated static func currentDate(
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        makeFormatter(
            calendar: calendar,
            locale: locale,
            dateFormat: "dd.MM.yyyy"
        ).string(from: now)
    }
    
    nonisolated static func currentDateText(
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        makeFormatter(
            calendar: calendar,
            locale: locale,
            dateFormat: "d MMMM yyyy 'г.'"
        ).string(from: now)
    }
    
    nonisolated static func currentDateQuoted(
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        makeFormatter(
            calendar: calendar,
            locale: locale,
            dateFormat: "«dd» MMMM yyyy 'г.'"
        ).string(from: now)
    }
}

private extension BuiltInDerivedValueFactory {
    nonisolated static func parseLegalForm(_ legalForm: String?) -> LegalForm? {
        legalForm?
            .trimmedNilIfEmpty
            .flatMap { LegalForm.parse($0) }
    }
    
    nonisolated static func makeFormatter(
        calendar: Calendar,
        locale: Locale,
        dateFormat: String
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = .current
        formatter.dateFormat = dateFormat
        return formatter
    }
}
