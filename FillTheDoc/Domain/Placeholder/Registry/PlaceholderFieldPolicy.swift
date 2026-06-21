import Foundation

/// Policy обработки пользовательского значения конкретного поля внутри registry.
///
/// Единый источник правил нормализации и валидации для каждого placeholder-поля.
/// Form VM делегирует сюда, не дублируя логику.
///
/// Для text-полей достаточно `validate(String)`.
/// Для choice-полей валидация зависит от состояния `.empty` vs `.value`,
/// поэтому используется `validateFieldValue(PlaceholderFieldValue)`.
nonisolated struct PlaceholderFieldPolicy: Sendable {
    /// Максимальная длина значения для custom text-полей (мягкое ограничение, warning).
    static let maxCustomTextLength = 300
    
    let normalize: FieldNormalizer
    let validate: FieldValidator
    
    /// Опциональная валидация на уровне `PlaceholderFieldValue`.
    /// Если задана — вызывается вместо `validate` из form VM.
    /// Позволяет choice-policy различать `.empty` и `.value("")`.
    let validateFieldValue: (@Sendable (PlaceholderFieldValue) -> FieldIssue?)?
    
    init(
        normalize: @escaping FieldNormalizer = { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
        validate: @escaping FieldValidator = { _ in nil },
        validateFieldValue: (@Sendable (PlaceholderFieldValue) -> FieldIssue?)? = nil
    ) {
        self.normalize = normalize
        self.validate = validate
        self.validateFieldValue = validateFieldValue
    }
}
