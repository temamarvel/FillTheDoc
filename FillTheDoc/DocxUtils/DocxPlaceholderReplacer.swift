//
//  DocxPlaceholderReplacer.swift
//  FillTheDoc
//

import Foundation
import ZIPFoundation

public final class DocxPlaceholderReplacer: Sendable {
    
    // MARK: - Options
    
    public struct Options: Sendable {
        public enum MissingKeyPolicy: Sendable {
            case error
            case keep
            case blank
        }
        
        public var includeFootnotes: Bool = true
        public var includeEndnotes: Bool = true
        public var includeComments: Bool = true
        public var selection: PartsSelection = .standard
        public var missingKeyPolicy: MissingKeyPolicy = .keep
        public var preserveWhitespaceWhenNeeded: Bool = true
        public var includeFieldInstructionText: Bool = false
        public var validateTemplate: Bool = true
        public var sanitizeValues: Bool = true
        public var onWarning: (@Sendable (String) -> Void)? = nil
        
        public enum PartsSelection: Sendable {
            case standard
            case allWordXML
        }
        
        public init() {}
        
        fileprivate var core: DocxPartOptions {
            DocxPartOptions(
                includeFootnotes: includeFootnotes,
                includeEndnotes: includeEndnotes,
                includeComments: includeComments,
                includeFieldInstructionText: includeFieldInstructionText,
                selection: selection == .allWordXML ? .allWordXML : .standard
            )
        }
    }
    
    // MARK: - Report
    
    public struct Report: Sendable {
        public var processedParts: [String] = []
        public var foundKeys: Set<String> = []
        public var replacedKeys: Set<String> = []
        public var missingKeys: Set<String> = []
        public var replacementsCount: Int = 0
        
        public init() {}
    }
    
    // MARK: - Error
    
    public enum Error: Swift.Error, LocalizedError {
        case cannotCreateOutputArchive
        case missingKeys([String])
        
        public var errorDescription: String? {
            switch self {
                case .cannotCreateOutputArchive:
                    return "Cannot create output DOCX archive."
                case .missingKeys(let keys):
                    return "Template contains placeholders without values: \(keys.joined(separator: ", "))."
            }
        }
    }
    
    public init() {}
    
    // MARK: - Public API
    
    public func fill(
        templateURL template: URL,
        outputURL output: URL,
        values: [String: String],
        options: Options = .init()
    ) async throws -> Report {
        let fm = FileManager.default
        
        if options.validateTemplate {
            guard fm.fileExists(atPath: template.path) else {
                throw DocxProcessingError.fileNotFound(template)
            }
        }
        
        let processedValues = options.sanitizeValues ? sanitizeValuesDictionary(values) : values
        
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("fillthedoc-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            do { try fm.removeItem(at: tempDir) }
            catch { options.onWarning?("Failed to clean temp directory: \(error.localizedDescription)") }
        }
        
        // 1) Unzip
        let src = try DocxArchive.openForRead(template)
        try DocxArchive.extractAllSafely(from: src, to: tempDir)
        
        // 2) Locate parts
        let partURLs = try DocxArchive.locatePartURLs(root: tempDir, options: options.core)
        
        // 3) Replace
        var report = Report()
        
        for url in partURLs {
            let rel = DocxArchive.relativePath(of: url, under: tempDir)
            
            do {
                let (partReport, didChange) = try replaceInPart(
                    partURL: url,
                    values: processedValues,
                    options: options,
                    partPath: rel
                )
                
                if didChange {
                    report.processedParts.append(rel)
                }
                
                report.foundKeys.formUnion(partReport.foundKeys)
                report.replacedKeys.formUnion(partReport.replacedKeys)
                report.missingKeys.formUnion(partReport.missingKeys)
                report.replacementsCount += partReport.replacementsCount
            } catch {
                options.onWarning?("Failed to process \(rel): \(error.localizedDescription)")
            }
        }
        
        // 4) Missing policy
        if options.missingKeyPolicy == .error, !report.missingKeys.isEmpty {
            throw Error.missingKeys(report.missingKeys.sorted())
        }
        
        // 5) Zip back
        if fm.fileExists(atPath: output.path) {
            try fm.removeItem(at: output)
        }
        
        let out = try DocxArchive.openForCreate(output)
        try DocxArchive.addDirectoryContents(from: tempDir, to: out)
        
        return report
    }
    
