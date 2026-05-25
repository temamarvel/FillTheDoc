//
//  TextEditorStyle.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


// MARK: - Input configuration

nonisolated enum TextEditorStyle: Hashable, Codable, Sendable {
    case singleLine
    case multiline(minLines: Int = 1, maxLines: Int = 8)
    
    var label: String {
        switch self {
            case .singleLine:
                return "Однострочное"
            case .multiline:
                return "Многострочное"
        }
    }
    
    var signatureFragment: String {
        switch self {
            case .singleLine:
                return "singleLine"
            case .multiline(let minLines, let maxLines):
                return "multiline|\(minLines)|\(maxLines)"
        }
    }
}
