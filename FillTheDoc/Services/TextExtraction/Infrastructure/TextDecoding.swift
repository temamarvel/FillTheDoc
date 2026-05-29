//
//  TextDecoding.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//

import Foundation


/// Вспомогательная стратегия best-effort декодирования текстовых файлов.
///
/// При извлечении из внешних источников кодировка часто неизвестна заранее,
/// поэтому декодер последовательно пробует несколько практичных вариантов,
/// типичных для русского документооборота.
enum TextDecoding {
    static func decodeBestEffort(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .utf16) { return s }
        if let s = String(data: data, encoding: .windowsCP1251) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        return String(decoding: data, as: UTF8.self)
    }
}
