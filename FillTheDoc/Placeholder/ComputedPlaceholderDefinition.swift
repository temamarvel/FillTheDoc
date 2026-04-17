import Foundation

struct TemplateResolveContext: Sendable {
    let company: CompanyDetails
    let editableValues: [PlaceholderKey: String]
    let customValues: [PlaceholderKey: String]
    let now: Date
}

struct ComputedPlaceholderDefinition: Identifiable, Sendable {
    let id: PlaceholderKey
    let key: PlaceholderKey
    let resolver: @Sendable (TemplateResolveContext) -> String?
}
