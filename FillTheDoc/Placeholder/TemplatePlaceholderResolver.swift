import Foundation

enum TemplatePlaceholderResolver {
    static func resolve(
        formModel: PlaceholderFormModel,
        company: CompanyDetails,
        computed: [ComputedPlaceholderDefinition] = ComputedPlaceholderCatalog.definitions,
        now: Date = .now
    ) -> [String: String] {
        let allValues = formModel.editableValues()
        let customValues = formModel.editableValues(in: .custom)

        let context = TemplateResolveContext(
            company: company,
            editableValues: allValues,
            customValues: customValues,
            now: now
        )

        var result: [String: String] = [:]

        // Editable values
        for (key, value) in allValues {
            result[key.rawValue] = value
        }

        // Computed values
        for definition in computed {
            result[definition.key.rawValue] = definition.resolver(context) ?? ""
        }

        return result
    }
}
