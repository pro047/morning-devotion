//
//  DevotionListParser.swift
//  MorningDevotion
//

import Foundation

nonisolated struct DevotionListLink: Equatable, Sendable {
    let title: String
    let articleNo: Int?
}

nonisolated enum DevotionListParser {
    private static let titlePattern = try! NSRegularExpression(
        pattern: #"class=["']?subjectColor["']?[^>]*>([^<]*)"#
    )

    private static let noPattern = try! NSRegularExpression(pattern: #"(?<=[?&;])no=(\d+)"#)

    /// One element per subjectColor match, document order.
    static func extractLinks(fromHTML html: String) -> [DevotionListLink] {
        let ns = html as NSString
        let matches = titlePattern.matches(in: html, range: NSRange(location: 0, length: ns.length))
        return matches.map { m in
            let titleRange = m.range(at: 1)
            let title = decodeEntities(ns.substring(with: titleRange))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Opening tag = nearest "<" before the match, up to the ">" before the title.
            let lt = ns.range(of: "<", options: .backwards, range: NSRange(location: 0, length: m.range.location))
            let tagStart = lt.location == NSNotFound ? 0 : lt.location
            let tag = ns.substring(with: NSRange(location: tagStart, length: titleRange.location - tagStart))

            let tagNS = tag as NSString
            var articleNo: Int?
            if let nm = noPattern.firstMatch(in: tag, range: NSRange(location: 0, length: tagNS.length)) {
                articleNo = Int(tagNS.substring(with: nm.range(at: 1)))
            }
            return DevotionListLink(title: title, articleNo: articleNo)
        }
    }

    static func extractTitles(fromHTML html: String) -> [String] {
        extractLinks(fromHTML: html).map(\.title)
    }

    static func parseEntries(fromHTML html: String) -> [DevotionEntry] {
        extractLinks(fromHTML: html).compactMap { link in
            guard var entry = DevotionTitleParser.parse(link.title) else { return nil }
            entry.articleNo = link.articleNo
            return entry
        }
    }

    private static let named: [String: String] = [
        "nbsp": "\u{00A0}", "amp": "&", "quot": "\"", "lt": "<", "gt": ">",
    ]

    /// Single pass, so "&amp;#58;" decodes to "&#58;" and not further.
    static func decodeEntities(_ s: String) -> String {
        var out = ""
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c == "&", let semi = s[i...].firstIndex(of: ";"),
               s.distance(from: i, to: semi) <= 10,
               let decoded = decodeOne(String(s[s.index(after: i)..<semi])) {
                out += decoded
                i = s.index(after: semi)
            } else {
                out.append(c)
                i = s.index(after: i)
            }
        }
        return out
    }

    private static func decodeOne(_ body: String) -> String? {
        if body.hasPrefix("#") {
            let digits = body.dropFirst()
            let code: UInt32?
            if digits.hasPrefix("x") || digits.hasPrefix("X") {
                code = UInt32(digits.dropFirst(), radix: 16)
            } else {
                code = UInt32(digits, radix: 10)
            }
            guard let code, let scalar = Unicode.Scalar(code) else { return nil }
            return String(Character(scalar))
        }
        return named[body]
    }
}
