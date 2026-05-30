//
//  PlaceholderFieldValue.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


// MARK: - PlaceholderFieldValue

/// Типизированное runtime-состояние поля формы.
///
/// После упрощения choice-модели и текст, и выбор хранят одинаковый replacement value.
nonisolated enum PlaceholderFieldValue: Hashable, Codable, Sendable {
    case value(String)
    case empty
    
    var stringValue: String? {
        guard case .value(let value) = self else { return nil }
        return value
    }
    
    var replacementString: String {
        switch self {
            case .value(let string):
                return string
            case .empty:
                return ""
        }
    }
}
