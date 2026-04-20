//
//  DocxProcessingError.swift
//  FillTheDoc


//
//  Created by Артем Денисов on 19.04.2026.
//


import Foundation
import ZIPFoundation

// MARK: - Shared public error

public enum DocxProcessingError: LocalizedError {
    case fileNotFound(URL)
    case invalidDocx(URL)
    case missingMainDocumentXML
    case cannotCreateOutputArchive(URL)
    case failedToReadXML(part: String)
    case failedToParseXML(part: String)
    case failedToWriteXML(part: String)
    case missingReplacementValues([String])
    case zipSlipDetected(String)
    
    public var errorDescription: String? {
        switch self {
            case .fileNotFound(let url):
                return "DOCX file not found: \(url.path)"
            case .invalidDocx(let url):
                return "File is not a valid DOCX archive: \(url.path)"
            case .missingMainDocumentXML:
                return "DOCX does not contain word/document.xml"
            case .cannotCreateOutputArchive(let url):
                return "Cannot create output DOCX archive at: \(url.path)"
            case .failedToReadXML(let part):
                return "Failed to read XML part: \(part)"
            case .failedToParseXML(let part):
                return "Failed to parse XML part: \(part)"
            case .failedToWriteXML(let part):
                return "Failed to write XML part: \(part)"
            case .missingReplacementValues(let keys):
                return "Missing values for placeholders: \(keys.joined(separator: ", "))"
            case .zipSlipDetected(let entryPath):
                return "Unsafe ZIP entry path detected: \(entryPath)"
        }
    }
}

// MARK: - Shared part selection

enum DocxPartSelection: Sendable {
    case standard
    case allWordXML
}

struct DocxPartOptions: Sendable {
    var includeFootnotes: Bool
    var includeEndnotes: Bool
    var includeComments: Bool
    var includeFieldInstructionText: Bool
    var selection: DocxPartSelection
}

// MARK: - Placeholder parsing

struct DocxPlaceholderMatch {
    let raw: String
    let key: String
    let range: Range<String.Index>
}

enum DocxPlaceholderParser {
    static let regex = try! NSRegularExpression(pattern: #"<\!([A-Za-z0-9_]+)\!>"#)
    
    static func findMatches(in text: String) -> [DocxPlaceholderMatch] {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        
        return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
            guard
                match.numberOfRanges == 2,
                let fullRange = Range(match.range(at: 0), in: text),
                let keyRange = Range(match.range(at: 1), in: text)
            else {
                return nil
            }
            
            return DocxPlaceholderMatch(
                raw: String(text[fullRange]),
                key: String(text[keyRange]),
                range: fullRange
            )
        }
    }
}

// MARK: - XML helpers

enum DocxXML {
    /// Parses DOCX XML data into an `XMLDocument`.
    ///
    /// Apple's `XMLDocument` silently drops whitespace-only text nodes
    /// (e.g. `<w:t xml:space="preserve"> </w:t>`) even with `.nodePreserveAll`.
    /// We work around this by converting whitespace-only content inside `<w:t>`
    /// and `<w:instrText>` elements to `&#x20;` entity references before parsing.
    static func parseDocument(data: Data, partPath: String) throws -> XMLDocument {
        let preprocessed = protectWhitespaceOnlyTextNodes(in: data)
        do {
            return try XMLDocument(data: preprocessed, options: [.nodePreserveAll])
        } catch {
            throw DocxProcessingError.failedToParseXML(part: partPath)
        }
    }
    
    /// Replaces whitespace-only content in `<w:t ...>` and `<w:instrText ...>` with
    /// `&#x20;` / `&#x09;` entity references so `XMLDocument` does not discard them.
    private static func protectWhitespaceOnlyTextNodes(in data: Data) -> Data {
        guard var xmlString = String(data: data, encoding: .utf8) else { return data }
        
        // Pattern: (opening w:t or w:instrText tag)(whitespace-only content)(closing tag)
        let pattern = #"(<(?:\w+:)?(?:t|instrText)\b[^>]*>)([ \t\r\n]+)(</(?:\w+:)?(?:t|instrText)>)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return data }
        
        let ns = xmlString as NSString
        let matches = regex.matches(in: xmlString, range: NSRange(location: 0, length: ns.length))
        
        // Process in reverse to preserve indices
        for match in matches.reversed() {
            guard match.numberOfRanges == 4 else { continue }
            let contentRange = match.range(at: 2)
            let content = ns.substring(with: contentRange)
            
            let escaped = content
                .replacingOccurrences(of: " ", with: "&#x20;")
                .replacingOccurrences(of: "\t", with: "&#x09;")
                .replacingOccurrences(of: "\r", with: "&#xD;")
                .replacingOccurrences(of: "\n", with: "&#xA;")
            
            let startIdx = xmlString.index(xmlString.startIndex, offsetBy: contentRange.location)
            let endIdx = xmlString.index(startIdx, offsetBy: contentRange.length)
            xmlString.replaceSubrange(startIdx..<endIdx, with: escaped)
        }
        
        return xmlString.data(using: .utf8) ?? data
    }
    
