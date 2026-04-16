//
//  FormFocusKey.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 13.04.2026.
//

struct DocumentMetadata {
    let companyDetails: [CompanyDetails.CompanyDetailsKeys: FieldMetadata]
    let documentDetails: [DocumentDetails.DocumentDetailsKeys: FieldMetadata]
}


enum FormFocusKey: Hashable, CodingKey, CaseIterable {
    case company(CompanyDetails.CompanyDetailsKeys)
    case document(DocumentDetails.DocumentDetailsKeys)
    
    static var allCases: [FormFocusKey] {
        CompanyDetails.CompanyDetailsKeys.allCases.map(Self.company)
        + DocumentDetails.DocumentDetailsKeys.allCases.map(Self.document)
    }
    
    var stringValue: String {
        switch self {
            case .company(let key):
                return "company.\(key.stringValue)"
            case .document(let key):
                return "document.\(key.stringValue)"
        }
    }
    
    init?(stringValue: String) {
        let parts = stringValue.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        
        switch String(parts[0]) {
            case "company":
                guard let key = CompanyDetails.CompanyDetailsKeys(stringValue: String(parts[1])) else {
                    return nil
                }
                self = .company(key)
                
            case "document":
                guard let key = DocumentDetails.DocumentDetailsKeys(stringValue: String(parts[1])) else {
                    return nil
                }
                self = .document(key)
                
            default:
                return nil
        }
    }
    
    var intValue: Int? { nil }
    
    init?(intValue: Int) { nil }
}
