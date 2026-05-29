import Foundation

/// Преобразует runtime-значение поля формы в строку, которая попадёт в итоговый DOCX.
///
/// Это важная boundary-роль в новой архитектуре:
/// - форма хранит типизированный `PlaceholderFieldValue`;
/// - registry хранит definition (`PlaceholderDescriptor`);
/// - шаблонизатор работает только со строками.
///
/// Благодаря этому `choice`-поля не размазывают special-case'ы по UI, export и scanner-слоям.
nonisolated struct PlaceholderReplacementValueResolver: Sendable {
    func replacementValue(
        for value: PlaceholderFieldValue,
        descriptor: PlaceholderDescriptor
    ) -> String {
        switch (value, descriptor.kind) {
            case (.text(let text), .editable(_, .text)):
                return text
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
