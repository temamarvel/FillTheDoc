//
//  PlaceholderValueSource.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


// MARK: - PlaceholderValueSource

/// Источник значения для плейсхолдеров с `PlaceholderKind.editable`.
///
/// Для вычисляемых (`PlaceholderKind.derived`) плейсхолдеров источник не задаётся:
/// они не редактируются и вычисляются отдельными resolver'ами внутри registry.
nonisolated enum PlaceholderValueSource: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    /// Значение приходит из LLM extraction и затем может быть отредактировано человеком.
    case extracted
    /// Значение задаётся пользователем вручную в UI и никогда не должно прилетать из LLM.
    case manual
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
            case .extracted: return "Извлекается"
            case .manual: return "Заполняется вручную"
        }
    }
}
