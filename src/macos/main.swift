import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--help") || arguments.contains("-h") {
    print(CLIOptions.usage)
    exit(EXIT_SUCCESS)
}
if arguments.contains("--version") || arguments.contains("-v") {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? MdvuCoreBridge.shared.version ?? "0.5.0"
    print("mdvu \(version)")
    exit(EXIT_SUCCESS)
}
if BenchmarkRunner.runIfRequested(arguments) { exit(EXIT_SUCCESS) }

let options = CLIOptions.parse(arguments)

// Headless CLI execution (no GUI window)
if options.isHeadless {
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

    if let bridge = MdvuCoreBridge.shared.isAvailable ? MdvuCoreBridge.shared : nil,
       let rendered = bridge.render(
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
        // Fallback using Swift MarkdownPipeline + HTMLDocument
        let pipeline = MarkdownPipeline(dialect: options.dialect, mermaid: options.mermaid, isDialectExplicit: options.isDialectExplicit)
        let renderedDoc = pipeline.render(inputContent, diagramTheme: options.theme.rawValue)
        let html = HTMLDocument.make(
            body: renderedDoc.body,
            title: docTitle,
            theme: options.theme,
            fullWidth: options.fullWidth ?? false,
            baseURL: baseURL,
            embedEngines: options.standalone
        )

        if options.outputTOC {
            fputs("mdvu: TOC extraction requires mdvu-core bridge\n", stderr)
            exit(EXIT_FAILURE)
        }

        if let outPath = options.outputPath {
            do {
                try html.write(toFile: outPath, atomically: true, encoding: .utf8)
                exit(EXIT_SUCCESS)
            } catch {
                fputs("mdvu: error writing output to '\(outPath)': \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        } else {
            FileHandle.standardOutput.write(Data(html.utf8))
            exit(EXIT_SUCCESS)
        }
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
