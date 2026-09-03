import Foundation

enum BenchmarkRunner {
    static func runIfRequested(_ arguments: [String]) -> Bool {
        guard let flag = arguments.firstIndex(of: "--benchmark"), arguments.indices.contains(flag + 1) else { return false }
        let url = URL(fileURLWithPath: arguments[flag + 1])
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let source = String(decoding: data, as: UTF8.self)
            let mermaid = ProcessInfo.processInfo.environment["MDV_BENCHMARK_MERMAID"] == "1"
            let pipeline = MarkdownPipeline(dialect: .github, mermaid: mermaid)
            if ProcessInfo.processInfo.environment["MDV_BENCHMARK_WARMUP"] != "0" {
                autoreleasepool { _ = pipeline.render(source) }
            }
            var samples: [Double] = []
            let runCount = max(1, Int(ProcessInfo.processInfo.environment["MDV_BENCHMARK_RUNS"] ?? "") ?? 5)
            for _ in 0..<runCount {
                let start = ContinuousClock.now
                autoreleasepool { _ = pipeline.render(source) }
                let parts = start.duration(to: .now).components
                samples.append(Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15)
            }
            samples.sort()
            let median = samples[samples.count / 2]
            print(String(format: "%7.2f MB  median %8.2f ms  %8.1f MB/s", Double(data.count) / 1_048_576, median, Double(data.count) / 1_048_576 / (median / 1_000)))
        } catch {
            FileHandle.standardError.write(Data("mdv benchmark: \(error.localizedDescription)\n".utf8))
        }
        return true
    }
}
