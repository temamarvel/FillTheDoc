import Foundation

/// Динамический контейнер ответа LLM для extracted placeholder-значений.
///
/// Сохраняет извлечённые значения прямо в placeholder-domain без фиксированного DTO.
/// Ключи приходят по JSON-схеме из `placeholderRegistry.extractedDescriptors`,
/// а затем используются как черновик значений для формы подтверждения.
struct ExtractedPlaceholderValues: Decodable, Sendable {
    let values: [PlaceholderKey: String?]
    
    init(values: [PlaceholderKey: String?]) {
        self.values = values
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PlaceholderCodingKey.self)
        var result: [PlaceholderKey: String?] = [:]
        
        for key in container.allKeys {
            let value = try container.decodeIfPresent(String.self, forKey: key)
            result[key.placeholderKey] = value?.trimmedNilIfEmpty
        }
        
        self.values = result
    }
    
    /// Отбрасывает `nil` и пустые строки, оставляя только фактические extracted значения.
    func stringValues() -> [PlaceholderKey: String] {
        values.compactMapValues { $0?.trimmedNilIfEmpty }
    }
}

/// `CodingKey`-адаптер для динамических JSON-ключей вида `company_name`, `inn`, `fee`.
/// Нужен для декодирования ответа модели в placeholder-domain без жёстко зашитого enum-а ключей.
struct PlaceholderCodingKey: CodingKey, Sendable {
    let stringValue: String
    let intValue: Int?
    let placeholderKey: PlaceholderKey
    
    private init(stringValue: String, intValue: Int?) {
        self.stringValue = stringValue
        self.intValue = intValue
        self.placeholderKey = stringValue.placeholderKey
    }
    
    init(stringValue: String) {
        self.init(stringValue: stringValue, intValue: nil)
    }
    
    init?(intValue: Int) {
        self.init(stringValue: "\(intValue)", intValue: intValue)
    }
}
