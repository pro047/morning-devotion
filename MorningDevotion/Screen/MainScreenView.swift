//
//  MainScreenView.swift
//  MorningDevotion
//

import SwiftUI

struct MainScreenView: View {
    let model: MainScreenModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var screen: DevotionScreenModel?

    var body: some View {
        TimelineView(.everyMinute) { _ in
            ScrollView {
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 16) {
                        row(.oldTestament)
                        row(.newTestament)
                    }
                }
                .padding()
            }
        }
        .background(Theme.mainBackground.ignoresSafeArea())
        .navigationTitle("묵상")
        .task { await model.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refreshOnReturn() }
            }
        }
        .onChange(of: screen == nil) { _, closed in
            if closed {
                Task { await model.refreshOnReturn() }
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { screen != nil },
            set: { if !$0 { screen = nil } }
        )) {
            if let screen {
                DevotionScreenView(model: screen)
            }
        }
    }

    @ViewBuilder
    private func row(_ testament: Testament) -> some View {
        let state = model.row(for: testament)
        let arrows = MainRowRules.arrows(for: state)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(testament.displayName).font(.headline)
                if model.isNow(testament) {
                    BadgeLabel(text: "지금", tint: .orange)
                }
                Spacer()
                if case .ready(let c) = state, c.isRead {
                    BadgeLabel(text: "읽음", tint: .green)
                }
            }
            switch state {
            case .loading:
                ProgressView()
            case .ready(let c):
                navRow(testament, arrows: arrows) {
                    Text(c.title)
                        .font(Theme.passageFont)
                        .multilineTextAlignment(.center)
                }
                .id(c.entry.date)
                .transition(.push(from: pushEdge(testament)))
                movingAndNotice(testament)
            case .networkError:
                Text(state.message ?? "")
                Button("다시 시도") { Task { await model.retry(testament) } }
            case .noNextDevotion:
                navRow(testament, arrows: arrows) {
                    Text(state.message ?? "")
                }
                movingAndNotice(testament)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
        .contentShape(Rectangle())
        .onTapGesture {
            if case .ready = state {
                screen = model.makeScreenModel(for: testament)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20).onEnded { v in
                let direction = SwipeRules.direction(
                    dx: v.translation.width,
                    dy: v.translation.height,
                    startX: v.startLocation.x,
                    excludesLeadingEdge: false
                )
                if let direction {
                    Task { await model.navigate(testament, direction) }
                }
            }
        )
        .animation(.snappy, value: state)
        .sensoryFeedback(trigger: model.feedback(for: testament)) { _, new in
            guard let new else { return nil }
            return new.succeeded ? .impact(weight: .light) : .warning
        }
    }

    /// Arrow / content / arrow line; arrows the row does not offer are left out.
    private func navRow<Content: View>(
        _ testament: Testament,
        arrows: NavArrows,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            if arrows.allows(.previous) {
                GlassArrowButton(direction: .previous) {
                    Task { await model.navigate(testament, .previous) }
                }
                .disabled(model.isMoving(testament))
            }
            content().frame(maxWidth: .infinity)
            if arrows.allows(.next) {
                GlassArrowButton(direction: .next) {
                    Task { await model.navigate(testament, .next) }
                }
                .disabled(model.isMoving(testament))
            }
        }
    }

    @ViewBuilder
    private func movingAndNotice(_ testament: Testament) -> some View {
        if model.isMoving(testament) {
            ProgressView().controlSize(.small)
        }
        if let notice = model.notice(for: testament) {
            Text(notice)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func pushEdge(_ testament: Testament) -> Edge {
        model.feedback(for: testament)?.direction == .previous ? .leading : .trailing
    }
}
