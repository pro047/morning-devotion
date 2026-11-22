import SwiftUI

struct ContentView: View {
    @State private var model = MainScreenModel(
        store: ReadingProgressStore(defaults: .standard),
        fetcher: URLSessionHTMLFetcher(),
        searcher: URLSessionYouTubeSearchFetcher(),
        apiKey: YouTubeAPIKey.read(from: Bundle.main.infoDictionary),
        calendar: .current,
        now: { Date() }
    )

    var body: some View {
        NavigationStack {
            MainScreenView(model: model)
        }
    }
}
