import Foundation
import ZIPFoundation

public final class DocxPlaceholderReplacer: Sendable {
    
    public struct Options: Sendable {
        public enum PartsSelection: Sendable {
            case standard
            case allWordXML
        }
        
        public enum MissingKeyPolicy: Sendable {
            case error
            case keep
            case blank
        }
        
        public var includeFootnotes: Bool = true
        public var includeEndnotes: Bool = true
        public var includeComments: Bool = true
        public var includeFieldInstructionText: Bool = false
        public var selection: PartsSelection = .standard
        public var missingKeyPolicy: MissingKeyPolicy = .keep
        public var validateTemplateFileExists: Bool = true
        public var sanitizeValues: Bool = true
        public var onWarning: (@Sendable (String) -> Void)?
        
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
    
    public struct Report: Sendable {
        public var processedParts: [String] = []
        public var foundKeys: Set<String> = []
        public var replacedKeys: Set<String> = []
        public var missingKeys: Set<String> = []
        public var replacementsCount: Int = 0
        
        public init() {}
    }
    
    public init() {}
    
    public func fill(
        templateURL: URL,
        outputURL: URL,
        values: [String: String],
        options: Options = .init()
    ) throws -> Report {
        let fileManager = FileManager.default
        
        if options.validateTemplateFileExists {
            guard fileManager.fileExists(atPath: templateURL.path) else {
                throw DocxProcessingError.fileNotFound(templateURL)
            }
        }
        
        let preparedValues = options.sanitizeValues ? sanitize(values) : values
        let sourceArchive = try DocxArchive.openForRead(templateURL)
        
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("fillthedoc-\(UUID().uuidString)", isDirectory: true)
        
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDirectory)
        }
        
        try DocxArchive.extractAllSafely(from: sourceArchive, to: tempDirectory)
        
        let partURLs = try DocxArchive.locatePartURLs(root: tempDirectory, options: options.core)
        var report = Report()
        
        for partURL in partURLs {
            let partPath = DocxArchive.relativePath(of: partURL, under: tempDirectory)
            
            do {
                let partResult = try processPart(
                    at: partURL,
                    partPath: partPath,
                    values: preparedValues,
                    options: options
                )
                
                if partResult.didChange {
                    report.processedParts.append(partPath)
                }
                
                report.foundKeys.formUnion(partResult.report.foundKeys)
                report.replacedKeys.formUnion(partResult.report.replacedKeys)
                report.missingKeys.formUnion(partResult.report.missingKeys)
                report.replacementsCount += partResult.report.replacementsCount
            } catch {
                options.onWarning?("Failed to process \(partPath): \(error.localizedDescription)")
            }
        }
        
        if options.missingKeyPolicy == .error, !report.missingKeys.isEmpty {
            throw DocxProcessingError.missingReplacementValues(report.missingKeys.sorted())
        }
        
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }
        
        let outputArchive = try DocxArchive.openForCreate(outputURL)
        try DocxArchive.addDirectoryContents(from: tempDirectory, to: outputArchive)
        
        return report
    }
}

private extension DocxPlaceholderReplacer {
    struct PartProcessingResult {
        let report: PartReport
        let didChange: Bool
    }
    
    struct PartReport {
        var foundKeys: Set<String> = []
        var replacedKeys: Set<String> = []
        var missingKeys: Set<String> = []
        var replacementsCount: Int = 0
    }
    
    func sanitize(_ values: [String: String]) -> [String: String] {
        values.mapValues { value in
            value
                .replacingOccurrences(of: "<!", with: "&lt;!")
                .replacingOccurrences(of: "!>", with: "!&gt;")
        }
    }
    
