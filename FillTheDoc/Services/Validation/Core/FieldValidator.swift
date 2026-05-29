import Foundation

/// Проверяет нормализованное строковое значение поля и возвращает проблему, если она есть.
typealias FieldValidator = @Sendable (String) -> FieldIssue?