    // MARK: - Sanitization
    
    private func sanitizeValuesDictionary(_ values: [String: String]) -> [String: String] {
        values.mapValues { sanitizeValue($0) }
    }
    
    private func sanitizeValue(_ value: String) -> String {
        var sanitized = value
        sanitized = sanitized.replacingOccurrences(of: "<!", with: "&lt;!")
        sanitized = sanitized.replacingOccurrences(of: "!>", with: "!&gt;")
        return sanitized
    }
}

// MARK: - Part-level replacement

private struct PartReport {
    var foundKeys: Set<String> = []
    var replacedKeys: Set<String> = []
    var missingKeys: Set<String> = []
    var replacementsCount: Int = 0
}

private func replaceInPart(
    partURL: URL,
    values: [String: String],
    options: DocxPlaceholderReplacer.Options,
    partPath: String
) throws -> (PartReport, Bool) {
    let data: Data
    do {
        data = try Data(contentsOf: partURL)
    } catch {
        throw DocxProcessingError.failedToReadXML(part: partPath)
    }
    
    let doc = try DocxXML.parseDocument(data: data, partPath: partPath)
    
    let rewriter = ParagraphRewriter(options: options, values: values)
    let (report, didChange) = rewriter.rewrite(document: doc)
    
    if didChange {
        let outData = doc.xmlData(options: [.nodePreserveAll])
        do {
            try outData.write(to: partURL, options: [.atomic])
        } catch {
            throw DocxProcessingError.failedToWriteXML(part: partPath)
        }
    }
    
    return (report, didChange)
}

// MARK: - ParagraphRewriter

private struct ParagraphRewriter {
    let options: DocxPlaceholderReplacer.Options
    let values: [String: String]
    
    func rewrite(document: XMLDocument) -> (PartReport, Bool) {
        var report = PartReport()
        var didChange = false
        
        for paragraph in DocxXML.findParagraphs(in: document) {
            let (paragraphReport, changed) = rewriteParagraph(paragraph)
            
            report.foundKeys.formUnion(paragraphReport.foundKeys)
            report.replacedKeys.formUnion(paragraphReport.replacedKeys)
            report.missingKeys.formUnion(paragraphReport.missingKeys)
            report.replacementsCount += paragraphReport.replacementsCount
            
            if changed { didChange = true }
        }
        
        return (report, didChange)
    }
    
    // MARK: Paragraph rewrite
    
    private func rewriteParagraph(_ paragraph: XMLElement) -> (PartReport, Bool) {
        var model = ParagraphProjection.build(
            from: paragraph,
            includeFieldInstructionText: options.includeFieldInstructionText
        )
        
        guard !model.nodes.isEmpty else { return (PartReport(), false) }
        
        let matches = DocxPlaceholderParser.findMatches(in: model.fullText)
        guard !matches.isEmpty else { return (PartReport(), false) }
        
        let lengths = model.nodes.map(\.text.count)
        let prefixes = TextOffsetMapper.prefixSums(for: lengths)
        
        var report = PartReport()
        var changed = false
        
        // Process in reverse to preserve indices
        for match in matches.reversed() {
            report.foundKeys.insert(match.key)
            
            let replacement: String?
            if let value = values[match.key] {
                replacement = value
                report.replacedKeys.insert(match.key)
            } else {
                report.missingKeys.insert(match.key)
                switch options.missingKeyPolicy {
                    case .error: replacement = nil
                    case .keep:  replacement = nil
                    case .blank: replacement = ""
                }
            }
            
            guard let replacement else { continue }
            
            guard
                let start = TextOffsetMapper.locateStart(
                    position: match.range.lowerBound,
                    in: model.fullText,
                    prefixSums: prefixes
                ),
                let end = TextOffsetMapper.locateEnd(
                    position: match.range.upperBound,
                    in: model.fullText,
                    prefixSums: prefixes
                )
            else { continue }
            
            applyReplacement(nodes: &model.nodes, start: start, end: end, replacement: replacement)
            clearPlaceholderHighlight(in: model.nodes, from: start.nodeIndex, to: end.nodeIndex)
            report.replacementsCount += 1
            changed = true
        }
        
        if changed {
            commitChanges(to: &model.nodes)
        }
        
        return (report, changed)
    }
    
