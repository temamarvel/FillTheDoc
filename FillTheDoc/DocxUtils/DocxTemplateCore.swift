//
//  DocxTemplateCore.swift
//  FillTheDoc
//

import Foundation
import ZIPFoundation

// MARK: - Placeholder regex

enum PlaceholderPattern {
    /// Matches `<!key!>` where key = [A-Za-z0-9_]+
    static let regex: NSRegularExpression = {
        let pattern = #"<\!([A-Za-z0-9_]+)\!>"#
        return try! NSRegularExpression(pattern: pattern)
    }()
}

// MARK: - Shared data types

struct PlaceholderMatch {
    let key: String
    let range: Range<String.Index>
}

// MARK: - Shared DOCX parts options

struct DocxPartsOptions {
    var includeFootnotes: Bool = true
    var includeEndnotes: Bool = true
    var includeComments: Bool = true
    var includeFieldInstructionText: Bool = false
    var selection: PartsSelection = .standard
    
    enum PartsSelection {
        case standard
        case allWordXML
    }
}

// MARK: - Shared errors

enum DocxTemplateError: Error, LocalizedError {
    case invalidDocx
    case missingMainDocumentXML
    case templateNotFound(URL)
    case xmlReadFailed(part: String)
    case xmlWriteFailed(part: String)
    case zipSlipDetected(entryPath: String)
    
    var errorDescription: String? {
        switch self {
            case .invalidDocx:
                return "Invalid DOCX archive."
            case .missingMainDocumentXML:
                return "DOCX does not contain word/document.xml."
            case .templateNotFound(let url):
                return "Template file not found at: \(url.path)"
            case .xmlReadFailed(let part):
                return "Failed to read XML part: \(part)"
            case .xmlWriteFailed(let part):
                return "Failed to write XML part: \(part)"
            case .zipSlipDetected(let entryPath):
                return "Unsafe ZIP entry path detected: \(entryPath)"
        }
    }
}

// MARK: - Placeholder search

func findPlaceholders(in text: String) -> [PlaceholderMatch] {
    let ns = text as NSString
    let matches = PlaceholderPattern.regex.matches(
        in: text,
        range: NSRange(location: 0, length: ns.length)
    )
    
    return matches.compactMap { match in
        guard match.numberOfRanges == 2 else { return nil }
        let key = ns.substring(with: match.range(at: 1))
        guard let range = Range(match.range(at: 0), in: text) else { return nil }
        return PlaceholderMatch(key: key, range: range)
    }
}

// MARK: - XML parsing

func parseXMLDocument(data: Data, partPath: String) throws -> XMLDocument {
    do {
        return try XMLDocument(
            data: data,
            options: [.nodePreserveAll, .nodePreserveWhitespace]
        )
    } catch {
        throw DocxTemplateError.xmlReadFailed(part: partPath)
    }
}

func findParagraphs(in document: XMLDocument) -> [XMLElement] {
    (try? document.nodes(forXPath: "//*[local-name()='p']") as? [XMLElement]) ?? []
}

// MARK: - Part location (from archive paths)

