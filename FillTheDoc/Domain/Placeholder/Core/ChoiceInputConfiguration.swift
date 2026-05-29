//
//  ChoiceInputConfiguration.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


/// Конфигурация editable-поля с ограниченным набором вариантов выбора.
///
/// Для choice-плейсхолдера выбранная строка и есть итоговое replacement value,
/// поэтому здесь хранятся только допустимые строковые варианты и правила пустого значения.
nonisolated struct ChoiceInputConfiguration: Hashable, Codable, Sendable {
    var options: [String]
    var allowsEmptyValue: Bool
    var emptyTitle: String
    
    init(
        options: [String],
        allowsEmptyValue: Bool = false,
        emptyTitle: String = "Не выбрано"
    ) {
        self.options = options
        self.allowsEmptyValue = allowsEmptyValue
        self.emptyTitle = emptyTitle
    }
    
    /// Нормализует внешнее строковое значение к допустимому runtime-состоянию поля.
    func normalizedFieldValue(for value: String?) -> PlaceholderFieldValue {
        if let value,
           options.contains(value) {
            return .value(value)
        }
        
        if allowsEmptyValue {
            return .empty
        }
        
        return .value(options.first ?? "")
    }
}
