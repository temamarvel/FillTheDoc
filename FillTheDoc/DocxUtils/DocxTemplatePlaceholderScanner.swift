import Foundation
import ZIPFoundation

public final class DocxTemplatePlaceholderScanner: Sendable {
    
    public struct Options: Sendable {
        public enum PartsSelection: Sendable {
            case standard
            case allWordXML
        }
        
        public var includeFootnotes: Bool = true
        public var includeEndnotes: Bool = true
        public var includeComments: Bool = true
        public var includeFieldInstructionText: Bool = false
        public var selection: PartsSelection = .standard
        public var validateTemplateFileExists: Bool = true
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
        public var orderedKeys: [String] = []
        public var foundKeys: Set<String> = []
        public var occurrences: [String: Int] = [:]
        public var partsByKey: [String: Set<String>] = [:]
        
        public init() {}
        
        public var sortedKeys: [String] {
            foundKeys.sorted()
        }
    }
    
    public init() {}
    
    public func scan(
        templateURL: URL,
        options: Options = .init()
    ) throws -> Report {
        let fileManager = FileManager.default
        
        if options.validateTemplateFileExists {
            guard fileManager.fileExists(atPath: templateURL.path) else {
                throw DocxProcessingError.fileNotFound(templateURL)
            }
        }
        
        let archive = try DocxArchive.openForRead(templateURL)
        let partPaths = DocxArchive.locatePartPaths(in: archive, options: options.core)
        
        guard partPaths.contains("word/document.xml") else {
            throw DocxProcessingError.missingMainDocumentXML
        }
        
        var report = Report()
        
        for partPath in partPaths {
            guard let entry = archive[partPath] else { continue }
            
            do {
                let data = try DocxArchive.extractEntryData(from: entry, in: archive)
                let document = try DocxXML.parseDocument(data: data, partPath: partPath)
                let partReport = scanPart(document, options: options)
                
                if !partReport.keysInOrder.isEmpty {
                    report.processedParts.append(partPath)
                }
                
                merge(partReport, from: partPath, into: &report)
            } catch {
                options.onWarning?("Failed to scan \(partPath): \(error.localizedDescription)")
            }
        }
        
        return report
    }
    
    public func scanKeys(
        templateURL: URL,
        options: Options = .init()
    ) throws -> [String] {
        try scan(templateURL: templateURL, options: options).orderedKeys
    }
}

private extension DocxTemplatePlaceholderScanner {
    struct PartReport {
        var keysInOrder: [String] = []
        var uniqueKeys: Set<String> = []
        var occurrences: [String: Int] = [:]
    }
    
    func scanPart(
        _ document: XMLDocument,
        options: Options
    ) -> PartReport {
        var report = PartReport()
        
        for paragraph in DocxXML.findParagraphs(in: document) {
            let projection = ParagraphProjection.build(
                from: paragraph,
                includeFieldInstructionText: options.includeFieldInstructionText
            )
            
            guard !projection.fullText.isEmpty else { continue }
            
            let matches = DocxPlaceholderParser.findMatches(in: projection.fullText)
            
            for match in matches {
                if report.uniqueKeys.insert(match.key).inserted {
                    report.keysInOrder.append(match.key)
                }
                report.occurrences[match.key, default: 0] += 1
            }
        }
        
        return report
    }
    
    func merge(
        _ partReport: PartReport,
        from partPath: String,
        into report: inout Report
    ) {
        for key in partReport.keysInOrder {
            if report.foundKeys.insert(key).inserted {
                report.orderedKeys.append(key)
            }
            report.partsByKey[key, default: []].insert(partPath)
        }
        
        for (key, count) in partReport.occurrences {
            report.occurrences[key, default: 0] += count
        }
    }
}
