import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--help") || arguments.contains("-h") {
    print(CLIOptions.usage)
    exit(EXIT_SUCCESS)
}
if BenchmarkRunner.runIfRequested(arguments) { exit(EXIT_SUCCESS) }

let app = NSApplication.shared
let delegate = AppDelegate(arguments: arguments)
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
