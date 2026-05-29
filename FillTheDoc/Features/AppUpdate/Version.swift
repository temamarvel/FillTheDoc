import Foundation

/// Value-object для сравнения версий приложения.
///
/// Нужен потому, что сравнение строк вида `1.10` и `1.9`, а также prerelease-суффиксов,
/// нельзя надёжно делать обычным lexical compare.
/// Этот тип изолирует всю логику сравнения, чтобы network/UI-слой оперировал уже
/// понятным правилом «есть обновление / нет обновления».
nonisolated struct Version: Comparable, CustomStringConvertible, Sendable {
    let components: [Int]
    let prerelease: Prerelease?
    
    var description: String {
        let base = components.map(String.init).joined(separator: ".")
        if let prerelease {
            return "\(base)-\(prerelease.rawValue)"
        }
        return base
    }
    
    init?(_ raw: String) {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "v", with: "", options: [.anchored, .caseInsensitive])
        
        guard !normalized.isEmpty else { return nil }
        
        let parts = normalized.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        let numericPart = String(parts[0])
        let numericComponents = numericPart
            .split(separator: ".")
            .compactMap { Int($0) }
        
        guard !numericComponents.isEmpty else { return nil }
        
        self.components = numericComponents
        self.prerelease = parts.count > 1 ? Prerelease(String(parts[1])) : nil
    }
    
    static func < (lhs: Version, rhs: Version) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)
        
        for index in 0..<maxCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            
            if left != right {
                return left < right
            }
        }
        
        switch (lhs.prerelease, rhs.prerelease) {
            case (nil, nil):
                return false
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            case let (.some(left), .some(right)):
                return left < right
        }
    }
    
    enum Prerelease: Comparable, Sendable {
        case alpha
        case beta
        case rc
        case other(String)
        
        init(_ raw: String) {
            let value = raw.lowercased()
            
            if value.hasPrefix("alpha") {
                self = .alpha
            } else if value.hasPrefix("beta") {
                self = .beta
            } else if value.hasPrefix("rc") {
                self = .rc
            } else {
                self = .other(value)
            }
        }
        
        var rawValue: String {
            switch self {
                case .alpha: return "alpha"
                case .beta: return "beta"
                case .rc: return "rc"
                case .other(let value): return value
            }
        }
        
        private var rank: Int {
            switch self {
                case .alpha: return 0
                case .beta: return 1
                case .rc: return 2
                case .other: return 3
            }
        }
        
        static func < (lhs: Prerelease, rhs: Prerelease) -> Bool {
            if lhs.rank != rhs.rank {
                return lhs.rank < rhs.rank
            }
            
            switch (lhs, rhs) {
                case let (.other(left), .other(right)):
                    return left < right
                default:
                    return false
            }
        }
    }
}
