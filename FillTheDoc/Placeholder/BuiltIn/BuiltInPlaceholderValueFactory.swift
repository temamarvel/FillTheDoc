import Foundation

/// Централизованный factory вычисляемых встроенных placeholder-значений.
///
/// В отличие от прошлой архитектуры с context-объектом, здесь каждый метод принимает
/// только явные аргументы. Это делает resolution прозрачным и позволяет читать flow линейно:
/// sourceValues → derived/system values → resolvedValues.
enum BuiltInPlaceholderValueFactory {
    static func companyNameWithLegalForm(
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
    
    static func fullCompanyNameExpanded(
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
    
    static func ceoRole(
        legalForm: String?
    ) -> String {
        parseLegalForm(legalForm) == .ip
        ? "Индивидуальный предприниматель"
        : "Генеральный директор"
    }
    
    static func rules(
        legalForm: String?
    ) -> String {
        parseLegalForm(legalForm) == .ip
        ? "Листа записи в Едином государственном реестре индивидуальных предпринимателей (ЕГРИП)"
        : "Устава"
    }
    
    static func currentDate(
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
    
    static func currentDateText(
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
    
    static func currentDateQuoted(
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

private extension BuiltInPlaceholderValueFactory {
    static func parseLegalForm(_ legalForm: String?) -> LegalForm? {
        legalForm?
            .trimmedNilIfEmpty
            .flatMap { LegalForm.parse($0) }
    }
    
    static func makeFormatter(
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