    func processPart(
        at url: URL,
        partPath: String,
        values: [String: String],
        options: Options
    ) throws -> PartProcessingResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DocxProcessingError.failedToReadXML(part: partPath)
        }
        
        let document = try DocxXML.parseDocument(data: data, partPath: partPath)
        let result = rewriteDocument(document, values: values, options: options)
        
        if result.didChange {
            var outData = document.xmlData(options: [.nodePreserveAll])
            outData = DocxXML.restoreSelfClosingPreserveTextNodes(outData)
            
            do {
                try outData.write(to: url, options: [.atomic])
            } catch {
                throw DocxProcessingError.failedToWriteXML(part: partPath)
            }
        }
        
        return result
    }
    
    func rewriteDocument(
        _ document: XMLDocument,
        values: [String: String],
        options: Options
    ) -> PartProcessingResult {
        var report = PartReport()
        var didChange = false
        
        for paragraph in DocxXML.findParagraphs(in: document) {
            let result = rewriteParagraph(
                paragraph,
                values: values,
                options: options
            )
            
            report.foundKeys.formUnion(result.report.foundKeys)
            report.replacedKeys.formUnion(result.report.replacedKeys)
            report.missingKeys.formUnion(result.report.missingKeys)
            report.replacementsCount += result.report.replacementsCount
            
            if result.didChange {
                didChange = true
            }
        }
        
        return PartProcessingResult(report: report, didChange: didChange)
    }
    
    func rewriteParagraph(
        _ paragraph: XMLElement,
        values: [String: String],
        options: Options
    ) -> PartProcessingResult {
        let projection = ParagraphProjection.build(
            from: paragraph,
            includeFieldInstructionText: options.includeFieldInstructionText
        )
        
        guard !projection.nodes.isEmpty else {
            return .init(report: PartReport(), didChange: false)
        }
        
        let matches = DocxPlaceholderParser.findMatches(in: projection.fullText)
        guard !matches.isEmpty else {
            return .init(report: PartReport(), didChange: false)
        }
        
        var nodes = projection.nodes
        let lengths = nodes.map(\.text.count)
        let prefixSums = TextOffsetMapper.prefixSums(for: lengths)
        
        var report = PartReport()
        var didChange = false
        
        for match in matches.reversed() {
            report.foundKeys.insert(match.key)
            
            let replacement: String?
            if let value = values[match.key] {
                replacement = value
                report.replacedKeys.insert(match.key)
            } else {
                report.missingKeys.insert(match.key)
                
                switch options.missingKeyPolicy {
                    case .error, .keep:
                        replacement = nil
                    case .blank:
                        replacement = ""
                }
            }
            
            guard let replacement else { continue }
            
            guard
                let start = TextOffsetMapper.locateStart(
                    position: match.range.lowerBound,
                    in: projection.fullText,
                    prefixSums: prefixSums
                ),
                let end = TextOffsetMapper.locateEnd(
                    position: match.range.upperBound,
                    in: projection.fullText,
                    prefixSums: prefixSums
                )
            else {
                continue
            }
            
            applyReplacement(
                to: &nodes,
                start: start,
                end: end,
                replacement: replacement
            )
            
            report.replacementsCount += 1
            didChange = true
        }
        
        if didChange {
            normalizeStandaloneWhitespaceNodes(in: &nodes)
            commit(nodes: nodes, in: paragraph)
        }
        
        return .init(report: report, didChange: didChange)
    }
    
    func nearestNonEmptyTextNodeIndex(
        in nodes: [EditableTextNode],
        startingAt startIndex: Int,
        step: Int
    ) -> Int? {
        guard step == -1 || step == 1 else { return nil }
        guard !nodes.isEmpty else { return nil }
        
        var index = startIndex
        
        while index >= 0 && index < nodes.count {
            let node = nodes[index]
            if node.kind == .text, !node.text.isEmpty {
                return index
            }
            index += step
        }
        
        return nil
    }
    
    func normalizeStandaloneWhitespaceNodes(in nodes: inout [EditableTextNode]) {
        guard !nodes.isEmpty else { return }
        
        for index in nodes.indices {
            guard nodes[index].kind == .text else { continue }
            let text = nodes[index].text
            guard DocxXML.isBoundaryWhitespaceCandidate(text) else { continue }
            
            let leftIndex = nearestNonEmptyTextNodeIndex(
                in: nodes,
                startingAt: index - 1,
                step: -1
            )
            
            let rightIndex = nearestNonEmptyTextNodeIndex(
                in: nodes,
                startingAt: index + 1,
                step: 1
            )
            
            if let rightIndex {
                // Самый надежный вариант — приклеивать пробел к следующему тексту как leading space.
                nodes[rightIndex].text = text + nodes[rightIndex].text
                nodes[rightIndex].isDirty = true
                nodes[index].text = ""
                nodes[index].isDirty = true
                continue
            }
            
            if let leftIndex {
                nodes[leftIndex].text += text
                nodes[leftIndex].isDirty = true
                nodes[index].text = ""
                nodes[index].isDirty = true
            }
        }
    }
    
    func applyReplacement(
        to nodes: inout [EditableTextNode],
        start: TextLocation,
        end: TextLocation,
        replacement: String
    ) {
        if start.nodeIndex == end.nodeIndex {
            let original = nodes[start.nodeIndex].text
            let prefix = original.prefixCharacters(start.offset)
            let suffix = original.suffixCharacters(from: end.offset)
            
            nodes[start.nodeIndex].text = prefix + replacement + suffix
            nodes[start.nodeIndex].isDirty = true
            nodes[start.nodeIndex].shouldNormalizeRunBackground = true
            return
        }
        
        let startOriginal = nodes[start.nodeIndex].text
        let endOriginal = nodes[end.nodeIndex].text
        
        let startPrefix = startOriginal.prefixCharacters(start.offset)
        let endSuffix = endOriginal.suffixCharacters(from: end.offset)
        
        nodes[start.nodeIndex].text = startPrefix + replacement
        nodes[start.nodeIndex].isDirty = true
        nodes[start.nodeIndex].shouldNormalizeRunBackground = true
        
        for index in (start.nodeIndex + 1)..<end.nodeIndex {
            nodes[index].text = ""
            nodes[index].isDirty = true
        }
        
        nodes[end.nodeIndex].text = endSuffix
        nodes[end.nodeIndex].isDirty = true
    }
    
    
    func commit(nodes: [EditableTextNode], in paragraph: XMLElement) {
        for node in nodes where node.isDirty {
            DocxXML.setExactText(node.text, on: node.element)
            
            if node.kind == .text {
                if DocxXML.needsXMLSpacePreserve(for: node.text) {
                    DocxXML.ensureXMLSpacePreserve(on: node.element)
                } else {
                    DocxXML.removeXMLSpacePreserve(on: node.element)
                }
            }
            
            if node.shouldNormalizeRunBackground,
               let run = DocxXML.parentRun(of: node.element),
               !node.text.isEmpty {
                DocxXML.removeHighlightAndBackground(from: run)
            }
        }
        
        DocxXML.removeEmptyRuns(in: paragraph)
    }
}
