//
//  TextEditorStyle.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


// MARK: - Input configuration

/// Предпочтительный визуальный режим текстового поля в форме.
nonisolated enum TextEditorStyle: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case singleLine
    case multiline
    
    var id: String { rawValue }
    
    /// Человекочитаемое название режима для редактора пользовательских плейсхолдеров.
    var label: String {
        switch self {
            case .singleLine:
                return "Однострочное"
            case .multiline:
                return "Многострочное"
        }
    }
    
    /// Стабильный фрагмент сигнатуры для отслеживания изменений definition-модели.
    var signatureFragment: String {
        switch self {
            case .singleLine:
                return "singleLine"
            case .multiline:
                return "multiline"
        }
    }
}
