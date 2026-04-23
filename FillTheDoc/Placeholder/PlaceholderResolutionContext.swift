import Foundation

/// Единый контекст для вычисления значений всех плейсхолдеров.
struct PlaceholderResolutionContext: Sendable {
    let editableValues: [PlaceholderKey: String]
    let customValues: [PlaceholderKey: String]
    let now: Date
    let calendar: Calendar
    let locale: Locale

    init(
        editableValues: [PlaceholderKey: String] = [:],
        customValues: [PlaceholderKey: String] = [:],
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = Locale(identifier: "ru_RU")
    ) {
        self.editableValues = editableValues
        self.customValues = customValues
        self.now = now
        self.calendar = calendar
        self.locale = locale
    }

    /// Собирает CompanyDetails из editable values.
    var companyDetails: CompanyDetails {
        CompanyDetailsAssembler.makeCompanyDetails(from: editableValues)
    }
}
