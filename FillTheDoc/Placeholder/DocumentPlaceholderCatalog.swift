import Foundation

enum DocumentPlaceholderCatalog {
    static let editableDefinitions: [EditablePlaceholderDefinition] = [
        .init(
            key: "document_number",
            title: "Номер договора", placeholder: "yyyy-mm-#",
            section: .document, isRequired: false,
            normalizer: { $0.trimmed },
            validator: { _ in nil }
        ),
        .init(
            key: "fee",
            title: "Комиссия, %", placeholder: "10",
            section: .document, isRequired: true,
            normalizer: { $0.trimmed },
            validator: Validators.percentage
        ),
        .init(
            key: "min_fee",
            title: "Мин. комиссия, руб", placeholder: "10",
            section: .document, isRequired: true,
            normalizer: { $0.trimmed },
            validator: Validators.percentage
        ),
    ]
}
