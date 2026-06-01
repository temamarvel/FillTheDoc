//
//  PlaceholderInputKind.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


/// Описывает форму пользовательского ввода для editable-плейсхолдера.
///
/// Этот enum нужен, чтобы registry и UI опирались на единое определение того,
/// является ли поле обычным текстом или полем выбора с опциями.
nonisolated enum PlaceholderInputKind: Hashable, Codable, Sendable {
    case text
    case choice(ChoiceInputConfiguration)
    
    /// Короткое человекочитаемое название типа ввода для UI.
    var label: String {
        switch self {
            case .text:
                return "Текст"
            case .choice:
                return "Выбор"
        }
    }
    
    /// Стабильный фрагмент сигнатуры для синхронизации UI с изменившимся registry.
    var signatureFragment: String {
        switch self {
            case .text:
                return "text"
            case .choice(let configuration):
                let optionsLine = configuration.options
                    .joined(separator: ";")
                return "choice|\(optionsLine)|\(configuration.allowsEmptyValue)|\(configuration.emptyTitle)"
        }
    }
}
