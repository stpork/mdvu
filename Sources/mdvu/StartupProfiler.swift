import Foundation
import os

final class StartupProfiler {
    private let start = ContinuousClock.now
    private var previous = ContinuousClock.now
    private let enabled = _isDebugAssertConfiguration()

    func mark(_ name: String) {
        guard enabled else { return }
        let now = ContinuousClock.now
        let total = start.duration(to: now)
        let delta = previous.duration(to: now)
        previous = now
        let line = String(format: "mdvu.profile %-26s %7.1f ms  total %7.1f ms", (name as NSString).utf8String!, milliseconds(delta), milliseconds(total))
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    private func milliseconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
    }
}
