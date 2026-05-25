import Foundation

/// Нормализует пользовательский ввод перед хранением и валидацией.
typealias FieldNormalizer = @Sendable (String) -> String
/// Проверяет нормализованное строковое значение поля и возвращает проблему, если она есть.
typealias FieldValidator = @Sendable (String) -> FieldIssue?

/// Runtime-поведение конкретного плейсхолдера внутри registry.
///
/// Этот type связывает identity плейсхолдера с тремя policy-решениями:
/// - как нормализовать ввод;
/// - как валидировать editable значение;
/// - как вычислять derived/system значение при резолве шаблона.
nonisolated struct PlaceholderBehavior: Sendable {
    let normalizer: FieldNormalizer
    let validator: FieldValidator
    let resolver: (@Sendable (PlaceholderResolutionContext) -> String?)?
    
    nonisolated init(
        normalizer: @escaping FieldNormalizer = { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
        validator: @escaping FieldValidator = { _ in nil },
        resolver: (@Sendable (PlaceholderResolutionContext) -> String?)? = nil
    ) {
        self.normalizer = normalizer
        self.validator = validator
        self.resolver = resolver
    }
}
