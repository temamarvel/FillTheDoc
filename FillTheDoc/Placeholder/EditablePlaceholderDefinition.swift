import Foundation

struct EditablePlaceholderDefinition: Identifiable, Sendable {
    enum Section: String, Hashable, Sendable, CaseIterable {
        case document
        case company
        case custom
    }

    let id: PlaceholderKey
    let key: PlaceholderKey
    let title: String
    let placeholder: String
    let section: Section
    let isRequired: Bool
    let normalizer: @Sendable (String) -> String
    let validator: @Sendable (String) -> FieldIssue?

    // Identifiable + Hashable by key only (closures can't be Equatable)
    static func == (lhs: EditablePlaceholderDefinition, rhs: EditablePlaceholderDefinition) -> Bool {
        lhs.key == rhs.key
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}

extension EditablePlaceholderDefinition: Hashable {}
