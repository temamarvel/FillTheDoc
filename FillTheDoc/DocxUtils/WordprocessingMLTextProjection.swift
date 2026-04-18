//
//  WordprocessingMLTextProjection.swift
//  FillTheDoc
//

import Foundation

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
    
    /// Точная текстовая проекция сегмента в линейную строку paragraph fullText.
    var text: String
    
    /// true только для сегментов, которые реально можно переписать как text node
    /// (например w:t и instrText).
    let isEditableTextNode: Bool
    
    /// Для replacer: был ли сегмент изменён.
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

struct ParagraphTextProjection {
    let segments: [TextSegment]
    let fullText: String
}

enum WordprocessingMLTextProjection {
    
    static func buildParagraphTextProjection(
        from paragraph: XMLElement,
        includeFieldInstructionText: Bool
    ) -> ParagraphTextProjection {
        let segments = collectTextSegments(
            in: paragraph,
            includeFieldInstructionText: includeFieldInstructionText
        )
        
        return ParagraphTextProjection(
            segments: segments,
            fullText: segments.map(\.text).joined()
        )
    }
    
    static func collectTextSegments(
        in paragraph: XMLElement,
        includeFieldInstructionText: Bool
    ) -> [TextSegment] {
        var segments: [TextSegment] = []
        
        // Важно: берём ВСЕ run-ы внутри paragraph subtree, а не только прямых детей.
        // Это лучше работает для hyperlink / ins / smartTag / customXml и похожих структур.
        let runNodes = ((try? paragraph.nodes(forXPath: ".//*[local-name()='r']")) as? [XMLElement]) ?? []
        
        for run in runNodes {
            for child in run.children ?? [] {
                guard let element = child as? XMLElement else { continue }
                let localName = element.localName ?? element.name ?? ""
                
                switch localName {
                    case "t":
                        // Никакого trim: даже " " для DOCX может быть значимым.
                        segments.append(
                            TextSegment(
                                element: element,
                                kind: .wT,
                                runElement: run,
                                text: element.stringValue ?? "",
                                isEditableTextNode: true
                            )
                        )
                        
                    case "instrText":
                        guard includeFieldInstructionText else { continue }
                        segments.append(
                            TextSegment(
                                element: element,
                                kind: .instrText,
                                runElement: run,
                                text: element.stringValue ?? "",
                                isEditableTextNode: true
                            )
                        )
                        
                    case "tab":
                        segments.append(
                            TextSegment(
                                element: element,
                                kind: .tab,
                                runElement: run,
                                text: "\t",
                                isEditableTextNode: false
                            )
                        )
                        
                    case "br":
                        segments.append(
                            TextSegment(
                                element: element,
                                kind: .lineBreak,
                                runElement: run,
                                text: "\n",
                                isEditableTextNode: false
                            )
                        )
                        
                    case "cr":
                        segments.append(
                            TextSegment(
                                element: element,
                                kind: .carriageReturn,
                                runElement: run,
                                text: "\n",
                                isEditableTextNode: false
                            )
                        )
                        
                    case "noBreakHyphen":
                        segments.append(
                            TextSegment(
                                element: element,
                                kind: .noBreakHyphen,
                                runElement: run,
                                text: "\u{2011}",
                                isEditableTextNode: false
                            )
                        )
                        
                    case "softHyphen":
                        segments.append(
                            TextSegment(
                                element: element,
                                kind: .softHyphen,
                                runElement: run,
                                text: "\u{00AD}",
                                isEditableTextNode: false
                            )
                        )
                        
                    default:
                        continue
                }
            }
        }
        
        return segments
    }
}
