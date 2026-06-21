//
//  FieldIssue.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 06.03.2026.
//

/// Результат валидации поля.
/// `nil` означает валидное поле (pass). Наличие — предупреждение или ошибка.
nonisolated struct FieldIssue: Hashable, Sendable {
    let severity: Severity
    let text: String
    
    init(_ severity: Severity, _ text: String) {
        self.severity = severity
        self.text = text
    }
    
    enum Severity: Int, Hashable, Sendable, Comparable {
        case info = 0
        case warning = 1
        case error = 2
        
        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Convenience factories
    
    static func error(_ text: String) -> FieldIssue {
        FieldIssue(.error, text)
    }
    
    static func warning(_ text: String) -> FieldIssue {
        FieldIssue(.warning, text)
    }
    
    static func info(_ text: String) -> FieldIssue {
        FieldIssue(.info, text)
    }
}
