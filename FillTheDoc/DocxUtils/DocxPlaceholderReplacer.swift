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
                let result = try processPart(
                    at: partURL,
                    partPath: partPath,
                    values: preparedValues,
                    options: options
                )
                
                if result.didChange {
                    report.processedParts.append(partPath)
                }
                
                report.foundKeys.formUnion(result.report.foundKeys)
                report.replacedKeys.formUnion(result.report.replacedKeys)
                report.missingKeys.formUnion(result.report.missingKeys)
                report.replacementsCount += result.report.replacementsCount
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
    
    struct PlaceholderOccurrence {
        let key: String
        let range: Range<Int>
        let replacement: String
        let placeholderRun: XMLElement?
    }
    
    struct SegmentSourceSpan {
        let tokenIndex: Int
        let localStart: Int
        let localEnd: Int
    }
    
    struct ParagraphSegment {
        enum Kind {
            case preserved
            case replacement
        }
        
        let kind: Kind
        let text: String
        let sourceSpans: [SegmentSourceSpan]
        let styleRun: XMLElement?
        let normalizeBackground: Bool
    }
    
    struct RunBuildPlan {
        let text: String
        let baseRun: XMLElement
        let normalizeBackground: Bool
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
            let result = rewriteParagraph(paragraph, values: values, options: options)
            
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
        let model = ParagraphModel.build(
            from: paragraph,
            includeFieldInstructionText: options.includeFieldInstructionText
        )
        
        guard !model.tokens.isEmpty else {
            return .init(report: PartReport(), didChange: false)
        }
        
        let matches = DocxPlaceholderParser.findMatches(in: model.fullText)
        guard !matches.isEmpty else {
            return .init(report: PartReport(), didChange: false)
        }
        
        var report = PartReport()
        var occurrences: [PlaceholderOccurrence] = []
        
        for match in matches {
            report.foundKeys.insert(match.key)
            
            if let value = values[match.key] {
                report.replacedKeys.insert(match.key)
                report.replacementsCount += 1
                
                let lower = model.fullText.distance(from: model.fullText.startIndex, to: match.range.lowerBound)
                let upper = model.fullText.distance(from: model.fullText.startIndex, to: match.range.upperBound)
                
                let placeholderRun = placeholderStyleRun(
                    for: lower..<upper,
                    in: model
                )
                
                occurrences.append(
                    PlaceholderOccurrence(
                        key: match.key,
                        range: lower..<upper,
                        replacement: value,
                        placeholderRun: placeholderRun
                    )
                )
            } else {
                report.missingKeys.insert(match.key)
                
                switch options.missingKeyPolicy {
                    case .error, .keep:
                        continue
                        
                    case .blank:
                        let lower = model.fullText.distance(from: model.fullText.startIndex, to: match.range.lowerBound)
                        let upper = model.fullText.distance(from: model.fullText.startIndex, to: match.range.upperBound)
                        let placeholderRun = placeholderStyleRun(
                            for: lower..<upper,
                            in: model
                        )
                        
                        occurrences.append(
                            PlaceholderOccurrence(
                                key: match.key,
                                range: lower..<upper,
                                replacement: "",
                                placeholderRun: placeholderRun
                            )
                        )
                        
                        report.replacementsCount += 1
                }
            }
        }
        
        guard !occurrences.isEmpty else {
            return .init(report: report, didChange: false)
        }
        
        let affectedRange = affectedRunRange(for: occurrences, in: model)
        guard let affectedRange else {
            return .init(report: report, didChange: false)
        }
        
        let segments = buildSegments(
            in: model,
            occurrences: occurrences,
            affectedRunRange: affectedRange
        )
        
        let buildPlans = buildRunPlans(from: segments, in: model)
        guard !buildPlans.isEmpty else {
            return .init(report: report, didChange: false)
        }
        
        let newRuns = buildRuns(from: buildPlans)
        replaceRuns(
            in: paragraph,
            model: model,
            affectedRunRange: affectedRange,
            with: newRuns
        )
        
        return .init(report: report, didChange: true)
    }
    
    func placeholderStyleRun(
        for range: Range<Int>,
        in model: ParagraphModel
    ) -> XMLElement? {
        for token in model.tokens {
            guard token.globalEnd > range.lowerBound, token.globalStart < range.upperBound else {
                continue
            }
            
            if let run = token.runElement as XMLElement? {
                return run
            }
        }
        
        return nil
    }
    
    func affectedRunRange(
        for occurrences: [PlaceholderOccurrence],
        in model: ParagraphModel
    ) -> Range<Int>? {
        guard !occurrences.isEmpty else { return nil }
        
        var minRunIndex: Int?
        var maxRunIndex: Int?
        
        for occurrence in occurrences {
            for token in model.tokens {
                guard token.globalEnd > occurrence.range.lowerBound,
                      token.globalStart < occurrence.range.upperBound else {
                    continue
                }
                
                if let runIndex = model.runIndexByID[token.runIdentifier] {
                    if minRunIndex == nil || runIndex < minRunIndex! {
                        minRunIndex = runIndex
                    }
                    if maxRunIndex == nil || runIndex > maxRunIndex! {
                        maxRunIndex = runIndex
                    }
                }
            }
        }
        
        guard var lower = minRunIndex, var upper = maxRunIndex else {
            return nil
        }
        
        // Расширяем влево на standalone whitespace-runs
        while lower > 0, isWhitespaceOnlyRun(model.runElements[lower - 1]) {
            lower -= 1
        }
        
        // Расширяем вправо на standalone whitespace-runs
        while upper + 1 < model.runElements.count, isWhitespaceOnlyRun(model.runElements[upper + 1]) {
            upper += 1
        }
        
        return lower..<(upper + 1)
    }
    
    func buildSegments(
        in model: ParagraphModel,
        occurrences: [PlaceholderOccurrence],
        affectedRunRange: Range<Int>
    ) -> [ParagraphSegment] {
        let affectedTokens = model.tokens.filter { token in
            guard let runIndex = model.runIndexByID[token.runIdentifier] else { return false }
            return affectedRunRange.contains(runIndex)
        }
        
        guard !affectedTokens.isEmpty else { return [] }
        
        let affectedStart = affectedTokens.first!.globalStart
        let affectedEnd = affectedTokens.last!.globalEnd
        
        let relevantOccurrences = occurrences
            .filter { $0.range.lowerBound >= affectedStart && $0.range.upperBound <= affectedEnd }
            .sorted { $0.range.lowerBound < $1.range.lowerBound }
        
        var segments: [ParagraphSegment] = []
        var cursor = affectedStart
        
        for occurrence in relevantOccurrences {
            if cursor < occurrence.range.lowerBound {
                let preservedSegment = makePreservedSegment(
                    in: model,
                    range: cursor..<occurrence.range.lowerBound
                )
                if !preservedSegment.text.isEmpty {
                    segments.append(preservedSegment)
                }
            }
            
            segments.append(
                ParagraphSegment(
                    kind: .replacement,
                    text: occurrence.replacement,
                    sourceSpans: [],
                    styleRun: occurrence.placeholderRun,
                    normalizeBackground: true
                )
            )
            
            cursor = occurrence.range.upperBound
        }
        
        if cursor < affectedEnd {
            let tailSegment = makePreservedSegment(
                in: model,
                range: cursor..<affectedEnd
            )
            if !tailSegment.text.isEmpty {
                segments.append(tailSegment)
            }
        }
        
        return mergeAdjacentPreservedSegments(segments)
    }
    
    func makePreservedSegment(
        in model: ParagraphModel,
        range: Range<Int>
    ) -> ParagraphSegment {
        var text = ""
        var spans: [SegmentSourceSpan] = []
        var styleRun: XMLElement?
        
        for (tokenIndex, token) in model.tokens.enumerated() {
            guard token.globalEnd > range.lowerBound, token.globalStart < range.upperBound else {
                continue
            }
            
            let localStart = max(range.lowerBound, token.globalStart) - token.globalStart
            let localEnd = min(range.upperBound, token.globalEnd) - token.globalStart
            guard localEnd > localStart else { continue }
            
            let piece = token.text.substring(from: localStart, to: localEnd)
            text += piece
            spans.append(
                SegmentSourceSpan(
                    tokenIndex: tokenIndex,
                    localStart: localStart,
                    localEnd: localEnd
                )
            )
            
            if styleRun == nil {
                styleRun = token.runElement
            }
        }
        
        return ParagraphSegment(
            kind: .preserved,
            text: text,
            sourceSpans: spans,
            styleRun: styleRun,
            normalizeBackground: false
        )
    }
    
    func mergeAdjacentPreservedSegments(_ segments: [ParagraphSegment]) -> [ParagraphSegment] {
        guard !segments.isEmpty else { return [] }
        
        var result: [ParagraphSegment] = []
        
        for segment in segments {
            if let last = result.last,
               last.kind == .preserved,
               segment.kind == .preserved,
               last.styleRun === segment.styleRun {
                let merged = ParagraphSegment(
                    kind: .preserved,
                    text: last.text + segment.text,
                    sourceSpans: last.sourceSpans + segment.sourceSpans,
                    styleRun: last.styleRun,
                    normalizeBackground: false
                )
                result[result.count - 1] = merged
            } else {
                result.append(segment)
            }
        }
        
        return result
    }
    
    func buildRunPlans(
        from segments: [ParagraphSegment],
        in model: ParagraphModel
    ) -> [RunBuildPlan] {
        segments.compactMap { segment in
            guard !segment.text.isEmpty else { return nil }
            
            guard let baseRun = resolveBaseRun(for: segment, in: model) else {
                return nil
            }
            
            return RunBuildPlan(
                text: segment.text,
                baseRun: baseRun,
                normalizeBackground: segment.normalizeBackground
            )
        }
    }
    
    func resolveBaseRun(
        for segment: ParagraphSegment,
        in model: ParagraphModel
    ) -> XMLElement? {
        if let styleRun = segment.styleRun {
            return styleRun
        }
        
        switch segment.kind {
            case .replacement:
                return model.runElements.first
                
            case .preserved:
                if let firstSpan = segment.sourceSpans.first {
                    return model.tokens[firstSpan.tokenIndex].runElement
                }
                return model.runElements.first
        }
    }
    
    func buildRuns(from plans: [RunBuildPlan]) -> [XMLElement] {
        plans.compactMap { plan in
            guard let newRun = DocxXML.cloneRunSkeleton(from: plan.baseRun) else {
                return nil
            }
            
            if plan.normalizeBackground {
                DocxXML.removeHighlightAndBackground(from: newRun)
            }
            
            let textElementName = DocxXML.preferredTextElementName(from: plan.baseRun)
            let textElement = DocxXML.makeTextElement(
                localName: textElementName,
                text: plan.text
            )
            
            newRun.addChild(textElement)
            return newRun
        }
    }
    
    func replaceRuns(
        in paragraph: XMLElement,
        model: ParagraphModel,
        affectedRunRange: Range<Int>,
        with newRuns: [XMLElement]
    ) {
        let paragraphChildren = paragraph.children ?? []
        let runSlice = model.runElements[affectedRunRange]
        
        guard let firstRun = runSlice.first,
              let insertionIndex = paragraphChildren.firstIndex(where: { $0 === firstRun }) else {
            return
        }
        
        for run in runSlice.reversed() {
            run.detach()
        }
        
        for (offset, run) in newRuns.enumerated() {
            paragraph.insertChild(run, at: insertionIndex + offset)
        }
    }
    
    func isWhitespaceOnlyRun(_ run: XMLElement) -> Bool {
        let textNodes = (((try? run.nodes(forXPath: "./*[local-name()='t' or local-name()='instrText']")) as? [XMLElement]) ?? [])
        
        guard !textNodes.isEmpty else { return false }
        
        let texts = textNodes.map { DocxXML.exactText(of: $0) }
        let combined = texts.joined()
        
        guard !combined.isEmpty else { return false }
        
        // run считается whitespace-only только если кроме текста там нет специальных inline-элементов
        let nonTextChildren = ((run.children ?? []).compactMap { $0 as? XMLElement }).filter {
            let name = $0.localName ?? $0.name ?? ""
            return name != "rPr" && name != "t" && name != "instrText"
        }
        
        guard nonTextChildren.isEmpty else { return false }
        
        return DocxXML.isWhitespaceOnly(combined)
    }
}
