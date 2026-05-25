//
//  TextInputConfiguration.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


nonisolated struct TextInputConfiguration: Hashable, Codable, Sendable {
    var isRequired: Bool
    var trimOnCommit: Bool
    var editorStyle: TextEditorStyle
    
    init(
        isRequired: Bool = false,
        trimOnCommit: Bool = true,
        editorStyle: TextEditorStyle = .singleLine
    ) {
        self.isRequired = isRequired
        self.trimOnCommit = trimOnCommit
        self.editorStyle = editorStyle
    }
}
