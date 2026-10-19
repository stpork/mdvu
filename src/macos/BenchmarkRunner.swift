import Foundation
import Darwin

enum BenchmarkRunner {
    static func runIfRequested(_ arguments: [String], options: CLIOptions) -> Int32? {
        guard arguments.contains("--benchmark") else { return nil }
        guard let path = options.paths.first else {
            FileHandle.standardError.write(Data("mdvu: error: --benchmark requires a file path argument\nusage: mdvu --benchmark <file>\n".utf8))
            return EXIT_FAILURE
        }
        let url = URL(fileURLWithPath: path)
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let source = String(decoding: data, as: UTF8.self)
            let mermaid = options.mermaid && ProcessInfo.processInfo.environment["MDVU_BENCHMARK_MERMAID"] == "1"
            let pipeline = MarkdownPipeline(dialect: options.dialect, mermaid: mermaid, isDialectExplicit: options.isDialectExplicit)
            if ProcessInfo.processInfo.environment["MDVU_BENCHMARK_WARMUP"] != "0" {
                autoreleasepool { _ = pipeline.render(source, diagramTheme: options.theme.rawValue) }
            }
            var samples: [Double] = []
            let runCount = max(1, Int(ProcessInfo.processInfo.environment["MDVU_BENCHMARK_RUNS"] ?? "") ?? 5)
            for _ in 0..<runCount {
                let start = ContinuousClock.now
                autoreleasepool { _ = pipeline.render(source, diagramTheme: options.theme.rawValue) }
                let parts = start.duration(to: .now).components
                samples.append(Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15)
            }
            samples.sort()
            let median = samples[samples.count / 2]
            print(String(format: "%7.2f MB  median %8.2f ms  %8.1f MB/s", Double(data.count) / 1_048_576, median, Double(data.count) / 1_048_576 / (median / 1_000)))
        } catch {
            FileHandle.standardError.write(Data("mdvu benchmark: \(error.localizedDescription)\n".utf8))
            return EXIT_FAILURE
        }
        return EXIT_SUCCESS
    }
}