    static func findParagraphs(in document: XMLDocument) -> [XMLElement] {
        ((try? document.nodes(forXPath: "//*[local-name()='p']")) as? [XMLElement]) ?? []
    }
    
    static func collectEditableTextNodes(
        in paragraph: XMLElement,
        includeFieldInstructionText: Bool
    ) -> [EditableTextNode] {
        guard let nodes = try? paragraph.nodes(
            forXPath: ".//*[local-name()='t' or local-name()='instrText']"
        ) as? [XMLElement] else {
            return []
        }
        
        return nodes.compactMap { element in
            let localName = element.localName ?? element.name ?? ""
            
            if localName == "instrText", includeFieldInstructionText == false {
                return nil
            }
            
            return EditableTextNode(
                element: element,
                kind: localName == "instrText" ? .instrText : .text,
                text: element.stringValue ?? ""
            )
        }
    }
    
    static func setExactText(_ value: String, on element: XMLElement) {
        for child in element.children ?? [] {
            child.detach()
        }
        
        if !value.isEmpty {
            let textNode = XMLNode.text(withStringValue: value) as! XMLNode
            element.addChild(textNode)
        }
    }
    
    static func ensureXMLSpacePreserve(on element: XMLElement) {
        if let attribute = element.attribute(forName: "xml:space") {
            attribute.stringValue = "preserve"
        } else {
            let attribute = XMLNode.attribute(withName: "xml:space", stringValue: "preserve") as! XMLNode
            element.addAttribute(attribute)
        }
        
    }
    
    static func needsXMLSpacePreserve(for text: String) -> Bool {
        guard !text.isEmpty else { return false }
        if text.first == " " || text.last == " " { return true }
        if text.contains("  ") { return true }
        if text.contains("\t") || text.contains("\n") { return true }
        return false
    }
}

// MARK: - Editable text projection

enum EditableTextKind {
    case text
    case instrText
}

struct EditableTextNode {
    let element: XMLElement
    let kind: EditableTextKind
    var text: String
    var isDirty: Bool = false
}

struct ParagraphProjection {
    var nodes: [EditableTextNode]
    let fullText: String
    
    static func build(
        from paragraph: XMLElement,
        includeFieldInstructionText: Bool
    ) -> ParagraphProjection {
        
        
        
        
        
        
        
        
        let nodes = DocxXML.collectEditableTextNodes(
            in: paragraph,
            includeFieldInstructionText: includeFieldInstructionText
        )
        
        return ParagraphProjection(
            nodes: nodes,
            fullText: nodes.map(\.text).joined()
        )
    }
}

// MARK: - Offset mapping

struct TextLocation {
    let nodeIndex: Int
    let offset: Int
}

enum TextOffsetMapper {
    static func prefixSums(for lengths: [Int]) -> [Int] {
        var result = Array(repeating: 0, count: lengths.count + 1)
        for index in lengths.indices {
            result[index + 1] = result[index] + lengths[index]
        }
        return result
    }
    
    static func locateStart(
        position: String.Index,
        in fullText: String,
        prefixSums: [Int]
    ) -> TextLocation? {
        let target = fullText.distance(from: fullText.startIndex, to: position)
        
        for i in 0..<(prefixSums.count - 1) {
            let start = prefixSums[i]
            let end = prefixSums[i + 1]
            
            if target >= start && target < end {
                return TextLocation(nodeIndex: i, offset: target - start)
            }
        }
        
        return nil
    }
    
    static func locateEnd(
        position: String.Index,
        in fullText: String,
        prefixSums: [Int]
    ) -> TextLocation? {
        let target = fullText.distance(from: fullText.startIndex, to: position)
        
        if target == fullText.count {
            for i in stride(from: prefixSums.count - 2, through: 0, by: -1) {
                let start = prefixSums[i]
                let end = prefixSums[i + 1]
                if end > start {
                    return TextLocation(nodeIndex: i, offset: end - start)
                }
            }
        }
        
        for i in 0..<(prefixSums.count - 1) {
            let start = prefixSums[i]
            let end = prefixSums[i + 1]
            
            guard end > start else { continue }
            
            if target > start && target <= end {
                return TextLocation(nodeIndex: i, offset: target - start)
            }
        }
        
        return nil
    }
}

// MARK: - String slicing

extension String {
    func prefixCharacters(_ count: Int) -> String {
        String(prefix(max(0, count)))
    }
    
    func suffixCharacters(from offset: Int) -> String {
        guard offset > 0 else { return self }
        guard offset < count else { return "" }
        let index = self.index(startIndex, offsetBy: offset)
        return String(self[index...])
    }
}

// MARK: - ZIP helpers