func locatePartPaths(in archive: Archive, options: DocxPartsOptions) -> [String] {
    let allPaths = archive.map(\.path)
    
    switch options.selection {
        case .standard:
            var result: [String] = []
            
            if allPaths.contains("word/document.xml") {
                result.append("word/document.xml")
            }
            
            result += allPaths
                .filter { path in
                    let name = (path as NSString).lastPathComponent
                    return path.hasPrefix("word/") && path.hasSuffix(".xml") && name.hasPrefix("header")
                }
                .sorted()
            
            result += allPaths
                .filter { path in
                    let name = (path as NSString).lastPathComponent
                    return path.hasPrefix("word/") && path.hasSuffix(".xml") && name.hasPrefix("footer")
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

// MARK: - Part location (from extracted folder URLs)

func locatePartURLs(
    root: URL,
    mainDoc: URL,
    options: DocxPartsOptions
) throws -> [URL] {
    let fm = FileManager.default
    
    switch options.selection {
        case .standard:
            var urls: [URL] = [mainDoc]
            
            let wordDir = root.appendingPathComponent("word", isDirectory: true)
            let contents = try fm.contentsOfDirectory(
                at: wordDir,
                includingPropertiesForKeys: nil
            )
            
            urls += contents
                .filter {
                    $0.lastPathComponent.hasPrefix("header")
                    && $0.pathExtension.lowercased() == "xml"
                }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            urls += contents
                .filter {
                    $0.lastPathComponent.hasPrefix("footer")
                    && $0.pathExtension.lowercased() == "xml"
                }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            if options.includeFootnotes {
                let footnotes = wordDir.appendingPathComponent("footnotes.xml")
                if fm.fileExists(atPath: footnotes.path) {
                    urls.append(footnotes)
                }
            }
            
            if options.includeEndnotes {
                let endnotes = wordDir.appendingPathComponent("endnotes.xml")
                if fm.fileExists(atPath: endnotes.path) {
                    urls.append(endnotes)
                }
            }
            
            if options.includeComments {
                let comments = wordDir.appendingPathComponent("comments.xml")
                if fm.fileExists(atPath: comments.path) {
                    urls.append(comments)
                }
            }
            
            return urls
            
        case .allWordXML:
            let wordDir = root.appendingPathComponent("word", isDirectory: true)
            let enumerator = fm.enumerator(
                at: wordDir,
                includingPropertiesForKeys: nil
            )
            
            var urls: [URL] = []
            
            while let fileURL = enumerator?.nextObject() as? URL {
                guard fileURL.pathExtension.lowercased() == "xml" else { continue }
                guard !fileURL.lastPathComponent.hasSuffix(".rels") else { continue }
                urls.append(fileURL)
            }
            
            return urls.sorted { relativeDocxPath(fromExtractedURL: $0, extractedRoot: root) < relativeDocxPath(fromExtractedURL: $1, extractedRoot: root) }
    }
}

func relativeDocxPath(fromExtractedURL url: URL, extractedRoot: URL) -> String {
    var path = url.path
    let rootPath = extractedRoot.path
    
    if path.hasPrefix(rootPath + "/") {
        path.removeFirst(rootPath.count + 1)
    }
    
    return path
}

// MARK: - ZIP extraction helpers

func extractEntryData(from entry: Entry, in archive: Archive) throws -> Data {
    var data = Data()
    _ = try archive.extract(entry) { chunk in
        data.append(chunk)
    }
    return data
}

extension Archive {
    func extractAllSafely(to destinationURL: URL) throws {
        let fm = FileManager.default
        let basePath = destinationURL.standardizedFileURL.path
        
        for entry in self {
            let entryPath = entry.path
            
            if entryPath.contains("..") || entryPath.hasPrefix("/") || entryPath.hasPrefix("\\") {
                throw DocxTemplateError.zipSlipDetected(entryPath: entryPath)
            }
            
            let outputURL = destinationURL.appendingPathComponent(entryPath)
            let standardizedOutputPath = outputURL.standardizedFileURL.path
            
            guard standardizedOutputPath == basePath || standardizedOutputPath.hasPrefix(basePath + "/") else {
                throw DocxTemplateError.zipSlipDetected(entryPath: entryPath)
            }
            
            let parentDirectory = outputURL.deletingLastPathComponent()
            try fm.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            
            switch entry.type {
                case .directory:
                    try fm.createDirectory(at: outputURL, withIntermediateDirectories: true)
                    
                default:
                    _ = try self.extract(entry, to: outputURL)
            }
        }
    }
    
    func addDirectoryContents(of directoryURL: URL) throws {
        let fm = FileManager.default
        let basePath = directoryURL.standardizedFileURL.path
        
        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true { continue }
            
            var relPath = fileURL.standardizedFileURL.path
            if relPath.hasPrefix(basePath + "/") {
                relPath.removeFirst(basePath.count + 1)
            }
            
            try self.addEntry(
                with: relPath,
                fileURL: fileURL,
                compressionMethod: .deflate
            )
        }
    }
}
