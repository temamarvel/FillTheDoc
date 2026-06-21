import Foundation

@MainActor
final class CompanyValidationService {
    private let validator: CompanyReferenceValidator
    private var validationTask: Task<Void, Never>?
    private var lastValidationSignature: String?
    
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
        guard let validationSignature = Self.validationSignature(for: values) else {
            cancel()
            applyIssues([:])
            lastValidationSignature = nil
            return
        }
        
        guard validationSignature != lastValidationSignature else { return }
        
        validationTask?.cancel()
        validationTask = Task { [validator] in
            do {
                try await Task.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                
                let currentValues = await MainActor.run(body: valuesProvider)
                let resolution = await validator.resolve(values: currentValues)
                let currentValidationSignature = Self.validationSignature(for: currentValues)
                
                try Task.checkCancellation()
                await MainActor.run {
                    applyIssues(resolution.issues)
                    lastValidationSignature = currentValidationSignature
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
            lastValidationSignature = nil
            validationTask = nil
            return
        }
        
        validationTask = Task { [validator] in
            let currentValues = await MainActor.run(body: valuesProvider)
            let resolution = await validator.resolve(values: currentValues)
            let currentValidationSignature = Self.validationSignature(for: currentValues)
            
            await MainActor.run {
                applyIssues(resolution.issues)
                lastValidationSignature = currentValidationSignature
                validationTask = nil
            }
        }
    }
    
    func runReplacementNow(
        valuesProvider: @escaping @MainActor () -> [PlaceholderKey: String],
        applyResult: @escaping @MainActor (
            [PlaceholderKey: FieldIssue],
            [PlaceholderKey: String]
        ) -> Void
    ) {
        validationTask?.cancel()
        
        let values = valuesProvider()
        guard Self.lookupKey(for: values) != nil else {
            applyResult([:], [:])
            lastValidationSignature = nil
            validationTask = nil
            return
        }
        
        validationTask = Task { [validator] in
            let currentValues = await MainActor.run(body: valuesProvider)
            let resolution = await validator.resolve(values: currentValues)
            let currentValidationSignature = Self.validationSignature(for: currentValues)
            
            await MainActor.run {
                applyResult(resolution.issues, resolution.referenceValues)
                lastValidationSignature = currentValidationSignature
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
    
    static func validationSignature(for values: [PlaceholderKey: String]) -> String? {
        guard lookupKey(for: values) != nil else { return nil }
        
        return values
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.rawValue)=\($0.value.trimmed)" }
            .joined(separator: "|")
    }
}
