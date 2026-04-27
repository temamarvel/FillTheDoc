import Foundation

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

actor CustomPlaceholderRepository {
    private let store: CustomPlaceholderStore
    private var definitions: [CustomPlaceholderDefinition] = []
    
    init(store: CustomPlaceholderStore) {
        self.store = store
    }
    
    func load() async throws {
        definitions = try await store.load()
    }
    
    func all() -> [CustomPlaceholderDefinition] {
        definitions.sorted { lhs, rhs in
            if lhs.order == rhs.order {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.order < rhs.order
        }
    }
    
    func enabled() -> [CustomPlaceholderDefinition] {
        all().filter(\.isEnabled)
    }
    
    func add(_ definition: CustomPlaceholderDefinition) async throws {
        guard !definitions.contains(where: { $0.key == definition.key }) else {
            throw CustomPlaceholderRepositoryError.duplicateKey(definition.key)
        }
        definitions.append(definition)
        try await store.save(definitions)
    }
    
    func update(_ definition: CustomPlaceholderDefinition) async throws {
        guard let index = definitions.firstIndex(where: { $0.key == definition.key }) else {
            throw CustomPlaceholderRepositoryError.definitionNotFound(definition.key)
        }
        var updated = definition
        updated.updatedAt = Date()
        definitions[index] = updated
        try await store.save(definitions)
    }
    
    func delete(key: PlaceholderKey) async throws {
        let oldCount = definitions.count
        definitions.removeAll { $0.key == key }
        guard definitions.count != oldCount else {
            throw CustomPlaceholderRepositoryError.definitionNotFound(key)
        }
        try await store.save(definitions)
    }
}
