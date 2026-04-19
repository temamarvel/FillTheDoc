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
    
    struct ResolvedReplacement {
        let text: String
        let styleDonorRun: XMLElement?
        let start: TextLocation
        let end: TextLocation
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
            
            // Критично: FoundationXML при сериализации теряет whitespace-only
            // <w:t xml:space="preserve"> </w:t> и делает self-closing узлы.
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
            
            let replacementText: String?
            if let value = values[match.key] {
                replacementText = value
                report.replacedKeys.insert(match.key)
            } else {
                report.missingKeys.insert(match.key)
                
                switch options.missingKeyPolicy {
                    case .error, .keep:
                        replacementText = nil
                    case .blank:
                        replacementText = ""
                }
            }
            
            guard let replacementText else { continue }
            
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
            
            let donorRun = chooseStyleDonorRun(
                in: nodes,
                startNodeIndex: start.nodeIndex,
                endNodeIndex: end.nodeIndex
            )
            
            let resolved = ResolvedReplacement(
                text: replacementText,
                styleDonorRun: donorRun,
                start: start,
                end: end
            )
            
            applyReplacement(to: &nodes, resolved: resolved)
            
            report.replacementsCount += 1
            didChange = true
        }
        
        if didChange {
            commit(nodes: nodes, in: paragraph)
        }
        
        return .init(report: report, didChange: didChange)
    }
    
    func chooseStyleDonorRun(
        in nodes: [EditableTextNode],
        startNodeIndex: Int,
        endNodeIndex: Int
    ) -> XMLElement? {
        // Сначала смотрим влево на ближайший "живой" текст
        if startNodeIndex > 0 {
            for index in stride(from: startNodeIndex - 1, through: 0, by: -1) {
                let text = nodes[index].text
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                if let run = DocxXML.parentRun(of: nodes[index].element) {
                    return run
                }
            }
        }
        
        // Потом вправо
        if endNodeIndex + 1 < nodes.count {
            for index in (endNodeIndex + 1)..<nodes.count {
                let text = nodes[index].text
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                if let run = DocxXML.parentRun(of: nodes[index].element) {
                    return run
                }
            }
        }
        
        return nil
    }
    
    func applyReplacement(
        to nodes: inout [EditableTextNode],
        resolved: ResolvedReplacement
    ) {
        let start = resolved.start
        let end = resolved.end
        let replacement = resolved.text
        
        if start.nodeIndex == end.nodeIndex {
            let original = nodes[start.nodeIndex].text
            let prefix = original.prefixCharacters(start.offset)
            let suffix = original.suffixCharacters(from: end.offset)
            
            nodes[start.nodeIndex].text = prefix + replacement + suffix
            nodes[start.nodeIndex].isDirty = true
            
            // Если placeholder полностью заменил text node,
            // перетягиваем стиль с соседнего обычного run.
            if prefix.isEmpty, suffix.isEmpty,
               let targetRun = DocxXML.parentRun(of: nodes[start.nodeIndex].element) {
                DocxXML.replaceRunProperties(of: targetRun, from: resolved.styleDonorRun)
            }
            return
        }
        
        let startOriginal = nodes[start.nodeIndex].text
        let endOriginal = nodes[end.nodeIndex].text
        
        let startPrefix = startOriginal.prefixCharacters(start.offset)
        let endSuffix = endOriginal.suffixCharacters(from: end.offset)
        
        let endSuffixIsWhitespaceOnly = endSuffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        // Важный момент:
        // если suffix состоит только из пробела/табов/переводов строки,
        // не оставляем его отдельным text run-ом, потому что FoundationXML
        // потом легко сериализует его в пустой self-closing узел.
        nodes[start.nodeIndex].text = startPrefix + replacement + (endSuffixIsWhitespaceOnly ? endSuffix : "")
        nodes[start.nodeIndex].isDirty = true
        
        // Стилизация replacement run-а:
        // применяем донорский rPr только если start node не содержит живого текста слева.
        if startPrefix.isEmpty,
           let targetRun = DocxXML.parentRun(of: nodes[start.nodeIndex].element) {
            DocxXML.replaceRunProperties(of: targetRun, from: resolved.styleDonorRun)
        }
        
        for index in (start.nodeIndex + 1)..<end.nodeIndex {
            nodes[index].text = ""
            nodes[index].isDirty = true
        }
        
        nodes[end.nodeIndex].text = endSuffixIsWhitespaceOnly ? "" : endSuffix
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
        }
        
        DocxXML.removeEmptyRuns(in: paragraph)
    }
}
