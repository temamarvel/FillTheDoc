//
//  DocumentDetailsModel.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 14.04.2026.
//

import Foundation

@MainActor
@Observable
final class DocumentDetailsModel {
    
    private(set) var fields: [DocumentDetails.DocumentDetailsKeys: FieldState] = [:]
    private let metadata: [DocumentDetails.DocumentDetailsKeys: FieldMetadata]
    private let allFieldKeys: [DocumentDetails.DocumentDetailsKeys]
    private let validator: DocumentDetailsValidator
    
    init(
        metadata: [DocumentDetails.DocumentDetailsKeys: FieldMetadata],
        keys: [DocumentDetails.DocumentDetailsKeys]
    ) {
        self.metadata = metadata
        self.allFieldKeys = keys
        self.validator = DocumentDetailsValidator(metadata: metadata)
        self.fields = Self.createFields(allFieldKeys: allFieldKeys, metadata: metadata)
        validateAllFields()
    }
    
    private static func createFields(
        allFieldKeys: [DocumentDetails.DocumentDetailsKeys],
        metadata: [DocumentDetails.DocumentDetailsKeys: FieldMetadata]
    ) -> [DocumentDetails.DocumentDetailsKeys: FieldState] {
        var fields: [DocumentDetails.DocumentDetailsKeys: FieldState] = [:]
        let documentDetails = DocumentDetails()
        for key in allFieldKeys {
            let raw = documentDetails[key]
            let normalized = raw.flatMap { value in
                metadata[key].map { $0.normalizer(value) } ?? value.trimmedNilIfEmpty
            }
            fields[key] = FieldState(value: normalized, issue: nil)
        }
        return fields
    }
    
    // MARK: - Field access (для UI)
    
    func keysInOrder() -> [DocumentDetails.DocumentDetailsKeys] { allFieldKeys }
    func value(for key: DocumentDetails.DocumentDetailsKeys) -> String { fields[key]?.value ?? "" }
    func issue(for key: DocumentDetails.DocumentDetailsKeys) -> FieldIssue? { fields[key]?.issue }
    func title(for key: DocumentDetails.DocumentDetailsKeys) -> String { metadata[key]?.title ?? key.stringValue }
    func placeholder(for key: DocumentDetails.DocumentDetailsKeys) -> String { metadata[key]?.placeholder ?? "" }
    var hasErrors: Bool { fields.values.contains { $0.issue?.severity == .error } }
    
    // MARK: - Set value (local only)
    
    func setValue(_ newValue: String, for key: DocumentDetails.DocumentDetailsKeys) {
        guard var fieldState = fields[key] else { return }
        
        let normalized: String
        if let normalizer = metadata[key]?.normalizer {
            normalized = normalizer(newValue)
        } else {
            normalized = newValue.trimmed
        }
        fieldState.value = normalized
        fieldState.issue = validateField(for: key, state: fieldState)
        
        fields[key] = fieldState
    }
    
    func validateAllFields() {
        for key in keysInOrder() {
            if var fieldState = fields[key] {
                fieldState.issue = validateField(for: key, state: fieldState)
                fields[key] = fieldState
            }
        }
    }
    
    // MARK: - Build DTO
    
    func buildResult(companyDetails: CompanyDetails) throws -> DocumentDetails {
        if hasErrors {
            // если у тебя есть свой тип ошибки — подставь его
            throw ValidationError(message: "В форме есть ошибки")
        }
        
        return DocumentDetails(
            documentNumber: value(for: .documentNumber),
            fee: value(for: .fee),
            minFee: value(for: .minFee),
            companyDetails: companyDetails
        )
    }
    
    // MARK: - Local messages policy
    
    private func validateField(for key: DocumentDetails.DocumentDetailsKeys, state: FieldState) -> FieldIssue? {
        return validator.validateField(for: key, state: state)
    }
}
