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
    
    nonisolated init(
        normalizerProvider: @escaping @Sendable (PlaceholderKey) -> FieldNormalizer
    ) {
        self.normalizerProvider = normalizerProvider
    }
    
    func replacementValue(
        for value: PlaceholderFieldValue,
        definition: PlaceholderDescriptor
    ) -> String {
        switch (value, definition.kind) {
            case (.text(let text), .editable(_, .text)):
                return normalizerProvider(definition.key)(text)
            case (.choice(let optionID), .editable(_, .choice(let configuration))):
                return configuration.options.first(where: { $0.id == optionID })?.replacementValue ?? ""
            case (.empty, .editable(_, .choice(let configuration))):
                if let defaultOptionID = configuration.defaultOptionID,
                   let option = configuration.options.first(where: { $0.id == defaultOptionID }) {
                    return option.replacementValue
                }
                if !configuration.allowsEmptySelection,
                   let firstOption = configuration.options.first {
                    return firstOption.replacementValue
                }
                return ""
            case (.empty, _):
                return ""
            default:
                return ""
        }
    }
}
