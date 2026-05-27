import Foundation

/// Нормализует пользовательский ввод перед хранением и валидацией.
typealias FieldNormalizer = @Sendable (String) -> String
/// Проверяет нормализованное строковое значение поля и возвращает проблему, если она есть.
typealias FieldValidator = @Sendable (String) -> FieldIssue?

/// Runtime-поведение конкретного плейсхолдера внутри registry.
///
/// После упрощения resolution registry отвечает только за policy input-полей:
/// - как нормализовать ввод;
/// - как валидировать editable значение.
///
/// Derived/system значения больше не вычисляются через замыкания в registry
/// и собираются централизованно в `TemplatePlaceholderResolver`.
nonisolated struct PlaceholderBehavior: Sendable {
    let normalizer: FieldNormalizer
    let validator: FieldValidator
    
    nonisolated init(
        normalizer: @escaping FieldNormalizer = { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
        validator: @escaping FieldValidator = { _ in nil }
    ) {
        self.normalizer = normalizer
        self.validator = validator
    }
}
