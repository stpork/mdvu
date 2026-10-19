import Foundation

// A command installed in ~/.local/bin can point into the app. Foundation's main
// bundle then describes the symlink location, so resolve the real app once.
enum AppBundle {
    static var version: String {
        if let version = main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, !version.isEmpty {
            return version
        }
        return MdvuCoreBridge.shared.version ?? "unknown"
    }

    static let main: Bundle = {
        let executable = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        let application = executable.resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard application.pathExtension == "app", let bundle = Bundle(url: application) else { return Bundle.main }
        return bundle
    }()
}
