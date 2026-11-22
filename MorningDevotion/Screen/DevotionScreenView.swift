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
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("이전") { Task { await model.move(.previous) } }
                        .disabled(navigationDisabled)
                    if model.isMoving {
                        ProgressView()
                    }
                    Button("다음") { Task { await model.move(.next) } }
                        .disabled(navigationDisabled)
                }
            }
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

    private var navigationDisabled: Bool {
        if case .loading = model.state { return true }
        return model.isMoving
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
                noticeText
                Text(model.state.message ?? "")
                Button("다시 시도") { Task { await model.retry() } }
            }
            .padding()
        }
    }

    private func showing(_ c: DevotionScreenContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                noticeText
                videoArea(c.video)
                HStack {
                    Text(c.headerDate)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink.opacity(0.7))
                    if model.isRead {
                        BadgeLabel(text: "읽음", tint: .green)
                    }
                }
                Text(c.headerPassage)
                    .font(Theme.passageFont)
                    .foregroundStyle(Theme.ink)
                if let hymn = c.article.hymn {
                    Text(hymn)
                        .font(.callout)
                        .foregroundStyle(Theme.ink.opacity(0.8))
                }
                Divider()
                Text(c.article.sermon)
                    .font(Theme.sermonFont)
                    .lineSpacing(Theme.sermonLineSpacing)
                    .foregroundStyle(Theme.ink)
                if model.showsFinishButton {
                    Button("다 봤어요") { model.markSeen() }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
        .background(Theme.paper.ignoresSafeArea())
    }

    @ViewBuilder
    private var noticeText: some View {
        if let notice = model.notice {
            Text(notice)
                .font(.footnote)
                .foregroundStyle(.secondary)
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
