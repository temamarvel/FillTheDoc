//
//  DocumentDetailsValidator.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 17.04.2026.
//


public actor DocumentDetailsValidator {
    
    typealias Key = DocumentDetails.DocumentDetailsKeys
    
    private let metadata: [Key: FieldMetadata]
    private let localValidator: LocalFieldValidator<Key>
    
    init(metadata: [Key: FieldMetadata]) {
        self.metadata = metadata
        
        self.localValidator = LocalFieldValidator(metadata: self.metadata) { fieldMedata in .warning("\(fieldMedata?.title ?? "Поле") не введен") }
    }
    
    nonisolated func validateField(for fieldKey: Key, state: FieldState) -> FieldIssue? {
        localValidator.validateField(for: fieldKey, state: state)
    }
}
