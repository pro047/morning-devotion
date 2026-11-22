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
            .safeAreaInset(edge: .bottom) { navigationCapsule }
            .sensoryFeedback(trigger: model.feedback) { _, new in
                guard let new else { return nil }
                return new.succeeded ? .impact(weight: .light) : .warning
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

    private var navigationCapsule: some View {
        HStack(spacing: 8) {
            capsuleArrow(.previous)
            Group {
                if model.isMoving {
                    ProgressView()
                } else {
                    Circle().fill(.secondary).frame(width: 6, height: 6)
                }
            }
            .frame(width: 24)
            capsuleArrow(.next)
        }
        .padding(.horizontal, 4)
        .glassEffect(.regular.interactive(), in: Capsule())
        .padding(.bottom, 8)
    }

    private func capsuleArrow(_ direction: MoveDirection) -> some View {
        Button {
            Task { await model.move(direction) }
        } label: {
            Image(systemName: direction.symbolName)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(direction.accessibilityLabel)
        .disabled(navigationDisabled)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
        case .showing(let c):
            showing(c)
                .id(c.entry.date)
                .transition(.push(from: model.feedback?.direction == .previous ? .leading : .trailing))
                .animation(.snappy, value: model.entry.date)
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
                textArea(c)
            }
            .padding()
        }
        .background(Theme.paper.ignoresSafeArea())
    }

    /// Passage, hymn, sermon and finish button; the swipe is only taken here, not over the video.
    private func textArea(_ c: DevotionScreenContent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global).onEnded { v in
                let direction = SwipeRules.direction(
                    dx: v.translation.width,
                    dy: v.translation.height,
                    startX: v.startLocation.x,
                    excludesLeadingEdge: true
                )
                if let direction {
                    Task { await model.move(direction) }
                }
            }
        )
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
