//
//  ChoiceInputConfiguration.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


/// Конфигурация editable-поля с ограниченным набором вариантов выбора.
///
/// Здесь зафиксированы options, default/fallback-правила и preferred presentation,
/// чтобы форма, persistence и export одинаково интерпретировали choice-значение.
nonisolated struct ChoiceInputConfiguration: Hashable, Codable, Sendable {
    var options: [PlaceholderOption]
    var defaultOptionID: String?
    var allowsEmptySelection: Bool
    var emptyTitle: String
    var presentationStyle: ChoicePresentationStyle
    
    init(
        options: [PlaceholderOption],
        defaultOptionID: String? = nil,
        allowsEmptySelection: Bool = true,
        emptyTitle: String = "Не выбрано",
        presentationStyle: ChoicePresentationStyle = .menu
    ) {
        self.options = options
        self.defaultOptionID = defaultOptionID
        self.allowsEmptySelection = allowsEmptySelection
        self.emptyTitle = emptyTitle
        self.presentationStyle = presentationStyle
    }
    
    /// Возвращает вариант по его стабильному идентификатору.
    func option(withID id: String) -> PlaceholderOption? {
        options.first { $0.id == id }
    }
    
    /// Fallback-вариант, который используется когда выбор обязателен,
    /// а текущее значение отсутствует или больше невалидно.
    var fallbackOption: PlaceholderOption? {
        if let defaultOptionID,
           let option = option(withID: defaultOptionID) {
            return option
        }
        if !allowsEmptySelection {
            return options.first
        }
        return nil
    }
    
    /// Нормализует внешний `optionID` к фактически допустимому выбору для текущей конфигурации.
    func effectiveOptionID(for optionID: String?) -> String? {
        if let optionID,
           let option = option(withID: optionID) {
            return option.id
        }
        return fallbackOption?.id
    }
    
    /// Переводит optional `optionID` в типизированное состояние поля формы.
    func normalizedFieldValue(for optionID: String?) -> PlaceholderFieldValue {
        if let optionID = effectiveOptionID(for: optionID) {
            return .choice(optionID: optionID)
        }
        return .empty
    }
    
    /// Возвращает строку, которая попадёт в итоговый документ для выбранной опции.
    func replacementValue(for optionID: String?) -> String {
        if let optionID,
           let option = option(withID: optionID) {
            return option.replacementValue
        }
        if optionID == nil {
            return fallbackOption?.replacementValue ?? ""
        }
        return ""
    }
}
