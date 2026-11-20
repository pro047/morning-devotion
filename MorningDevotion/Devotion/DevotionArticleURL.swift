//
//  DevotionArticleURL.swift
//  MorningDevotion
//

import Foundation

nonisolated enum DevotionArticleURL {
    static func string(articleNo: Int) -> String {
        "https://100church.org/home/board.php?board=cast&config=6&category=6&command=body&no=\(articleNo)&body_only=y&button_view=n"
    }

    static func url(articleNo: Int) -> URL? {
        URL(string: string(articleNo: articleNo))
    }
}
