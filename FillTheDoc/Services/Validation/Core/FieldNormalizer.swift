import Foundation

/// Нормализует пользовательский ввод перед хранением и валидацией.
typealias FieldNormalizer = @Sendable (String) -> String
