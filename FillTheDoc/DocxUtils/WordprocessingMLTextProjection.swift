//
//  WordprocessingMLTextProjection.swift
//  FillTheDoc
//
//  Shared text projection layer for DocxTemplatePlaceholderScanner and DocxPlaceholderReplacer.
//  Ensures both components see the same linear text model for a given paragraph.
//

import Foundation

// MARK: - TextSegment

struct TextSegment {
    enum Kind: Sendable {
        case wT
        case instrText
        case tab
        case lineBreak
        case carriageReturn
        case noBreakHyphen
        case softHyphen
    }

    let element: XMLElement
    let kind: Kind
    let runElement: XMLElement?

    /// Текстовая проекция сегмента в линейную строку fullText параграфа.
    var text: String

    /// true для сегментов, содержимое которых можно переписать (w:t, w:instrText).
    let isEditableTextNode: Bool

    /// Флаг для replacer: был ли сегмент изменён в процессе замены.
    var isDirty: Bool

    init(
        element: XMLElement,
        kind: Kind,
        runElement: XMLElement?,
        text: String,
        isEditableTextNode: Bool,
        isDirty: Bool = false
    ) {
        self.element = element
        self.kind = kind
        self.runElement = runElement
        self.text = text
        self.isEditableTextNode = isEditableTextNode
        self.isDirty = isDirty
    }
}

// MARK: - ParagraphTextProjection

struct ParagraphTextProjection {
    let segments: [TextSegment]
    let fullText: String
}

// MARK: - WordprocessingMLTextProjection

enum WordprocessingMLTextProjection {

    /// Строит текстовую проекцию параграфа: сегменты + склеенный fullText.
    /// Scanner и replacer обязаны использовать этот метод, чтобы видеть одинаковый текст.
    static func buildParagraphTextProjection(
        from paragraph: XMLElement,
        includeFieldInstructionText: Bool
    ) -> ParagraphTextProjection {
        let segments = collectTextSegments(
            in: paragraph,
            includeFieldInstructionText: includeFieldInstructionText
        )
        let fullText = segments.map(\.text).joined()
        return ParagraphTextProjection(segments: segments, fullText: fullText)
    }

    // MARK: - Internal segment collection

    static func collectTextSegments(
        in paragraph: XMLElement,
        includeFieldInstructionText: Bool
    ) -> [TextSegment] {
        var segments: [TextSegment] = []

        // Обходим runs в document order, чтобы fullText совпадал с реальным порядком XML.
        let runNodes = ((try? paragraph.nodes(forXPath: "./*[local-name()='r']")) as? [XMLElement]) ?? []

        for run in runNodes {
            for child in run.children ?? [] {
                guard let element = child as? XMLElement else { continue }
                let localName = element.localName ?? element.name ?? ""

                switch localName {
                case "t":
                    // Пробелы не обрезаем — они могут быть значимыми.
                    segments.append(TextSegment(
                        element: element,
                        kind: .wT,
                        runElement: run,
                        text: element.stringValue ?? "",
                        isEditableTextNode: true
                    ))
                case "instrText":
                    guard includeFieldInstructionText else { continue }
                    segments.append(TextSegment(
                        element: element,
                        kind: .instrText,
                        runElement: run,
                        text: element.stringValue ?? "",
                        isEditableTextNode: true
                    ))
                case "tab":
                    segments.append(TextSegment(
                        element: element,
                        kind: .tab,
                        runElement: run,
                        text: "\t",
                        isEditableTextNode: false
                    ))
                case "br":
                    segments.append(TextSegment(
                        element: element,
                        kind: .lineBreak,
                        runElement: run,
                        text: "\n",
                        isEditableTextNode: false
                    ))
                case "cr":
                    segments.append(TextSegment(
                        element: element,
                        kind: .carriageReturn,
                        runElement: run,
                        text: "\n",
                        isEditableTextNode: false
                    ))
                case "noBreakHyphen":
                    segments.append(TextSegment(
                        element: element,
                        kind: .noBreakHyphen,
                        runElement: run,
                        text: "\u{2011}",
                        isEditableTextNode: false
                    ))
                case "softHyphen":
                    segments.append(TextSegment(
                        element: element,
                        kind: .softHyphen,
                        runElement: run,
                        text: "\u{00AD}",
                        isEditableTextNode: false
                    ))
                default:
                    continue
                }
            }
        }

        return segments
    }
}
