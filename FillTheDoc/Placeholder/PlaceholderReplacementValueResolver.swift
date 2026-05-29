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
        switch value {
            case .value(let string):
                return string
            case .empty:
                return ""
        }
    }
}
