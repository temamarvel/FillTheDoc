import Foundation

/// Единый контекст для вычисления значений всех плейсхолдеров.
///
/// Это boundary object между формой/DTO и слоем резолва. Он собирает в одном месте
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
    
    /// Ленивая проекция editable values обратно в `CompanyDetails`.
    ///
    /// Это удобно для derived placeholder'ов: им не нужно вручную разбирать словарь
    /// по ключам, они могут работать с привычной DTO-моделью.
    nonisolated var companyDetails: CompanyDetails {
        CompanyDetailsAssembler.makeCompanyDetails(from: editableValues)
    }
}
