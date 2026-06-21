import Foundation

/// Канонический идентификатор плейсхолдера в приложении.
///
/// Это самый «тонкий» тип placeholder-domain: он описывает только identity
/// (`company_name`, `date_short`, `fee` и т.п.) и принципиально не знает:
/// - как поле показывается в UI;
/// - обязательно ли оно;
/// - как валидируется;
/// - откуда берётся его значение.
///
/// Все эти знания живут отдельно, в `PlaceholderDescriptor` и `PlaceholderRegistry`.
/// Такое разделение делает ключи универсальными: их можно использовать и в форме,
/// и в библиотеке плейсхолдеров, и в словаре для DOCX fill.
nonisolated struct PlaceholderKey: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
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
    ///
    /// Это важное различие для template engine:
    /// control tokens управляют сборкой условных блоков и не должны вести себя
    /// как обычные пользовательские поля вроде `inn` или `company_name`.
    var isControlToken: Bool {
        // Control tokens either contain a colon (switch_start:key, case_start:value)
        // or match one of the fixed service keywords.
        if rawValue.contains(":") { return true }
        switch rawValue {
                //TODO: do it with enum?
            case "switch_end", "case_end", "default_start", "default_end":
                return true
            default:
                return false
        }
    }
}
