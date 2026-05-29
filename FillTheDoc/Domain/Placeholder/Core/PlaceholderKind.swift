//
//  PlaceholderKind.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


// MARK: - PlaceholderKind

/// Явно описывает жизненный цикл плейсхолдера.
///
/// - `editable` означает, что у плейсхолдера есть пользовательский ввод,
///   конкретный `inputKind` и понятный `valueSource`.
/// - `derived` означает, что значение вычисляется системой resolver'ов и
///   пользователь его не редактирует.
nonisolated enum PlaceholderKind: Hashable, Codable, Sendable {
    case editable(source: PlaceholderValueSource, inputKind: PlaceholderInputKind)
    case derived
    
    var signatureFragment: String {
        switch self {
            case .editable(let source, let inputKind):
                return "editable|\(source.rawValue)|\(inputKind.signatureFragment)"
            case .derived:
                return "derived"
        }
    }
}
