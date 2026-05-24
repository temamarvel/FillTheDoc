import Foundation

typealias FieldNormalizer = @Sendable (String) -> String
typealias FieldValidator = @Sendable (String) -> FieldIssue?

nonisolated struct PlaceholderBehavior: Sendable {
    let normalizer: FieldNormalizer
    let validator: FieldValidator
    let resolver: (@Sendable (PlaceholderResolutionContext) -> String?)?
    
    nonisolated init(
        normalizer: @escaping FieldNormalizer = { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
        validator: @escaping FieldValidator = { _ in nil },
        resolver: (@Sendable (PlaceholderResolutionContext) -> String?)? = nil
    ) {
        self.normalizer = normalizer
        self.validator = validator
        self.resolver = resolver
    }
}
