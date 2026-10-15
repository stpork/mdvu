import Foundation

public final class MdvuCoreBridge: @unchecked Sendable {
    public static let shared = MdvuCoreBridge()

    private typealias VersionFunc = @convention(c) () -> UnsafePointer<CChar>
    private typealias RenderFunc = @convention(c) (
        UnsafePointer<CChar>,
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?,
        CBool,
        UnsafePointer<CChar>?,
        CBool
    ) -> OpaquePointer?
    private typealias GetStrFunc = @convention(c) (OpaquePointer) -> UnsafePointer<CChar>?
    private typealias FreeDocFunc = @convention(c) (OpaquePointer) -> Void

    private var handle: UnsafeMutableRawPointer?
    private var fnVersion: VersionFunc?
    private var fnRender: RenderFunc?
    private var fnGetHtml: GetStrFunc?
    private var fnGetTitle: GetStrFunc?
    private var fnGetToc: GetStrFunc?
    private var fnFreeDoc: FreeDocFunc?

    public private(set) var isAvailable: Bool = false

    private init() {
        loadLibrary()
    }

    private func loadLibrary() {
        let candidates: [String] = [
            // Bundle resources
            Bundle.main.resourceURL?.appendingPathComponent("libmdvu_core.dylib").path ?? "",
            Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/libmdvu_core.dylib").path,
            // Build tree targets
            "target/release/libmdvu_core.dylib",
            "target/debug/libmdvu_core.dylib",
            "../target/release/libmdvu_core.dylib",
            // System paths
            "/usr/local/lib/libmdvu_core.dylib",
            "/opt/homebrew/lib/libmdvu_core.dylib"
        ]

        for path in candidates where !path.isEmpty && FileManager.default.fileExists(atPath: path) {
            if let h = dlopen(path, RTLD_LAZY | RTLD_LOCAL) {
                bindSymbols(handle: h)
                if isAvailable { return }
            }
        }

        // Try global lookup if already loaded or linked
        if let h = dlopen(nil, RTLD_LAZY | RTLD_LOCAL) {
            bindSymbols(handle: h)
        }
    }

    private func bindSymbols(handle: UnsafeMutableRawPointer) {
        guard let symVersion = dlsym(handle, "mdvu_version"),
              let symRender = dlsym(handle, "mdvu_render_to_html"),
              let symGetHtml = dlsym(handle, "mdvu_document_get_html"),
              let symGetTitle = dlsym(handle, "mdvu_document_get_title"),
              let symGetToc = dlsym(handle, "mdvu_document_get_toc_json"),
              let symFreeDoc = dlsym(handle, "mdvu_document_free") else {
            return
        }

        self.handle = handle
        self.fnVersion = unsafeBitCast(symVersion, to: VersionFunc.self)
        self.fnRender = unsafeBitCast(symRender, to: RenderFunc.self)
        self.fnGetHtml = unsafeBitCast(symGetHtml, to: GetStrFunc.self)
        self.fnGetTitle = unsafeBitCast(symGetTitle, to: GetStrFunc.self)
        self.fnGetToc = unsafeBitCast(symGetToc, to: GetStrFunc.self)
        self.fnFreeDoc = unsafeBitCast(symFreeDoc, to: FreeDocFunc.self)
        self.isAvailable = true
    }

    public var version: String? {
        guard isAvailable, let fn = fnVersion else { return nil }
        return String(cString: fn())
    }

    public func render(
        source: String,
        title: String? = nil,
        dialect: String? = nil,
        theme: String = "system",
        fullWidth: Bool = false,
        baseURL: URL? = nil,
        embedEngines: Bool = false
    ) -> (html: String, title: String?, tocJSON: String)? {
        guard isAvailable,
              let fnRender = fnRender,
              let fnGetHtml = fnGetHtml,
              let fnGetTitle = fnGetTitle,
              let fnGetToc = fnGetToc,
              let fnFreeDoc = fnFreeDoc else {
            return nil
        }

        return source.withCString { cSource in
            let cTitle = title?.withCString { $0 }
            let cDialect = dialect?.withCString { $0 }
            let cBaseUrl = baseURL?.absoluteString.withCString { $0 }

            return theme.withCString { cTheme in
                guard let doc = fnRender(
                    cSource,
                    cTitle,
                    cDialect,
                    cTheme,
                    fullWidth,
                    cBaseUrl,
                    embedEngines
                ) else {
                    return nil
                }
                defer { fnFreeDoc(doc) }

                let html = fnGetHtml(doc).map { String(cString: $0) } ?? ""
                let docTitle = fnGetTitle(doc).map { String(cString: $0) }
                let toc = fnGetToc(doc).map { String(cString: $0) } ?? "[]"

                return (html: html, title: docTitle, tocJSON: toc)
            }
        }
    }
}
