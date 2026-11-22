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
            VStack(spacing: 16) {
                row(.oldTestament)
                row(.newTestament)
            }
            .padding()
        }
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
                    Text("지금").font(.caption).foregroundStyle(.tint)
                }
                if case .ready(let c) = state, c.isRead {
                    Text("읽음").font(.caption).foregroundStyle(.secondary)
                }
            }
            switch state {
            case .loading:
                ProgressView()
            case .ready(let c):
                Text(c.title)
            case .networkError:
                Text(state.message ?? "")
                Button("다시 시도") { Task { await model.retry(testament) } }
            case .noNextDevotion:
                Text(state.message ?? "")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            if case .ready = state {
                screen = model.makeScreenModel(for: testament)
            }
        }
    }
}
