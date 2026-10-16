import Foundation

public final class MdvuCoreBridge: @unchecked Sendable {
    public static let shared = MdvuCoreBridge()

    private typealias VersionFunc = @convention(c) () -> UnsafePointer<CChar>
    private typealias AssetStrFunc = @convention(c) () -> UnsafePointer<CChar>?
    private typealias CacheWriteFunc = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Void
    private typealias RenderBodyFunc = @convention(c) (
        UnsafePointer<CChar>,
        UnsafePointer<CChar>?,
        CBool,
        UnsafePointer<CChar>?,
        CBool
    ) -> OpaquePointer?
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
    private var fnGetMarkdownCss: AssetStrFunc?
    private var fnGetAppJs: AssetStrFunc?
    private var fnGetMermaidJs: AssetStrFunc?
    private var fnGetPlantumlJs: AssetStrFunc?
    private var fnGetKatexJs: AssetStrFunc?
    private var fnCacheWrite: CacheWriteFunc?
    private var fnRenderBody: RenderBodyFunc?
    private var fnRender: RenderFunc?
    private var fnGetHtml: GetStrFunc?
    private var fnGetBody: GetStrFunc?
    private var fnGetTitle: GetStrFunc?
    private var fnGetDialect: GetStrFunc?
    private var fnGetToc: GetStrFunc?
    private var fnFreeDoc: FreeDocFunc?

    public private(set) var isAvailable: Bool = false

    private init() {
        loadLibrary()
    }

    private func loadLibrary() {
        // 1. Try RTLD_DEFAULT: if statically linked into the Mach-O binary
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)!
        if bindSymbols(handle: rtldDefault) {
            return
        }

        // 2. Try standard search paths
        let cwd = FileManager.default.currentDirectoryPath
        var candidates: [String] = []
        if let envPath = ProcessInfo.processInfo.environment["MDVU_CORE_LIB"] {
            candidates.append(envPath)
        }
        if let res = Bundle.main.resourceURL?.appendingPathComponent("libmdvu_core.dylib").path {
            candidates.append(res)
        }
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/libmdvu_core.dylib").path)
        candidates.append("\(cwd)/target/release/libmdvu_core.dylib")
        candidates.append("target/release/libmdvu_core.dylib")
        candidates.append("../target/release/libmdvu_core.dylib")
        candidates.append("/opt/homebrew/lib/libmdvu_core.dylib")
        candidates.append("/usr/local/lib/libmdvu_core.dylib")

