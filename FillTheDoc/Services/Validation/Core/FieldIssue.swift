//
//  FieldIssue.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 06.03.2026.
//

/// Результат валидации поля.
/// `nil` означает валидное поле (pass). Наличие — предупреждение или ошибка.
struct FieldIssue: Equatable, Sendable {
    let severity: Severity
    let text: String
    
    nonisolated init(_ severity: Severity, _ text: String) {
        self.severity = severity
        self.text = text
    }
    
    enum Severity: Int, Equatable, Sendable, Comparable {
        case warning = 0
        case error = 1
        
        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Convenience factories
    
    nonisolated static func error(_ text: String) -> FieldIssue {
        FieldIssue(.error, text)
    }
    
    nonisolated static func warning(_ text: String) -> FieldIssue {
        FieldIssue(.warning, text)
    }
}
