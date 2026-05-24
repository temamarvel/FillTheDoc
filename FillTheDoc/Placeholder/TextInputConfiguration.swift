//
//  TextInputConfiguration.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


nonisolated struct TextInputConfiguration: Hashable, Codable, Sendable {
    var placeholder: String
    var isRequired: Bool
    var trimOnCommit: Bool
    var editorStyle: TextEditorStyle
    
    init(
        placeholder: String = "",
        isRequired: Bool = false,
        trimOnCommit: Bool = true,
        editorStyle: TextEditorStyle = .singleLine
    ) {
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.trimOnCommit = trimOnCommit
        self.editorStyle = editorStyle
    }
    
    private enum CodingKeys: String, CodingKey {
        case placeholder
        case isRequired
        case trimOnCommit
        case editorStyle
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder) ?? ""
        self.isRequired = try container.decodeIfPresent(Bool.self, forKey: .isRequired) ?? false
        self.trimOnCommit = try container.decodeIfPresent(Bool.self, forKey: .trimOnCommit) ?? true
        self.editorStyle = try container.decodeIfPresent(TextEditorStyle.self, forKey: .editorStyle) ?? .singleLine
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(placeholder, forKey: .placeholder)
        try container.encode(isRequired, forKey: .isRequired)
        try container.encode(trimOnCommit, forKey: .trimOnCommit)
        try container.encode(editorStyle, forKey: .editorStyle)
    }
}
