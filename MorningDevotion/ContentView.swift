import SwiftUI

struct ContentView: View {
    @State private var model = DevotionScreenModel(
        store: ReadingProgressStore(defaults: .standard),
        fetcher: URLSessionHTMLFetcher(),
        searcher: URLSessionYouTubeSearchFetcher(),
        apiKey: YouTubeAPIKey.read(from: Bundle.main.infoDictionary),
        calendar: .current,
        now: { Date() }
    )

    var body: some View {
        DevotionScreenView(model: model)
    }
}
