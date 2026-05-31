import Foundation

/// Ошибки прикладочного слоя управления пользовательскими плейсхолдерами.
enum CustomPlaceholderRepositoryError: LocalizedError {
    case duplicateKey(PlaceholderKey)
    case definitionNotFound(PlaceholderKey)
    
    var errorDescription: String? {
        switch self {
            case .duplicateKey(let key):
                return "Плейсхолдер \(key.rawValue) уже существует."
            case .definitionNotFound(let key):
                return "Плейсхолдер \(key.rawValue) не найден."
        }
    }
}

/// Actor-репозиторий пользовательских placeholder-definition'ов.
///
/// Он добавляет к низкоуровневому store прикладочные правила:
/// - держит in-memory snapshot определений;
/// - гарантирует уникальность ключей;
/// - отдаёт отсортированный список для UI и registry.
actor CustomPlaceholderRepository {
    private let store: CustomPlaceholderStore
    private var definitions: [PlaceholderDescriptor] = []
    
    init(store: CustomPlaceholderStore) {
        self.store = store
    }
    
    /// Загружает актуальный snapshot определений из persistence-слоя.
    func load() async throws {
        definitions = try await store.load()
    }
    
    /// Возвращает определения в стабильном порядке для UI и registry.
    func all() -> [PlaceholderDescriptor] {
        definitions.sortedCanonically()
    }
    
    /// Добавляет новый placeholder и сразу сохраняет обновлённый набор.
    func add(_ definition: PlaceholderDescriptor) async throws {
        guard !definitions.contains(where: { $0.key == definition.key }) else {
            throw CustomPlaceholderRepositoryError.duplicateKey(definition.key)
        }
        definitions.append(definition)
        try await store.save(definitions)
    }
    
    /// Обновляет существующий placeholder по ключу.
    func update(_ definition: PlaceholderDescriptor) async throws {
        guard let index = definitions.firstIndex(where: { $0.key == definition.key }) else {
            throw CustomPlaceholderRepositoryError.definitionNotFound(definition.key)
        }
        definitions[index] = definition
        try await store.save(definitions)
    }
    
    /// Удаляет placeholder по ключу и сохраняет обновлённый набор.
    func delete(key: PlaceholderKey) async throws {
        let oldCount = definitions.count
        definitions.removeAll { $0.key == key }
        guard definitions.count != oldCount else {
            throw CustomPlaceholderRepositoryError.definitionNotFound(key)
        }
        try await store.save(definitions)
    }
}
