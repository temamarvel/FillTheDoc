import Foundation

/// Преобразует runtime-значение поля формы в строку, которая попадёт в итоговый DOCX.
///
/// Это важная boundary-роль в новой архитектуре:
/// - форма хранит типизированный `PlaceholderFieldValue`;
/// - registry хранит definition (`PlaceholderDescriptor`);
/// - шаблонизатор работает только со строками.
///
/// Благодаря этому `choice`-поля не размазывают special-case'ы по UI, export и scanner-слоям.
nonisolated struct PlaceholderValueResolver: Sendable {
    let normalizerProvider: @Sendable (PlaceholderKey) -> FieldNormalizer
    let validatorProvider: @Sendable (PlaceholderKey) -> FieldValidator
    
    nonisolated init(
        normalizerProvider: @escaping @Sendable (PlaceholderKey) -> FieldNormalizer,
        validatorProvider: @escaping @Sendable (PlaceholderKey) -> FieldValidator = { _ in { _ in nil } }
    ) {
        self.normalizerProvider = normalizerProvider
        self.validatorProvider = validatorProvider
    }
    
    func normalize(_ value: String, for key: PlaceholderKey) -> String {
        normalizerProvider(key)(value)
    }
    
    func validate(_ value: String, for key: PlaceholderKey) -> FieldIssue? {
        validatorProvider(key)(value)
    }
    
    func replacementValue(
        for value: PlaceholderFieldValue,
        definition: PlaceholderDescriptor
    ) -> String {
        switch (value, definition.kind) {
            case (.text(let text), .editable(_, .text)):
                return normalizerProvider(definition.key)(text)
            case (.choice(let optionID), .editable(_, .choice(let configuration))):
                return configuration.replacementValue(for: optionID)
            case (.empty, .editable(_, .choice(let configuration))):
                return configuration.replacementValue(for: nil)
            case (.empty, _):
                return ""
            default:
                return ""
        }
    }
}
