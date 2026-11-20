//
//  DevotionArticleParser.swift
//  MorningDevotion
//

import Foundation

nonisolated enum DevotionArticleParser {
    private static let titlePattern = try! NSRegularExpression(
        pattern: #"<title>(.*?)</title>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
    private static let bodyDivPattern = try! NSRegularExpression(
        pattern: #"<div\b[^>]*margin:\s*60px[^>]*>"#, options: [.caseInsensitive])
    private static let divTagPattern = try! NSRegularExpression(
        pattern: #"<div[\s>]|</div\s*>"#, options: [.caseInsensitive])
    private static let passageLabel = try! NSRegularExpression(
        pattern: #"<span[^>]*>\s*본문\s*</span>"#)
    private static let hymnLabel = try! NSRegularExpression(
        pattern: #"<span[^>]*>\s*찬송가\s*</span>"#)
    private static let brPattern = try! NSRegularExpression(
        pattern: #"<br\s*/?>"#, options: [.caseInsensitive])
    private static let tagPattern = try! NSRegularExpression(pattern: #"<[^>]*>"#)

    /// nil when the margin:60px body div or the 본문 label is missing.
    static func parse(html: String) -> DevotionArticle? {
        guard let inner = bodyInner(html) else { return nil }
        let ns = inner as NSString
        let full = NSRange(location: 0, length: ns.length)

        guard let pm = passageLabel.firstMatch(in: inner, range: full) else { return nil }
        let passageEnd = lineEnd(ns, from: NSMaxRange(pm.range))
        let passageText = clean(ns.substring(with: NSRange(location: NSMaxRange(pm.range), length: passageEnd - NSMaxRange(pm.range))))

        var hymn: String?
        var lineAfter = passageEnd
        let hymnSearch = NSRange(location: passageEnd, length: ns.length - passageEnd)
        if let hm = hymnLabel.firstMatch(in: inner, range: hymnSearch) {
            let hymnEnd = lineEnd(ns, from: NSMaxRange(hm.range))
            hymn = clean(ns.substring(with: NSRange(location: NSMaxRange(hm.range), length: hymnEnd - NSMaxRange(hm.range))))
            lineAfter = hymnEnd
        }

        let brSearch = NSRange(location: lineAfter, length: ns.length - lineAfter)
        let start = brPattern.firstMatch(in: inner, range: brSearch).map { NSMaxRange($0.range) } ?? lineAfter
        let sermon = convertSermon(ns.substring(from: start))

        return DevotionArticle(titleEntry: titleEntry(html), passageText: passageText, hymn: hymn, sermon: sermon)
    }

    private static func titleEntry(_ html: String) -> DevotionEntry? {
        let ns = html as NSString
        guard let m = titlePattern.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let raw = DevotionListParser.decodeEntities(ns.substring(with: m.range(at: 1)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return DevotionTitleParser.parse(raw)
    }

    /// Inside of the first margin:60px div, matched by <div>/</div> depth. Unclosed → to end of document.
    private static func bodyInner(_ html: String) -> String? {
        let ns = html as NSString
        guard let open = bodyDivPattern.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let start = NSMaxRange(open.range)
        var depth = 1
        var end = ns.length
        let rest = NSRange(location: start, length: ns.length - start)
        for m in divTagPattern.matches(in: html, range: rest) {
            if ns.substring(with: m.range).hasPrefix("</") {
                depth -= 1
                if depth == 0 { end = m.range.location; break }
            } else {
                depth += 1
            }
        }
        return ns.substring(with: NSRange(location: start, length: end - start))
    }

    /// Index of the next "<" at or after `from`, or end of string.
    private static func lineEnd(_ ns: NSString, from: Int) -> Int {
        let r = ns.range(of: "<", range: NSRange(location: from, length: ns.length - from))
        return r.location == NSNotFound ? ns.length : r.location
    }

    private static func clean(_ s: String) -> String {
        DevotionListParser.decodeEntities(s).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func convertSermon(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "")
        s = replace(brPattern, in: s, with: "\n")
        s = replace(tagPattern, in: s, with: "")
        s = DevotionListParser.decodeEntities(s)
        return s.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replace(_ re: NSRegularExpression, in s: String, with template: String) -> String {
        re.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length),
                                    withTemplate: template)
    }
}
