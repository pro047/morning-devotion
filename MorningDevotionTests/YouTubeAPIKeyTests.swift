//
//  YouTubeAPIKeyTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

@MainActor
struct YouTubeAPIKeyTests {

    // MARK: - AC-11 key reading

    // AC-11: Info key name
    @Test func ac11_infoKeyName() {
        #expect(YouTubeAPIKey.infoKey == "YouTubeAPIKey")
    }

    // AC-11: a non-empty string value is returned as is
    @Test func ac11_readsStringValue() {
        #expect(YouTubeAPIKey.read(from: ["YouTubeAPIKey": "test-key"]) == "test-key")
    }

    // AC-11: empty string / missing key / nil dictionary / non-string value → nil
    @Test func ac11_missingOrEmptyIsNil() {
        #expect(YouTubeAPIKey.read(from: ["YouTubeAPIKey": ""]) == nil)
        #expect(YouTubeAPIKey.read(from: [:]) == nil)
        #expect(YouTubeAPIKey.read(from: nil) == nil)
        #expect(YouTubeAPIKey.read(from: ["YouTubeAPIKey": 42]) == nil)
    }

    // AC-11 boundary: other keys are ignored (only infoKey is read)
    @Test func ac11_otherKeysIgnored() {
        #expect(YouTubeAPIKey.read(from: ["YOUTUBE_API_KEY": "x", "CFBundleName": "MorningDevotion"]) == nil)
        #expect(YouTubeAPIKey.read(from: ["YouTubeAPIKey": "abc", "Other": "zzz"]) == "abc")
    }

    // MARK: - AC-23 embed

    // AC-23: embed URL string
    @Test func ac23_embedURLString() {
        #expect(YouTubeEmbed.embedURLString(videoID: "PR9GK_S83NU") == "https://www.youtube.com/embed/PR9GK_S83NU?playsinline=1")
        #expect(YouTubeEmbed.embedURLString(videoID: "-rD7ZDYCysw") == "https://www.youtube.com/embed/-rD7ZDYCysw?playsinline=1")
    }

    // AC-23: html contains exactly one iframe pointing at the embed URL
    @Test func ac23_htmlContainsIframe() {
        let html = YouTubeEmbed.html(videoID: "PR9GK_S83NU")
        #expect(html.contains("https://www.youtube.com/embed/PR9GK_S83NU?playsinline=1"))
        #expect(html.contains("<iframe"))
        #expect(html.components(separatedBy: "<iframe").count == 2)
        #expect(html.contains("allowfullscreen"))
        #expect(html.contains("viewport"))
    }

    // AC-23 boundary: html is per video (does not leak another id)
    @Test func ac23_htmlIsPerVideo() {
        let html = YouTubeEmbed.html(videoID: "M5VtIg1WAic")
        #expect(html.contains("https://www.youtube.com/embed/M5VtIg1WAic?playsinline=1"))
        #expect(!html.contains("PR9GK_S83NU"))
    }

    // AC-23: baseURL is the church site
    @Test func ac23_baseURL() {
        #expect(YouTubeEmbed.baseURL.absoluteString == "https://100church.org")
    }
}
