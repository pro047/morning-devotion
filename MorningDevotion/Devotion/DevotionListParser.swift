//
//  DevotionListParser.swift
//  MorningDevotion
//

import Foundation

nonisolated enum DevotionListParser {
    private static let titlePattern = try! NSRegularExpression(
        pattern: #"class=["']?subjectColor["']?[^>]*>([^<]*)"#
    )

    static func extractTitles(fromHTML html: String) -> [String] {
        let ns = html as NSString
        let matches = titlePattern.matches(in: html, range: NSRange(location: 0, length: ns.length))
        return matches.map { m in
            decodeEntities(ns.substring(with: m.range(at: 1)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func parseEntries(fromHTML html: String) -> [DevotionEntry] {
        extractTitles(fromHTML: html).compactMap(DevotionTitleParser.parse)
    }

    private static let named: [String: String] = [
        "nbsp": "\u{00A0}", "amp": "&", "quot": "\"", "lt": "<", "gt": ">",
    ]

    /// Single pass, so "&amp;#58;" decodes to "&#58;" and not further.
    private static func decodeEntities(_ s: String) -> String {
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
