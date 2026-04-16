//
//  LocalFieldValidator.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 14.04.2026.
//


import Foundation

struct LocalFieldValidator<Key: Hashable & Sendable>: Sendable {
    private let metadata: [Key: FieldMetadata]
    private let validationIssue: @Sendable (FieldMetadata?) -> FieldIssue?

    init(
        metadata: [Key: FieldMetadata],
        missingValueIssue: @escaping @Sendable (FieldMetadata?) -> FieldIssue?
    ) {
        self.metadata = metadata
        self.validationIssue = missingValueIssue
    }

    public func validateField(for fieldKey: Key, state: FieldState) -> FieldIssue? {
        guard let validator = metadata[fieldKey]?.validator else {
            return nil
        }

        guard let value = state.value else {
            return validationIssue(metadata[fieldKey])
        }

        return validator(value)
    }
}
