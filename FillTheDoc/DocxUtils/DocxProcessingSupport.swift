import Foundation
import ZIPFoundation

struct EditableTextNode {
    let element: XMLElement
    let kind: EditableTextKind
    let text: String
}

struct ParagraphProjection {
    let nodes: [EditableTextNode]
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

enum EditableTextKind {
    case text
    case instrText
}

struct ParagraphRunToken {
    let runElement: XMLElement
    let textElement: XMLElement
    let kind: EditableTextKind
    let text: String
    let globalStart: Int
    let globalEnd: Int
    
    var runIdentifier: ObjectIdentifier {
        ObjectIdentifier(runElement)
    }
}

struct ParagraphModel {
    let paragraphElement: XMLElement
    let tokens: [ParagraphRunToken]
    let fullText: String
    let runElements: [XMLElement]
    let runIndexByID: [ObjectIdentifier: Int]
    
    static func build(
        from paragraph: XMLElement,
        includeFieldInstructionText: Bool
    ) -> ParagraphModel {
        let runElements = (((try? paragraph.nodes(forXPath: "./*[local-name()='r']")) as? [XMLElement]) ?? [])
        
        var runIndexByID: [ObjectIdentifier: Int] = [:]
        for (index, run) in runElements.enumerated() {
            runIndexByID[ObjectIdentifier(run)] = index
        }
        
        var tokens: [ParagraphRunToken] = []
        var fullText = ""
        
        for run in runElements {
            let textChildren = (((try? run.nodes(forXPath: "./*[local-name()='t' or local-name()='instrText']")) as? [XMLElement]) ?? [])
            
            for textElement in textChildren {
                let localName = textElement.localName ?? textElement.name ?? ""
                
                if localName == "instrText", includeFieldInstructionText == false {
                    continue
                }
                
                let text = textElement.stringValue ?? ""
                let start = fullText.count
                fullText += text
                let end = fullText.count
                
                let kind: EditableTextKind = (localName == "instrText") ? .instrText : .text
                
                tokens.append(
                    ParagraphRunToken(
                        runElement: run,
                        textElement: textElement,
                        kind: kind,
                        text: text,
                        globalStart: start,
                        globalEnd: end
                    )
                )
            }
        }
        
        return ParagraphModel(
            paragraphElement: paragraph,
            tokens: tokens,
            fullText: fullText,
            runElements: runElements,
            runIndexByID: runIndexByID
        )
    }
}

enum DocxXML {
    
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
    
    static func parseDocument(data: Data, partPath: String) throws -> XMLDocument {
        do {
            return try XMLDocument(data: data, options: [.nodePreserveAll])
        } catch {
            throw DocxProcessingError.failedToParseXML(part: partPath)
        }
    }
    
    static func findParagraphs(in document: XMLDocument) -> [XMLElement] {
        ((try? document.nodes(forXPath: "//*[local-name()='p']")) as? [XMLElement]) ?? []
    }
    
    static func cloneRunSkeleton(from run: XMLElement) -> XMLElement? {
        guard let copy = run.copy() as? XMLElement else { return nil }
        
        let children = copy.children ?? []
        for child in children {
            if let element = child as? XMLElement {
                let localName = element.localName ?? element.name ?? ""
                if localName == "t" || localName == "instrText" {
                    element.detach()
                }
            }
        }
        
        let remainingChildren = copy.children ?? []
        for child in remainingChildren {
            if let element = child as? XMLElement {
                let localName = element.localName ?? element.name ?? ""
                if localName == "rPr" {
                    continue
                }
                
                // Если в run остались не-text children вроде fldChar/tab/br и т.д.,
                // вычищаем их, потому что для rebuilt text run они не нужны.
                element.detach()
            }
        }
        
        return copy
    }
    
    static func preferredTextElementName(from run: XMLElement) -> String {
        let children = (((try? run.nodes(forXPath: "./*[local-name()='t' or local-name()='instrText']")) as? [XMLElement]) ?? [])
        
        if let first = children.first {
            return first.localName ?? first.name ?? "t"
        }
        
        return "t"
    }
    
    static func makeTextElement(localName: String, text: String) -> XMLElement {
        let element = XMLElement(name: "w:\(localName)")
        
        if needsXMLSpacePreserve(for: text) {
            ensureXMLSpacePreserve(on: element)
        }
        
        if !text.isEmpty {
            let textNode = XMLNode.text(withStringValue: text) as! XMLNode
            element.addChild(textNode)
        }
        
        return element
    }
    
    static func ensureXMLSpacePreserve(on element: XMLElement) {
        if let attribute = element.attribute(forName: "xml:space") {
            attribute.stringValue = "preserve"
        } else {
            let attribute = XMLNode.attribute(withName: "xml:space", stringValue: "preserve") as! XMLNode
            element.addAttribute(attribute)
        }
    }
    
    static func removeXMLSpacePreserve(on element: XMLElement) {
        element.attribute(forName: "xml:space")?.detach()
    }
    
    static func needsXMLSpacePreserve(for text: String) -> Bool {
        guard !text.isEmpty else { return false }
        if text.first == " " || text.last == " " { return true }
        if text.contains("  ") { return true }
        if text.contains("\t") || text.contains("\n") || text.contains("\r") { return true }
        return false
    }
    
    static func removeHighlightAndBackground(from run: XMLElement) {
        guard let rPr = ((try? run.nodes(forXPath: "./*[local-name()='rPr']")) as? [XMLElement])?.first else {
            return
        }
        
        let children = (rPr.children ?? []).compactMap { $0 as? XMLElement }
        for child in children {
            let name = child.localName ?? child.name ?? ""
            if name == "highlight" || name == "shd" {
                child.detach()
            }
        }
        
        if (rPr.children ?? []).isEmpty {
            rPr.detach()
        }
    }
}

extension String {
    func substring(from lower: Int, to upper: Int) -> String {
        guard lower >= 0, upper >= lower, upper <= count else { return "" }
        let start = index(startIndex, offsetBy: lower)
        let end = index(startIndex, offsetBy: upper)
        return String(self[start..<end])
    }
}

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
                    .filter { path in
                        path.hasPrefix("word/header") && path.hasSuffix(".xml")
                    }
                    .sorted()
                
                result += allPaths
                    .filter { path in
                        path.hasPrefix("word/footer") && path.hasSuffix(".xml")
                    }
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
                    .filter { path in
                        path.hasPrefix("word/")
                        && path.hasSuffix(".xml")
                        && !path.hasSuffix(".rels")
                    }
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
