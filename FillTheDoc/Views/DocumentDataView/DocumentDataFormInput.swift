import Foundation

/// Snapshot входных данных формы редактирования документа.
///
/// `id` отделяет одну editing session от другой: когда extraction или registry
/// реально меняются, SwiftUI должен создать новую форму, а не переиспользовать
/// предыдущий `@State`-состояние view model.
struct DocumentDataFormInput: Identifiable, Sendable {
    let id: UUID
    let descriptors: [PlaceholderDescriptor]
    let extractedValues: [PlaceholderKey: String]
    
    init(
        id: UUID = UUID(),
        descriptors: [PlaceholderDescriptor],
        extractedValues: [PlaceholderKey: String]
    ) {
        self.id = id
        self.descriptors = descriptors
        self.extractedValues = extractedValues
    }
}