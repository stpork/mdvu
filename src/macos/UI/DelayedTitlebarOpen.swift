import Foundation

@MainActor
final class DelayedTitlebarOpen {
    private let interval: TimeInterval
    private var generation = 0

    init(interval: TimeInterval) { self.interval = interval }

    func cancel() { generation += 1 }

    func schedule(_ action: @escaping () -> Void) {
        cancel()
        let scheduledGeneration = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            guard let self, self.generation == scheduledGeneration else { return }
            self.generation += 1
            action()
        }
    }
}