enum DocxArchive {
    static func openForRead(_ url: URL) throws -> Archive {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw DocxProcessingError.invalidDocx(url)
        }
        return archive
    }
    
    static func openForCreate(_ url: URL) throws -> Archive {
        guard let archive = Archive(url: url, accessMode: .create) else {
            throw DocxProcessingError.cannotCreateOutputArchive(url)
        }
        return archive
    }
    
    static func extractEntryData(from entry: Entry, in archive: Archive) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }
    
    static func locatePartPaths(in archive: Archive, options: DocxPartOptions) -> [String] {
        let allPaths = archive.map(\.path)
        
        switch options.selection {
            case .standard:
                var result: [String] = []
                
                if allPaths.contains("word/document.xml") {
                    result.append("word/document.xml")
                }
                
                result += allPaths
                    .filter { $0.hasPrefix("word/header") && $0.hasSuffix(".xml") }
                    .sorted()
                
                result += allPaths
                    .filter { $0.hasPrefix("word/footer") && $0.hasSuffix(".xml") }
                    .sorted()
                
                if options.includeFootnotes, allPaths.contains("word/footnotes.xml") {
                    result.append("word/footnotes.xml")
                }
                
                if options.includeEndnotes, allPaths.contains("word/endnotes.xml") {
                    result.append("word/endnotes.xml")
                }
                
                if options.includeComments, allPaths.contains("word/comments.xml") {
                    result.append("word/comments.xml")
                }
                
                return result
                
            case .allWordXML:
                return allPaths
                    .filter { $0.hasPrefix("word/") && $0.hasSuffix(".xml") && !$0.hasSuffix(".rels") }
                    .sorted()
        }
    }
    
    static func extractAllSafely(from archive: Archive, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let basePath = destinationURL.standardizedFileURL.path
        
        for entry in archive {
            let entryPath = entry.path
            
            if entryPath.contains("..") || entryPath.hasPrefix("/") || entryPath.hasPrefix("\\") {
                throw DocxProcessingError.zipSlipDetected(entryPath)
            }
            
            let outputURL = destinationURL.appendingPathComponent(entryPath)
            let standardizedOutputPath = outputURL.standardizedFileURL.path
            
            guard standardizedOutputPath == basePath || standardizedOutputPath.hasPrefix(basePath + "/") else {
                throw DocxProcessingError.zipSlipDetected(entryPath)
            }
            
            try fileManager.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            switch entry.type {
                case .directory:
                    try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
                default:
                    _ = try archive.extract(entry, to: outputURL)
            }
        }
    }
    
    static func addDirectoryContents(
        from directoryURL: URL,
        to archive: Archive
    ) throws {
        let fileManager = FileManager.default
        let basePath = directoryURL.standardizedFileURL.path
        
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                continue
            }
            
            var relativePath = fileURL.standardizedFileURL.path
            if relativePath.hasPrefix(basePath + "/") {
                relativePath.removeFirst(basePath.count + 1)
            }
            
            try archive.addEntry(
                with: relativePath,
                fileURL: fileURL,
                compressionMethod: .deflate
            )
        }
    }
    
    static func locatePartURLs(
        root: URL,
        options: DocxPartOptions
    ) throws -> [URL] {
        let fileManager = FileManager.default
        let mainDoc = root.appendingPathComponent("word/document.xml")
        
        guard fileManager.fileExists(atPath: mainDoc.path) else {
            throw DocxProcessingError.missingMainDocumentXML
        }
        
        switch options.selection {
            case .standard:
                var urls: [URL] = [mainDoc]
                let wordDir = root.appendingPathComponent("word", isDirectory: true)
                
                let contents = try fileManager.contentsOfDirectory(
                    at: wordDir,
                    includingPropertiesForKeys: nil
                )
                
                urls += contents
                    .filter { $0.lastPathComponent.hasPrefix("header") && $0.pathExtension.lowercased() == "xml" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                
                urls += contents
                    .filter { $0.lastPathComponent.hasPrefix("footer") && $0.pathExtension.lowercased() == "xml" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                
                if options.includeFootnotes {
                    let url = wordDir.appendingPathComponent("footnotes.xml")
                    if fileManager.fileExists(atPath: url.path) { urls.append(url) }
                }
                
                if options.includeEndnotes {
                    let url = wordDir.appendingPathComponent("endnotes.xml")
                    if fileManager.fileExists(atPath: url.path) { urls.append(url) }
                }
                
                if options.includeComments {
                    let url = wordDir.appendingPathComponent("comments.xml")
                    if fileManager.fileExists(atPath: url.path) { urls.append(url) }
                }
                
                return urls
                
            case .allWordXML:
                let wordDir = root.appendingPathComponent("word", isDirectory: true)
                let enumerator = fileManager.enumerator(
                    at: wordDir,
                    includingPropertiesForKeys: nil
                )
                
                var urls: [URL] = []
                
                while let url = enumerator?.nextObject() as? URL {
                    guard url.pathExtension.lowercased() == "xml" else { continue }
                    guard !url.lastPathComponent.hasSuffix(".rels") else { continue }
                    urls.append(url)
                }
                
                return urls.sorted { relativePath(of: $0, under: root) < relativePath(of: $1, under: root) }
        }
    }
    
    static func relativePath(of url: URL, under root: URL) -> String {
        var path = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        
        if path.hasPrefix(rootPath + "/") {
            path.removeFirst(rootPath.count + 1)
        }
        
        return path
    }
}
