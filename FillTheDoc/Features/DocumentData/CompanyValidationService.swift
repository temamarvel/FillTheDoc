import Foundation

@MainActor
final class CompanyValidationService {
    private let validator: CompanyReferenceValidator
    private var validationTask: Task<Void, Never>?
    private var lastLookupKey: String?

    init(validator: CompanyReferenceValidator = CompanyReferenceValidator()) {
        self.validator = validator
    }

    deinit {
        validationTask?.cancel()
    }

    func scheduleValidation(
        valuesProvider: @escaping @MainActor () -> [PlaceholderKey: String],
        applyIssues: @escaping @MainActor ([PlaceholderKey: FieldIssue]) -> Void
    ) {
        let values = valuesProvider()
        guard let lookupKey = Self.lookupKey(for: values) else {
            cancel()
            applyIssues([:])
            lastLookupKey = nil
            return
        }

        guard lookupKey != lastLookupKey else { return }

        validationTask?.cancel()
        validationTask = Task { [validator] in
            do {
                try await Task.sleep(for: .milliseconds(300))
                try Task.checkCancellation()

                let currentValues = await MainActor.run(body: valuesProvider)
                let issues = await validator.validate(values: currentValues)
                let currentLookupKey = Self.lookupKey(for: currentValues)

                try Task.checkCancellation()
                await MainActor.run {
                    applyIssues(issues)
                    lastLookupKey = currentLookupKey
                    validationTask = nil
                }
            } catch {
                await MainActor.run {
                    validationTask = nil
                }
            }
        }
    }

    func runValidationNow(
        valuesProvider: @escaping @MainActor () -> [PlaceholderKey: String],
        applyIssues: @escaping @MainActor ([PlaceholderKey: FieldIssue]) -> Void
    ) {
        validationTask?.cancel()

        let values = valuesProvider()
        guard Self.lookupKey(for: values) != nil else {
            applyIssues([:])
            lastLookupKey = nil
            validationTask = nil
            return
        }

        validationTask = Task { [validator] in
            let currentValues = await MainActor.run(body: valuesProvider)
            let issues = await validator.validate(values: currentValues)
            let currentLookupKey = Self.lookupKey(for: currentValues)

            await MainActor.run {
                applyIssues(issues)
                lastLookupKey = currentLookupKey
                validationTask = nil
            }
        }
    }

    func cancel() {
        validationTask?.cancel()
        validationTask = nil
    }
}

private extension CompanyValidationService {
    static func lookupKey(for values: [PlaceholderKey: String]) -> String? {
        values[.ogrn]?.trimmedNilIfEmpty ?? values[.inn]?.trimmedNilIfEmpty
    }
}
