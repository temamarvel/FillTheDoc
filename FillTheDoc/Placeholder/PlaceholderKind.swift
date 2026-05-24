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
nonisolated enum PlaceholderKind: Hashable, Sendable {
    case editable(source: PlaceholderValueSource, inputKind: PlaceholderInputKind)
    case derived
    
    var acceptsUserInput: Bool {
        if case .editable = self {
            return true
        }
        return false
    }
    
    var isDerived: Bool { !acceptsUserInput }
    
    var valueSource: PlaceholderValueSource? {
        guard case .editable(let source, _) = self else { return nil }
        return source
    }
    
    var inputKind: PlaceholderInputKind? {
        guard case .editable(_, let inputKind) = self else { return nil }
        return inputKind
    }
    
    var inputKindLabel: String? { inputKind?.label }
    var textEditorStyleLabel: String? { inputKind?.textEditorStyleLabel }
    var valueSourceLabel: String? { valueSource?.label }
    
    var signatureFragment: String {
        switch self {
            case .editable(let source, let inputKind):
                return "editable|\(source.rawValue)|\(inputKind.signatureFragment)"
            case .derived:
                return "derived"
        }
    }
}
