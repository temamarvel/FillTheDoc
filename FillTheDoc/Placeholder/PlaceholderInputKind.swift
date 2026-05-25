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
    case text(TextInputConfiguration)
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
    
    /// Признак обязательности ввода на уровне definition-модели.
    var isRequired: Bool {
        switch self {
            case .text(let configuration):
                return configuration.isRequired
            case .choice(let configuration):
                return !configuration.allowsEmptySelection
        }
    }
    
    /// Стабильный фрагмент сигнатуры для синхронизации UI с изменившимся registry.
    var signatureFragment: String {
        switch self {
            case .text(let configuration):
                return "text|\(configuration.isRequired)|\(configuration.trimOnCommit)|\(configuration.editorStyle.signatureFragment)"
            case .choice(let configuration):
                let optionsLine = configuration.options
                    .map { "\($0.id):\($0.title):\($0.replacementValue)" }
                    .joined(separator: ";")
                return "choice|\(optionsLine)|\(configuration.defaultOptionID ?? "")|\(configuration.allowsEmptySelection)|\(configuration.emptyTitle)|\(configuration.presentationStyle.rawValue)"
        }
    }
}
