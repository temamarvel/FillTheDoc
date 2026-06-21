import Foundation

/// Собирает финальный словарь placeholder-значений для downstream pipeline.
///
/// Здесь происходит только одна ответственность:
/// `approvedValues + derived values = resolvedValues`.
///
/// Assembler не читает DOCX, не ищет токены, не валидирует и не нормализует input.
struct PlaceholderValueAssembler: Sendable {
    private let derivedValueFactory: BuiltInDerivedValueFactory
    
    init(
        derivedValueFactory: BuiltInDerivedValueFactory = .init()
    ) {
        self.derivedValueFactory = derivedValueFactory
    }
    
    /// Собирает полный набор значений для шаблона.
    ///
    /// `resolvedValues = approvedValues + derived values`.
    func assemble(
        approvedValues: [PlaceholderKey: String]
    ) -> [PlaceholderKey: String] {
        var resolvedValues = approvedValues
        let derivedValues = derivedValueFactory.makeValues(
            sourceValues: approvedValues
        )
        
        resolvedValues.merge(derivedValues) { _, derived in
            derived
        }
        
        return resolvedValues
    }
}
