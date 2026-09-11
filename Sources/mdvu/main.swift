import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--help") || arguments.contains("-h") {
    print(CLIOptions.usage)
    exit(EXIT_SUCCESS)
}
if arguments.contains("--version") || arguments.contains("-v") {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.2"
    print("mdvu \(version)")
    exit(EXIT_SUCCESS)
}
if BenchmarkRunner.runIfRequested(arguments) { exit(EXIT_SUCCESS) }

let options = CLIOptions.parse(arguments)
if let first = options.paths.first {
    EagerDocumentLoader.start(path: first, options: options)
}

let app = NSApplication.shared
WebKitPrewarmer.prewarm()
let delegate = AppDelegate(arguments: arguments)
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
