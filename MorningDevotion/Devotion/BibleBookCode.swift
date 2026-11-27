//
//  BibleBookCode.swift
//  MorningDevotion
//

import Foundation

nonisolated enum BibleBookCode {
    /// 66 books in canon order: (Korean name as in devotion titles, bskorea book code).
    /// Only gen / pro / jhn are verified against the site; the rest follow its URL convention.
    static let all: [(name: String, code: String)] = [
        // Old Testament (39)
        ("창세기", "gen"), ("출애굽기", "exo"), ("레위기", "lev"), ("민수기", "num"),
        ("신명기", "deu"), ("여호수아", "jos"), ("사사기", "jdg"), ("룻기", "rut"),
        ("사무엘상", "1sa"), ("사무엘하", "2sa"), ("열왕기상", "1ki"), ("열왕기하", "2ki"),
        ("역대상", "1ch"), ("역대하", "2ch"), ("에스라", "ezr"), ("느헤미야", "neh"),
        ("에스더", "est"), ("욥기", "job"), ("시편", "psa"), ("잠언", "pro"),
        ("전도서", "ecc"), ("아가", "sng"), ("이사야", "isa"), ("예레미야", "jer"),
        ("예레미야애가", "lam"), ("에스겔", "ezk"), ("다니엘", "dan"), ("호세아", "hos"),
        ("요엘", "jol"), ("아모스", "amo"), ("오바댜", "oba"), ("요나", "jnh"),
        ("미가", "mic"), ("나훔", "nam"), ("하박국", "hab"), ("스바냐", "zep"),
        ("학개", "hag"), ("스가랴", "zec"), ("말라기", "mal"),
        // New Testament (27)
        ("마태복음", "mat"), ("마가복음", "mrk"), ("누가복음", "luk"), ("요한복음", "jhn"),
        ("사도행전", "act"), ("로마서", "rom"), ("고린도전서", "1co"), ("고린도후서", "2co"),
        ("갈라디아서", "gal"), ("에베소서", "eph"), ("빌립보서", "php"), ("골로새서", "col"),
        ("데살로니가전서", "1th"), ("데살로니가후서", "2th"), ("디모데전서", "1ti"),
        ("디모데후서", "2ti"), ("디도서", "tit"), ("빌레몬서", "phm"), ("히브리서", "heb"),
        ("야고보서", "jas"), ("베드로전서", "1pe"), ("베드로후서", "2pe"), ("요한일서", "1jn"),
        ("요한이서", "2jn"), ("요한삼서", "3jn"), ("유다서", "jud"), ("요한계시록", "rev"),
    ]

    /// Exact name match after trimming whitespace. Abbreviations ("고린도전") → nil.
    static func code(for book: String) -> String? {
        let name = book.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return all.first { $0.name == name }?.code
    }
}

nonisolated enum BiblePassageURL {
    /// https://www.bskorea.or.kr/bible/korbibReadpage.php?version=GAE&book=<code>&chap=<chapter>
    /// nil when chapter < 1 or code is empty.
    static func url(bookCode: String, chapter: Int) -> URL? {
        guard chapter >= 1, !bookCode.isEmpty else { return nil }
        return URL(string: "https://www.bskorea.or.kr/bible/korbibReadpage.php?version=GAE&book=\(bookCode)&chap=\(chapter)")
    }
}
