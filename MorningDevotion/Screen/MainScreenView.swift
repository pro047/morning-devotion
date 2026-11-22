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
                Text(c.title)
                    .font(Theme.passageFont)
                HStack {
                    Button("이전") { Task { await model.move(testament, .previous) } }
                    Button("다음") { Task { await model.move(testament, .next) } }
                    if model.isMoving(testament) {
                        ProgressView().controlSize(.small)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(model.isMoving(testament))
                if let notice = model.notice(for: testament) {
                    Text(notice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .networkError:
                Text(state.message ?? "")
                Button("다시 시도") { Task { await model.retry(testament) } }
            case .noNextDevotion:
                Text(state.message ?? "")
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
    }
}