    // MARK: Replacement
    
    private func applyReplacement(
        nodes: inout [EditableTextNode],
        start: TextLocation,
        end: TextLocation,
        replacement: String
    ) {
        let si = start.nodeIndex
        let ei = end.nodeIndex
        
        if si == ei {
            let original = nodes[si].text
            let pre = original.prefixCharacters(start.offset)
            let suf = original.suffixCharacters(from: end.offset)
            nodes[si].text = pre + replacement + suf
            nodes[si].isDirty = true
            return
        }
        
        let first = nodes[si].text
        let last = nodes[ei].text
        let pre = first.prefixCharacters(start.offset)
        let suf = last.suffixCharacters(from: end.offset)
        
        nodes[si].text = pre + replacement + suf
        nodes[si].isDirty = true
        
        for index in (si + 1)...ei {
            if !nodes[index].text.isEmpty {
                nodes[index].text = ""
                nodes[index].isDirty = true
            }
        }
    }
    
    // MARK: Commit
    
    private func commitChanges(to nodes: inout [EditableTextNode]) {
        for index in nodes.indices {
            guard nodes[index].isDirty else { continue }
            
            DocxXML.setExactText(nodes[index].text, on: nodes[index].element)
            
            if nodes[index].kind == .text {
                if options.preserveWhitespaceWhenNeeded,
                   DocxXML.needsXMLSpacePreserve(for: nodes[index].text) {
                    DocxXML.ensureXMLSpacePreserve(on: nodes[index].element)
                }
            }
            
            nodes[index].isDirty = false
        }
    }
    
    // MARK: Highlight cleanup
    
    private func clearPlaceholderHighlight(
        in nodes: [EditableTextNode],
        from startIndex: Int,
        to endIndex: Int
    ) {
        guard startIndex <= endIndex else { return }
        var handledRuns = Set<ObjectIdentifier>()
        
        for index in startIndex...endIndex {
            guard let run = owningRun(for: nodes[index].element) else { continue }
            
            let runID = ObjectIdentifier(run)
            guard handledRuns.insert(runID).inserted else { continue }
            
            clearHighlightAttributes(from: run)
        }
    }
    
    private func owningRun(for element: XMLElement) -> XMLElement? {
        var current = element.parent
        while let node = current {
            if let el = node as? XMLElement,
               (el.localName ?? el.name ?? "") == "r" {
                return el
            }
            current = node.parent
        }
        return nil
    }
    
    private func clearHighlightAttributes(from run: XMLElement) {
        let path = "./*[local-name()='rPr']"
        
        let rPr: XMLElement
        if let existing = ((try? run.nodes(forXPath: path)) as? [XMLElement])?.first {
            rPr = existing
        } else {
            let created = XMLElement(name: "w:rPr")
            run.insertChild(created, at: 0)
            rPr = created
        }
        
        removeChildren(named: "shd", from: rPr)
        removeChildren(named: "highlight", from: rPr)
    }
    
    private func removeChildren(named localName: String, from element: XMLElement) {
        for child in (element.children ?? []).reversed() {
            guard let childElement = child as? XMLElement else { continue }
            let childLocalName = childElement.localName ?? childElement.name ?? ""
            if childLocalName == localName {
                child.detach()
            }
        }
    }
}
