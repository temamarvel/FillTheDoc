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
    private var descriptors: [PlaceholderDescriptor] = []
    
    init(store: CustomPlaceholderStore) {
        self.store = store
    }
    
    func load() async throws {
        descriptors = try await store.load()
    }
    
    func all() -> [PlaceholderDescriptor] {
        descriptors.sorted { lhs, rhs in
            if lhs.order == rhs.order {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.order < rhs.order
        }
    }
    
    func add(_ definition: PlaceholderDescriptor) async throws {
        guard !descriptors.contains(where: { $0.key == definition.key }) else {
            throw CustomPlaceholderRepositoryError.duplicateKey(definition.key)
        }
        descriptors.append(definition)
        try await store.save(descriptors)
    }
    
    func update(_ definition: PlaceholderDescriptor) async throws {
        guard let index = descriptors.firstIndex(where: { $0.key == definition.key }) else {
            throw CustomPlaceholderRepositoryError.definitionNotFound(definition.key)
        }
        descriptors[index] = definition
        try await store.save(descriptors)
    }
    
    func delete(key: PlaceholderKey) async throws {
        let oldCount = descriptors.count
        descriptors.removeAll { $0.key == key }
        guard descriptors.count != oldCount else {
            throw CustomPlaceholderRepositoryError.definitionNotFound(key)
        }
        try await store.save(descriptors)
    }
}
