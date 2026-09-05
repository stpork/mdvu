import Foundation

enum MarkdownDialect: String { case generic, github, obsidian }
enum ThemeChoice: String { case system, light, dark }

enum MarkdownDocument {
    static let supportedExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]
    static func isMarkdown(url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}

struct CLIOptions {
    static let usage = "usage: mdvu [--theme system|light|dark] [--dialect generic|github|obsidian] [--no-mermaid] [--full-width] [--snapshot PNG] FILE|DIR …"
    var paths: [String] = []
    var dialect: MarkdownDialect = .generic
    var theme: ThemeChoice = .system
    var mermaid = true
    var fullWidth: Bool?
    var snapshotPath: String?
    static let `default` = CLIOptions()

    static func parse(_ arguments: [String]) -> CLIOptions {
        var result = CLIOptions(); var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--dialect": if let value = iterator.next(), let dialect = MarkdownDialect(rawValue: value) { result.dialect = dialect }
            case "--theme": if let value = iterator.next(), let theme = ThemeChoice(rawValue: value) { result.theme = theme }
            case "--no-mermaid": result.mermaid = false
            case "--full-width": result.fullWidth = true
            case "--snapshot": result.snapshotPath = iterator.next()
            case "--help", "-h": break
            default: if !argument.hasPrefix("-") { result.paths.append(argument) }
            }
        }
        return result
    }
}
