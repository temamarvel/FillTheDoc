import Foundation

/// Преобразует runtime-значение поля формы в строку, которая попадёт в итоговый DOCX.
///
/// Это важная boundary-роль в новой архитектуре:
/// - форма хранит типизированный `PlaceholderFieldValue`;
/// - registry хранит definition (`PlaceholderDescriptor`);
/// - шаблонизатор работает только со строками.
///
/// Благодаря этому `choice`-поля не размазывают special-case'ы по UI, export и scanner-слоям.
struct PlaceholderValueResolver: Sendable {
    func replacementValue(
        for value: PlaceholderFieldValue,
        definition: PlaceholderDescriptor
    ) -> String {
        switch (value, definition.inputKind) {
            case (.text(let text), .some(.text)):
                return definition.normalizer(text)
            case (.text(let text), .some(.multilineText)):
                return definition.normalizer(text)
            case (.choice(let optionID), .some(.choice(let configuration))):
                return configuration.options.first(where: { $0.id == optionID })?.replacementValue ?? ""
            case (.empty, .some(.choice(let configuration))):
                if let defaultOptionID = configuration.defaultOptionID,
                   let option = configuration.options.first(where: { $0.id == defaultOptionID }) {
                    return option.replacementValue
                }
                return ""
            case (.empty, _):
                return ""
            default:
                return ""
        }
    }
}
