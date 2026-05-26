import Foundation

/// Единый контекст для вычисления значений всех плейсхолдеров.
///
/// Это boundary object между формой и слоем резолва. Он собирает в одном месте
/// всё, что может понадобиться для вычисления placeholder'ов:
/// - ручной ввод из формы;
/// - custom values;
/// - системные параметры вроде даты, календаря и локали.
///
/// Идея в том, чтобы resolver'ы не тянули данные из UI напрямую и не знали,
/// кто именно их вызвал. Им нужен только стабильный контекст с уже подготовленными значениями.
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
    
    nonisolated func value(for key: PlaceholderKey) -> String {
        editableValues[key]?.trimmed ?? ""
    }
    
    nonisolated var legalForm: LegalForm? {
        editableValues[.legalForm].flatMap { LegalForm.parse($0) }
    }
    
    nonisolated var companyName: String {
        value(for: .companyName)
    }
    
    nonisolated var fullCompanyName: String {
        let name = companyName
        guard let legalForm else {
            return name
        }
        if legalForm == .ip {
            return [legalForm.shortName, name]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        guard !name.isEmpty else {
            return legalForm.shortName
        }
        return "\(legalForm.shortName) «\(name)»"
    }
    
    nonisolated var fullCompanyNameExpanded: String {
        let name = companyName
        guard let legalForm else {
            return name
        }
        if legalForm == .ip {
            return [legalForm.fullName, name]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        guard !name.isEmpty else {
            return legalForm.fullName
        }
        return "\(legalForm.fullName) «\(name)»"
    }
    
    nonisolated var isIndividualEntrepreneur: Bool {
        legalForm == .ip
    }
}
