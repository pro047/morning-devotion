//
//  ReadingProgressStore.swift
//  MorningDevotion
//

import Foundation

nonisolated final class ReadingProgressStore {
    static let defaultProgress = ReadingProgress(
        lastSeenOld: DevotionDate(year: 2025, month: 9, day: 10),
        lastSeenNew: DevotionDate(year: 2020, month: 7, day: 11)
    )
    static let oldKey = "readingProgress.lastSeenOld"
    static let newKey = "readingProgress.lastSeenNew"
    static let finishedOldKey = "readingProgress.finishedDayOld"
    static let finishedNewKey = "readingProgress.finishedDayNew"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Per key: readable stored value, otherwise the default (which is written back).
    func load() -> ReadingProgress {
        ReadingProgress(
            lastSeenOld: loadValue(key: Self.oldKey, fallback: Self.defaultProgress.lastSeenOld),
            lastSeenNew: loadValue(key: Self.newKey, fallback: Self.defaultProgress.lastSeenNew)
        )
    }

    /// Sets only `testament`'s date and persists it.
    @discardableResult
    func markSeen(_ testament: Testament, date: DevotionDate) -> ReadingProgress {
        switch testament {
        case .oldTestament:
            defaults.set(date.storageString, forKey: Self.oldKey)
        case .newTestament:
            defaults.set(date.storageString, forKey: Self.newKey)
        }
        return load()
    }

    /// Same values `load()` would return, but never writes.
    func storedProgress() -> ReadingProgress {
        ReadingProgress(
            lastSeenOld: readValue(key: Self.oldKey) ?? Self.defaultProgress.lastSeenOld,
            lastSeenNew: readValue(key: Self.newKey) ?? Self.defaultProgress.lastSeenNew
        )
    }

    /// Last "다 봤어요" day for `testament`; nil when absent or unreadable. Never writes.
    func finishedDay(for testament: Testament) -> DevotionDate? {
        readValue(key: finishedKey(for: testament))
    }

    func markFinished(_ testament: Testament, on day: DevotionDate) {
        defaults.set(day.storageString, forKey: finishedKey(for: testament))
    }

    private func finishedKey(for testament: Testament) -> String {
        switch testament {
        case .oldTestament: return Self.finishedOldKey
        case .newTestament: return Self.finishedNewKey
        }
    }

    private func readValue(key: String) -> DevotionDate? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return DevotionDate(storageString: raw)
    }

    private func loadValue(key: String, fallback: DevotionDate) -> DevotionDate {
        if let raw = defaults.string(forKey: key), let stored = DevotionDate(storageString: raw) {
            return stored
        }
        defaults.set(fallback.storageString, forKey: key)
        return fallback
    }
}
