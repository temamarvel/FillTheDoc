import Foundation

/// Policy обработки пользовательского значения конкретного поля внутри registry.
///
/// После упрощения resolution registry отвечает только за policy input-полей:
/// - как нормализовать ввод;
/// - как валидировать editable значение.
///
/// Derived/system значения больше не вычисляются через замыкания в registry
/// и собираются централизованно в `PlaceholderValueAssembler`.
nonisolated struct PlaceholderFieldPolicy: Sendable {
    let normalize: FieldNormalizer
    let validate: FieldValidator
    
    nonisolated init(
        normalize: @escaping FieldNormalizer = { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
        validate: @escaping FieldValidator = { _ in nil }
    ) {
        self.normalize = normalize
        self.validate = validate
    }
}
