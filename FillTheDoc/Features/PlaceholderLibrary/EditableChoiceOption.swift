import Foundation

/// Стабильная UI-модель одного редактируемого варианта выбора.
///
/// Отдельный `id` нужен для корректной identity в `ForEach`, даже когда значения пустые
/// или временно совпадают во время редактирования.
struct EditableChoiceOption: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    var value: String
    
    init(
        id: UUID = UUID(),
        value: String = ""
    ) {
        self.id = id
        self.value = value
    }
}
