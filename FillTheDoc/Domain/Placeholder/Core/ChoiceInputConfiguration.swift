//
//  ChoiceInputConfiguration.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


import Foundation

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
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.allowsEmptyValue = allowsEmptyValue
        self.emptyTitle = emptyTitle
    }
    
    /// Нормализует внешнее строковое значение к допустимому runtime-состоянию поля.
    func normalizedFieldValue(for value: String?) -> PlaceholderFieldValue {
        guard !options.isEmpty else { return .empty }
        
        let normalizedValue = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        ?? ""
        
        guard !normalizedValue.isEmpty else {
            return allowsEmptyValue ? .empty : .value(options.first!)
        }
        
        guard options.contains(normalizedValue) else {
            return allowsEmptyValue ? .empty : .value(options.first!)
        }
        
        return .value(normalizedValue)
    }
}
