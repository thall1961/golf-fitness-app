import SwiftUI
import UIKit

struct RestTimerView: View {
    let seconds: Int
    let onFinished: () -> Void

    @State private var remaining: Int
    @State private var countdownTask: Task<Void, Never>?

    init(seconds: Int, onFinished: @escaping () -> Void) {
        self.seconds = seconds
        self.onFinished = onFinished
        _remaining = State(initialValue: seconds)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Rest")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(remaining)s")
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Button("Skip rest") { stop() }
                .buttonStyle(.bordered)
        }
        .onAppear(perform: start)
        .onDisappear { countdownTask?.cancel() }
    }

    private func start() {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                remaining -= 1
                if remaining == 0 {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    stop()
                }
            }
        }
    }

    private func stop() {
        countdownTask?.cancel()
        countdownTask = nil
        onFinished()
    }
}