        for path in candidates where !path.isEmpty && FileManager.default.fileExists(atPath: path) {
            if let h = dlopen(path, RTLD_LAZY | RTLD_LOCAL) {
                if bindSymbols(handle: h) {
                    return
                }
            }
        }
    }

    @inline(__always)
    private func withOptionalCString<R>(_ string: String?, _ body: (UnsafePointer<CChar>?) -> R) -> R {
        if let string = string {
            return string.withCString { body($0) }
        } else {
            return body(nil)
        }
    }

    @discardableResult
    private func bindSymbols(handle: UnsafeMutableRawPointer) -> Bool {
        guard let symVersion = dlsym(handle, "mdvu_version"),
              let symRender = dlsym(handle, "mdvu_render_to_html"),
              let symGetHtml = dlsym(handle, "mdvu_document_get_html"),
              let symGetBody = dlsym(handle, "mdvu_document_get_body"),
              let symGetTitle = dlsym(handle, "mdvu_document_get_title"),
              let symGetToc = dlsym(handle, "mdvu_document_get_toc_json"),
              let symFreeDoc = dlsym(handle, "mdvu_document_free") else {
            return false
        }

        self.handle = handle
        self.fnVersion = unsafeBitCast(symVersion, to: VersionFunc.self)
        self.fnRender = unsafeBitCast(symRender, to: RenderFunc.self)
        self.fnGetHtml = unsafeBitCast(symGetHtml, to: GetStrFunc.self)
        self.fnGetBody = unsafeBitCast(symGetBody, to: GetStrFunc.self)
        self.fnGetTitle = unsafeBitCast(symGetTitle, to: GetStrFunc.self)
        self.fnGetToc = unsafeBitCast(symGetToc, to: GetStrFunc.self)
        self.fnFreeDoc = unsafeBitCast(symFreeDoc, to: FreeDocFunc.self)

        if let sym = dlsym(handle, "mdvu_render_body") {
            self.fnRenderBody = unsafeBitCast(sym, to: RenderBodyFunc.self)
        }
        if let sym = dlsym(handle, "mdvu_document_get_dialect") {
            self.fnGetDialect = unsafeBitCast(sym, to: GetStrFunc.self)
        }
        if let sym = dlsym(handle, "mdvu_get_markdown_css") {
            self.fnGetMarkdownCss = unsafeBitCast(sym, to: AssetStrFunc.self)
        }
        if let sym = dlsym(handle, "mdvu_get_app_js") {
            self.fnGetAppJs = unsafeBitCast(sym, to: AssetStrFunc.self)
        }
        if let sym = dlsym(handle, "mdvu_get_mermaid_js") {
            self.fnGetMermaidJs = unsafeBitCast(sym, to: AssetStrFunc.self)
        }
        if let sym = dlsym(handle, "mdvu_get_plantuml_js") {
            self.fnGetPlantumlJs = unsafeBitCast(sym, to: AssetStrFunc.self)
        }
        if let sym = dlsym(handle, "mdvu_get_katex_js") {
            self.fnGetKatexJs = unsafeBitCast(sym, to: AssetStrFunc.self)
        }
        if let sym = dlsym(handle, "mdvu_diagram_cache_write") {
            self.fnCacheWrite = unsafeBitCast(sym, to: CacheWriteFunc.self)
        }

        self.isAvailable = true
        return true
    }

    public var version: String? {
        guard isAvailable, let fn = fnVersion else { return nil }
        return String(cString: fn())
    }

    public var markdownCSS: String? {
        guard isAvailable, let fn = fnGetMarkdownCss, let ptr = fn() else { return nil }
        return String(cString: ptr)
    }

    public var appJavaScript: String? {
        guard isAvailable, let fn = fnGetAppJs, let ptr = fn() else { return nil }
        return String(cString: ptr)
    }

    public var mermaidJavaScript: String? {
        guard isAvailable, let fn = fnGetMermaidJs, let ptr = fn() else { return nil }
        return String(cString: ptr)
    }

    public var plantumlJavaScript: String? {
        guard isAvailable, let fn = fnGetPlantumlJs, let ptr = fn() else { return nil }
        return String(cString: ptr)
    }

    public var katexJavaScript: String? {
        guard isAvailable, let fn = fnGetKatexJs, let ptr = fn() else { return nil }
        return String(cString: ptr)
    }

    public func writeDiagramCache(key: String, svg: String) {
        guard isAvailable, let fn = fnCacheWrite else { return }
        key.withCString { cKey in
            svg.withCString { cSvg in
                fn(cKey, cSvg)
            }
        }
    }

    public func renderBody(
        source: String,
        dialect: String,
        isDialectExplicit: Bool = false,
        theme: String = "light",
        enableDiagrams: Bool = true
    ) -> (body: String, title: String?, dialect: String)? {
        guard isAvailable,
              let fnRenderBody = fnRenderBody,
              let fnGetBody = fnGetBody,
              let fnGetTitle = fnGetTitle,
              let fnGetDialect = fnGetDialect,
              let fnFreeDoc = fnFreeDoc else {
            return nil
        }

        return source.withCString { cSource in
            dialect.withCString { cDialect in
                theme.withCString { cTheme in
                    guard let doc = fnRenderBody(
                        cSource,
                        cDialect,
                        isDialectExplicit,
                        cTheme,
                        enableDiagrams
                    ) else {
                        return nil
                    }
                    defer { fnFreeDoc(doc) }

                    let body = fnGetBody(doc).map { String(cString: $0) } ?? ""
                    let docTitle = fnGetTitle(doc).map { String(cString: $0) }
                    let effDialect = fnGetDialect(doc).map { String(cString: $0) } ?? dialect

                    return (body: body, title: docTitle, dialect: effDialect)
                }
            }
        }
    }

    public func render(
        source: String,
        title: String? = nil,
        dialect: String? = nil,
        theme: String = "system",
        fullWidth: Bool = false,
        baseURL: URL? = nil,
        embedEngines: Bool = false
    ) -> (html: String, body: String, title: String?, tocJSON: String)? {
        guard isAvailable,
              let fnRender = fnRender,
              let fnGetHtml = fnGetHtml,
              let fnGetBody = fnGetBody,
              let fnGetTitle = fnGetTitle,
              let fnGetToc = fnGetToc,
              let fnFreeDoc = fnFreeDoc else {
            return nil
        }

        return source.withCString { cSource in
            theme.withCString { cTheme in
                withOptionalCString(title) { cTitle in
                    withOptionalCString(dialect) { cDialect in
                        withOptionalCString(baseURL?.absoluteString) { cBaseUrl in
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
                            let body = fnGetBody(doc).map { String(cString: $0) } ?? ""
                            let docTitle = fnGetTitle(doc).map { String(cString: $0) }
                            let toc = fnGetToc(doc).map { String(cString: $0) } ?? "[]"

                            return (html: html, body: body, title: docTitle, tocJSON: toc)
                        }
                    }
                }
            }
        }
    }
}
