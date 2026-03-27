//
//  FieldIssue.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 06.03.2026.
//

/// Результат валидации поля.
/// `nil` означает валидное поле (pass). Наличие — предупреждение или ошибка.
public struct FieldIssue: Equatable, Sendable {
    public let severity: Severity
    public let text: String
    
    public init(_ severity: Severity, _ text: String) {
        self.severity = severity
        self.text = text
    }
    
    public enum Severity: Int, Equatable, Sendable, Comparable {
        case warning = 0
        case error = 1
        
        public static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Convenience factories
    
    public static func error(_ text: String) -> FieldIssue {
        FieldIssue(.error, text)
    }
    
    public static func warning(_ text: String) -> FieldIssue {
        FieldIssue(.warning, text)
    }
}
