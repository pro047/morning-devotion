//
//  BibleChapterParser.swift
//  MorningDevotion
//

import Foundation

nonisolated enum BibleChapterParser {
    /// Verses of one bskorea chapter page, in page order. [] when none are found.
    static func parse(html: String) -> [BibleVerse] {
        // Footnotes must go before splitting: footnote divs would cut verses at "</div".
        // (?s): "." also matches newlines.
        var src = remove(#"(?s)<a[^>]*class=comment[^>]*>.*?</a>"#, from: html)
        src = remove(#"(?s)<div[^>]*class=D2[^>]*>.*?</div>"#, from: src)

        let pieces = src.components(separatedBy: #"<span class="number">"#).dropFirst()
        var verses: [BibleVerse] = []
        for piece in pieces {
            guard let head = piece.range(of: #"^\d+(?:&nbsp;|\s)*</span>"#, options: .regularExpression) else {
                continue
            }
            let digits = piece[head].prefix { $0.isASCII && $0.isNumber }
            guard let number = Int(digits) else { continue }

            var body = String(piece[head.upperBound...])
            let cut = [body.range(of: "<br", options: .caseInsensitive)?.lowerBound,
                       body.range(of: "</div", options: .caseInsensitive)?.lowerBound]
                .compactMap { $0 }
                .min()
            if let cut { body = String(body[..<cut]) }

            let text = clean(body)
            if !text.isEmpty {
                verses.append(BibleVerse(number: number, text: text))
            }
        }
        return verses
    }

    private static func remove(_ pattern: String, from text: String) -> String {
        text.replacingOccurrences(
            of: pattern, with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private static func clean(_ body: String) -> String {
        var s = body.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")   // last, so "&amp;lt;" stays "&lt;"
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        return s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
