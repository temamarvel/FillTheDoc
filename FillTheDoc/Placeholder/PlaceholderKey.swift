import Foundation

/// Канонический идентификатор плейсхолдера в приложении.
///
/// Важно, что `PlaceholderKey` описывает только identity (`company_name`, `date_short` и т.п.)
/// и не знает ничего про UI, валидацию или способ вычисления значения.
struct PlaceholderKey: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    let rawValue: String
    
    init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
    
    /// Returns `true` for keys that are conditional-assembly control tokens
    /// (e.g. `switch_start:legal_form`, `case_end`, `default_start`),
    /// not regular replacement placeholders.
    var isControlToken: Bool {
        // Control tokens either contain a colon (switch_start:key, case_start:value)
        // or match one of the fixed service keywords.
        if rawValue.contains(":") { return true }
        switch rawValue {
            case "switch_end", "case_end", "default_start", "default_end":
                return true
            default:
                return false
        }
    }
}
