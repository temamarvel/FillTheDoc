import Foundation

struct ExtractedPlaceholderValues: Decodable, Sendable {
    let values: [PlaceholderKey: String?]
    
    init(values: [PlaceholderKey: String?]) {
        self.values = values
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var result: [PlaceholderKey: String?] = [:]
        
        for key in container.allKeys {
            let value = try container.decodeIfPresent(String.self, forKey: key)
            result[PlaceholderKey(rawValue: key.stringValue)] = value?.trimmedNilIfEmpty
        }
        
        self.values = result
    }
    
    func stringValues() -> [PlaceholderKey: String] {
        values.compactMapValues { $0?.trimmedNilIfEmpty }
    }
}

struct DynamicCodingKey: CodingKey, Sendable {
    let stringValue: String
    let intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
