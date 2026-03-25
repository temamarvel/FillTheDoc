//
//  String+Utils.swift
//  FillTheDoc
//

import Foundation

extension String {

    /// Обрезает пробельные символы с обоих концов.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Обрезает пробелы; возвращает `nil`, если строка пустая.
    var trimmedNilIfEmpty: String? {
        let t = trimmed
        return t.isEmpty ? nil : t
    }

    /// Оставляет только цифры.
    var digitsOnly: String {
        filter(\.isNumber)
    }

    /// Заменяет символы переноса строки и табуляцию на пробел, затем обрезает.
    /// Используется при формировании строки для Google Sheets (TSV).
    var sanitizedForTSV: String {
        replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmed
    }
}

extension Optional where Wrapped == String {

    /// Возвращает строку, если она не пустая после обрезки, иначе `nil`.
    var trimmedNilIfEmpty: String? {
        self?.trimmedNilIfEmpty
    }
}
