//
//  PlaceholderSection.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


// MARK: - PlaceholderSection

/// UI- и каталог-ориентированная группировка плейсхолдеров.
///
/// `section` не определяет, КАК считается значение, а только помогает
/// показывать плейсхолдеры пользователю и группировать форму/библиотеку.
/// Это presentation-классификация, а не вычислительная.
nonisolated enum PlaceholderSection: String, Codable, Hashable, Sendable, CaseIterable {
    case company
    case document
    case computed
    case custom
    
    var title: String {
        switch self {
            case .company: return "Реквизиты компании"
            case .document: return "Данные документа"
            case .computed: return "Вычисляемые"
            case .custom: return "Пользовательские"
        }
    }
}
