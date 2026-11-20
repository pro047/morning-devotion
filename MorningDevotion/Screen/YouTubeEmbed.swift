//
//  YouTubeEmbed.swift
//  MorningDevotion
//

import Foundation

nonisolated enum YouTubeEmbed {
    /// baseURL for WKWebView.loadHTMLString (the site that already embeds these videos).
    static let baseURL = URL(string: "https://100church.org")!

    static func embedURLString(videoID: String) -> String {
        "https://www.youtube.com/embed/\(videoID)?playsinline=1"
    }

    static func html(videoID: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>html,body{margin:0;height:100%;background:#000}iframe{border:0;width:100%;height:100%}</style>
        </head>
        <body>
        <iframe src="\(embedURLString(videoID: videoID))" allow="encrypted-media; picture-in-picture" allowfullscreen></iframe>
        </body>
        </html>
        """
    }
}
