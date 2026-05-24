//
//  PlaceholderFieldValue.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


// MARK: - PlaceholderFieldValue

/// Типизированное runtime-состояние поля формы.
///
/// Для `choice` мы храним именно `optionID`, а не итоговую строку подстановки,
/// чтобы UI и persistence были устойчивы к изменению `title` и `replacementValue`.
nonisolated enum PlaceholderFieldValue: Hashable, Codable, Sendable {
    case text(String)
    case choice(optionID: String)
    case empty
    
    var textValue: String {
        guard case .text(let value) = self else { return "" }
        return value
    }
    
    var choiceOptionID: String? {
        guard case .choice(let optionID) = self else { return nil }
        return optionID
    }
}
