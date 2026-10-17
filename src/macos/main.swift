import AppKit
import Darwin

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--help") || arguments.contains("-h") {
    print(CLIOptions.usage)
    exit(EXIT_SUCCESS)
}
if arguments.contains("--version") || arguments.contains("-v") {
    let version = AppBundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? MdvuCoreBridge.shared.version ?? "0.5.0"
    print("mdvu \(version)")
    exit(EXIT_SUCCESS)
}
let options = CLIOptions.parse(arguments)
guard MdvuCoreBridge.shared.isAvailable else {
    let message = "mdvu-core is missing or incompatible. Rebuild or reinstall mdvu."
    if options.isHeadless || arguments.contains("--benchmark") {
        fputs("mdvu: \(message)\n", stderr)
    } else {
        _ = NSApplication.shared
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Unable to start mdvu"
        alert.informativeText = message
        alert.runModal()
    }
    exit(EXIT_FAILURE)
}
if BenchmarkRunner.runIfRequested(arguments) { exit(EXIT_SUCCESS) }

// Headless CLI execution (no GUI window)
if options.isHeadless {
    // A closed consumer should terminate a Unix pipeline, not raise an Objective-C exception.
    signal(SIGPIPE, SIG_DFL)
    let inputContent: String
    let baseURL: URL?
    let defaultTitle: String

    if let path = options.paths.first, path != "-" {
        let fileURL = URL(fileURLWithPath: path).standardizedFileURL
        baseURL = fileURL
        defaultTitle = fileURL.deletingPathExtension().lastPathComponent
        do {
            inputContent = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            fputs("mdvu: error reading file '\(path)': \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    } else {
        baseURL = nil
        defaultTitle = "Document"
        let data = FileHandle.standardInput.readDataToEndOfFile()
        inputContent = String(decoding: data, as: UTF8.self)
    }

    let docTitle = options.title ?? defaultTitle
    let dialectStr = options.dialect.rawValue

    if let rendered = MdvuCoreBridge.shared.render(
           source: inputContent,
           title: docTitle,
           dialect: dialectStr,
           theme: options.theme.rawValue,
           fullWidth: options.fullWidth ?? false,
           baseURL: baseURL,
           embedEngines: options.standalone,
           isDialectExplicit: options.isDialectExplicit,
           enableDiagrams: options.mermaid
       ) {
        if options.outputTOC {
            print(rendered.tocJSON)
            exit(EXIT_SUCCESS)
        }

        if let outPath = options.outputPath {
            do {
                try rendered.html.write(toFile: outPath, atomically: true, encoding: .utf8)
                exit(EXIT_SUCCESS)
            } catch {
                fputs("mdvu: error writing output to '\(outPath)': \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        } else {
            FileHandle.standardOutput.write(Data(rendered.html.utf8))
            exit(EXIT_SUCCESS)
        }
    } else {
        fputs("mdvu: mdvu-core failed to render the document\n", stderr)
        exit(EXIT_FAILURE)
    }
}

if let first = options.paths.first {
    EagerDocumentLoader.start(path: first, options: options)
}

let app = NSApplication.shared
WebKitPrewarmer.prewarm()
let delegate = AppDelegate(arguments: arguments)
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
