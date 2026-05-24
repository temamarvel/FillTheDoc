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
    
    private enum CodingKeys: String, CodingKey {
        case type
        case minLines
        case maxLines
    }
    
    private enum Kind: String, Codable {
        case singleLine
        case multiline
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decodeIfPresent(Kind.self, forKey: .type) ?? .singleLine
        switch kind {
            case .singleLine:
                self = .singleLine
            case .multiline:
                let minLines = try container.decodeIfPresent(Int.self, forKey: .minLines) ?? 1
                let maxLines = try container.decodeIfPresent(Int.self, forKey: .maxLines) ?? 8
                self = .multiline(minLines: minLines, maxLines: max(maxLines, minLines))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .singleLine:
                try container.encode(Kind.singleLine, forKey: .type)
            case .multiline(let minLines, let maxLines):
                try container.encode(Kind.multiline, forKey: .type)
                try container.encode(minLines, forKey: .minLines)
                try container.encode(maxLines, forKey: .maxLines)
        }
    }
}
