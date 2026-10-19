import Foundation

enum MarkdownDialect: String, CaseIterable {
    case generic, github, obsidian, mkdocs, docusaurus, commonmark, hugo

    var menuTitle: String {
        switch self {
        case .generic: "Generic (CommonMark)"
        case .github: "GitHub (GFM)"
        case .obsidian: "Obsidian"
        case .mkdocs: "MkDocs"
        case .docusaurus: "Docusaurus"
        case .commonmark: "CommonMark"
        case .hugo: "Hugo"
        }
    }

    fileprivate static func normalized(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
            .lowercased()
    }

    static func from(string: String) -> MarkdownDialect? {
        let clean = normalized(string)
        switch clean {
        case "obsidian": return .obsidian
        case "github", "gfm": return .github
        case "generic", "default", "auto", "automatic": return .generic
        case "cm": return .commonmark
        default: return MarkdownDialect(rawValue: clean)
        }
    }
}
enum ThemeChoice: String { case system, light, dark }

enum MarkdownDocument {
    static let supportedExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]
    static func isMarkdown(url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}

struct CLIOptions {
    static let usage = """
    Usage: mdvu [OPTIONS] [FILE]

    Ultra-fast native Markdown viewer & headless renderer.

    Arguments:
      [FILE]                   Markdown file path (reads from stdin if omitted with -o/--stdout or "-")

    Headless / Export Options:
      -o, --output <OUTPUT>    Render to HTML file instead of opening GUI
          --stdout             Render HTML to stdout instead of opening GUI
          --toc                Output Table of Contents (JSON) to stdout and exit
      -s, --standalone         Embed offline diagram & math engines (KaTeX, Mermaid, PlantUML)
          --title <TITLE>      Override document title

    Display & Dialect Options:
      -d, --dialect <DIALECT>  generic, github (gfm), obsidian, mkdocs, docusaurus, commonmark, hugo
      -t, --theme <THEME>      system, light, dark [default: system]
          --full-width         Enable full-width article view
          --navigator          Open with directory navigator sidebar
          --no-mermaid         Disable Mermaid/ZenUML and PlantUML diagrams

    Diagnostic Options:
          --benchmark          Run Markdown parsing benchmarks
          --snapshot <PNG>     Capture offscreen window snapshot to PNG
      -v, --version            Show version information
      -h, --help               Show this help message
    """

    var paths: [String] = []
    var outputPath: String?
    var forceStdout: Bool = false
    var outputTOC: Bool = false
    var standalone: Bool = false
    var title: String?
    var dialect: MarkdownDialect = .generic
    var isDialectExplicit = false
    var theme: ThemeChoice = .system
    var mermaid = true
    var fullWidth: Bool?
    var navigator: Bool?
    var snapshotPath: String?

    var isHeadless: Bool {
        return outputPath != nil || forceStdout || outputTOC || paths.contains("-")
    }

    static let `default` = CLIOptions()

    static func parse(_ arguments: [String]) -> CLIOptions {
        var result = CLIOptions()
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "-o", "--output":
                result.outputPath = iterator.next()
            case "--stdout":
                result.forceStdout = true
            case "--toc":
                result.outputTOC = true
            case "-s", "--standalone":
                result.standalone = true
            case "--title":
                result.title = iterator.next()
            case "-d", "--dialect":
                if let value = iterator.next(), let dialect = MarkdownDialect.from(string: value) {
                    result.dialect = dialect
                    result.isDialectExplicit = !["auto", "automatic"].contains(MarkdownDialect.normalized(value))
                }
            case "-t", "--theme":
                if let value = iterator.next(), let theme = ThemeChoice(rawValue: value) {
                    result.theme = theme
                }
            case "--no-mermaid":
                result.mermaid = false
            case "--full-width":
                result.fullWidth = true
            case "--navigator":
                result.navigator = true
            case "--snapshot":
                result.snapshotPath = iterator.next()
            case "--help", "-h", "--version", "-v", "--benchmark":
                break
            default:
                if argument == "-" {
                    result.paths.append("-")
                } else if !argument.hasPrefix("-") {
                    result.paths.append(argument)
                }
            }
        }
        return result
    }
}
