//
//  PlaceholderValueSource.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


// MARK: - PlaceholderValueSource

/// Источник значения для полей, которые пользователь может редактировать.
///
/// `derived`-плейсхолдеры в эту модель не входят: они не редактируются и
/// вычисляются отдельными resolver'ами внутри registry.
nonisolated enum PlaceholderValueSource: String, Codable, Hashable, Sendable {
    /// Значение приходит из LLM extraction и затем может быть отредактировано человеком.
    case extracted
    /// Значение задаётся пользователем вручную в UI и никогда не должно прилетать из LLM.
    case manual
    
    var label: String {
        switch self {
            case .extracted: return "Извлекается"
            case .manual: return "Заполняется вручную"
        }
    }
}
