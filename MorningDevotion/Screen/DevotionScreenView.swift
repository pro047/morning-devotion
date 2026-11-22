//
//  DevotionScreenView.swift
//  MorningDevotion
//

import SwiftUI

struct DevotionScreenView: View {
    let model: DevotionScreenModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            .task { await model.load() }
            .onChange(of: model.isFinished) { _, finished in
                if finished { dismiss() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await model.refreshIfStale() }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
        case .showing(let c):
            showing(c)
        case .networkError:
            VStack(spacing: 16) {
                Text(model.state.message ?? "")
                Button("다시 시도") { Task { await model.retry() } }
            }
            .padding()
        }
    }

    private func showing(_ c: DevotionScreenContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                videoArea(c.video)
                Text(c.headerDate).font(.headline)
                Text(c.headerPassage).font(.title3)
                if let hymn = c.article.hymn {
                    Text(hymn)
                }
                Text(c.article.sermon)
                if model.showsFinishButton {
                    Button("다 봤어요") { model.markSeen() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func videoArea(_ slot: VideoSlot) -> some View {
        if case .video(let id) = slot {
            YouTubePlayerView(videoID: id)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
        } else if let message = slot.message {
            Text(message).foregroundStyle(.secondary)
        }
    }
}
