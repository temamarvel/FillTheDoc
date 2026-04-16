//
//  FieldState.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 17.04.2026.
//


public struct FieldState: Sendable, Equatable {
    var value : String?
    var issue: FieldIssue?
    var isValid: Bool {
        issue == nil
    }
}
