#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

#[cfg(windows)]
mod diagram_worker;
mod gui_shell;

#[cfg(windows)]
mod win32;

use clap::Parser as ClapParser;
use mdvu_core::{
    get_base_url_for_file, get_katex_js, get_mermaid_js, get_plantuml_js, navigator,
    render_markdown_body, render_markdown_full_options, split_path_and_fragment, DiagramCache,
    MarkdownDialect, NavigationHistory, RenderedDocument, ZoomPolicy,
};
use notify::{RecommendedWatcher, RecursiveMode, Watcher};
use serde::Deserialize;
use std::fs;
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::mpsc::{channel, RecvTimeoutError};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use tao::{
    dpi::LogicalSize,
    event::{ElementState, Event as TaoEvent, MouseButton, WindowEvent},
    event_loop::{ControlFlow, EventLoop, EventLoopBuilder},
    keyboard::{KeyCode, ModifiersState},
    window::WindowBuilder,
};
use wry::WebViewBuilder;

#[derive(ClapParser, Debug)]
#[command(name = "mdvu")]
#[command(
    about = "Ultra-fast native Markdown viewer & headless renderer",
    version = env!("CARGO_PKG_VERSION"),
    long_about = None
)]
struct Args {
    /// Input Markdown file or directory path (reads from stdin if omitted with -o/--stdout or "-")
    #[arg(value_name = "PATH")]
    input: Option<PathBuf>,

    /// Write output to file instead of launching GUI (headless mode)
    #[arg(short, long, value_name = "OUTPUT")]
    output: Option<PathBuf>,

    /// Force render HTML to stdout instead of launching GUI (headless mode)
    #[arg(long)]
    stdout: bool,

    /// Print Table of Contents (JSON) to stdout and exit
    #[arg(long)]
    toc: bool,

    /// Document title override
    #[arg(long)]
    title: Option<String>,

    /// Markdown dialect: auto, generic, obsidian, mkdocs, docusaurus, gfm, commonmark
    #[arg(short, long, default_value = "auto")]
    dialect: String,

    /// Color theme: light, dark, system
    #[arg(short = 't', visible_short_alias = 'T', long, default_value = "system")]
    theme: String,

    /// Enable full-width view (removes article max-width)
    #[arg(long)]
    full_width: bool,

    /// Disable Mermaid and PlantUML diagram rendering
    #[arg(long)]
    no_mermaid: bool,

    /// Embed all offline diagram & math engines (KaTeX, Mermaid, PlantUML) into the HTML
    #[arg(short, long)]
    standalone: bool,

    /// Show file navigator / vault sidebar on startup
    #[arg(long)]
    navigator: bool,

    /// Run internal rendering benchmark on target file and print throughput
    #[arg(long)]
    benchmark: bool,
}

impl Args {
    fn is_headless(&self) -> bool {
        self.output.is_some()
            || self.stdout
            || self.toc
            || self.benchmark
            || self.input.as_ref().map(|p| p.to_string_lossy()) == Some("-".into())
    }
}

#[cfg(windows)]
fn attach_console() {
    use std::os::windows::io::IntoRawHandle;
    use windows_sys::Win32::Foundation::{HANDLE, INVALID_HANDLE_VALUE};
    use windows_sys::Win32::Storage::FileSystem::{GetFileType, FILE_TYPE_UNKNOWN};
    use windows_sys::Win32::System::Console::{
        AttachConsole, GetStdHandle, SetStdHandle, ATTACH_PARENT_PROCESS, STD_ERROR_HANDLE,
        STD_INPUT_HANDLE, STD_OUTPUT_HANDLE,
    };

    unsafe fn is_valid_handle(h: HANDLE) -> bool {
        !h.is_null() && h != INVALID_HANDLE_VALUE && GetFileType(h) != FILE_TYPE_UNKNOWN
    }

    unsafe {
        let orig_out = GetStdHandle(STD_OUTPUT_HANDLE);
        let orig_err = GetStdHandle(STD_ERROR_HANDLE);
        let orig_in = GetStdHandle(STD_INPUT_HANDLE);

        let has_out = is_valid_handle(orig_out);
        let has_err = is_valid_handle(orig_err);
        let has_in = is_valid_handle(orig_in);

        if has_out && has_err && has_in {
            return;
        }

        if AttachConsole(ATTACH_PARENT_PROCESS) != 0 {
            if has_out {
                SetStdHandle(STD_OUTPUT_HANDLE, orig_out);
            } else if !is_valid_handle(GetStdHandle(STD_OUTPUT_HANDLE)) {
                if let Ok(file) = fs::OpenOptions::new().write(true).open("CONOUT$") {
                    SetStdHandle(STD_OUTPUT_HANDLE, file.into_raw_handle() as _);
                }
            }

            if has_err {
                SetStdHandle(STD_ERROR_HANDLE, orig_err);
            } else if !is_valid_handle(GetStdHandle(STD_ERROR_HANDLE)) {
                if let Ok(file) = fs::OpenOptions::new().write(true).open("CONOUT$") {
                    SetStdHandle(STD_ERROR_HANDLE, file.into_raw_handle() as _);
                }
            }

            if has_in {
                SetStdHandle(STD_INPUT_HANDLE, orig_in);
            } else if !is_valid_handle(GetStdHandle(STD_INPUT_HANDLE)) {
                if let Ok(file) = fs::File::open("CONIN$") {
                    SetStdHandle(STD_INPUT_HANDLE, file.into_raw_handle() as _);
                }
            }
        }
    }
}

#[cfg(not(windows))]
fn attach_console() {}

fn open_external_url(url: &str) {
    if !mdvu_core::navigator::is_external_url(url) {
        return;
    }
    #[cfg(windows)]
    unsafe {
        win32::open_url_in_browser(url);
    }
    #[cfg(target_os = "macos")]
    {
        let _ = std::process::Command::new("open").arg(url).spawn();
    }
    #[cfg(all(not(windows), not(target_os = "macos")))]
    {
        let _ = std::process::Command::new("xdg-open").arg(url).spawn();
    }
}

fn run_headless(args: Args) -> Result<(), Box<dyn std::error::Error>> {
    let (content, base_url) = match args.input {
        Some(ref path) if path.to_string_lossy() != "-" => {
            let s = fs::read_to_string(path)?;
            let url = get_base_url_for_file(path);
            (s, url)
        }
        _ => {
            let mut buf = String::new();
            io::stdin().read_to_string(&mut buf)?;
            (buf, None)
        }
    };

    let clean_dialect = args.dialect.trim().to_ascii_lowercase();
    let is_explicit = clean_dialect != "auto" && clean_dialect != "automatic";
    let dialect = MarkdownDialect::from_str_name(&args.dialect).unwrap_or(MarkdownDialect::Generic);

    if args.benchmark {
        let size_bytes = content.len();
        let size_mb = size_bytes as f64 / 1_048_576.0;

        let enable_diagrams = !args.no_mermaid
            && std::env::var("MDVU_BENCHMARK_MERMAID")
                .map(|v| v != "0")
                .unwrap_or(true);

        // Warmup run
        let _ = render_markdown_body(&content, dialect, is_explicit, &args.theme, enable_diagrams);

        let runs = std::env::var("MDVU_BENCHMARK_RUNS")
            .ok()
            .and_then(|s| s.parse::<usize>().ok())
            .unwrap_or(10)
            .max(1);

        let mut samples = Vec::with_capacity(runs);
        for _ in 0..runs {
            let start = Instant::now();
            let _ =
                render_markdown_body(&content, dialect, is_explicit, &args.theme, enable_diagrams);
            samples.push(start.elapsed().as_secs_f64() * 1000.0);
        }

        samples.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let median = samples[samples.len() / 2];
        let min = samples.first().copied().unwrap_or(0.0);
        let max = samples.last().copied().unwrap_or(0.0);
        let throughput = if median > 0.0 {
            size_mb / (median / 1000.0)
        } else {
            0.0
        };

        let file_name = args
            .input
            .as_ref()
            .and_then(|p| p.file_name())
            .map(|f| f.to_string_lossy().to_string())
            .unwrap_or_else(|| "stdin".to_string());
        println!(
            "{size_mb:7.2} MB  median {median:8.2} ms (min {min:6.2} ms, max {max:6.2} ms)  {throughput:8.1} MB/s  [{file_name}]"
        );
        let _ = io::stdout().flush();
        return Ok(());
    }

    let (html, rendered) = render_markdown_full_options(
        &content,
        args.title.as_deref(),
        dialect,
        is_explicit,
        &args.theme,
        args.full_width,
        base_url.as_deref(),
        args.standalone,
        !args.no_mermaid,
    );

    if args.toc {
        let toc_json = serde_json::to_string_pretty(&rendered.toc)?;
        println!("{toc_json}");
        let _ = io::stdout().flush();
        return Ok(());
    }

    match args.output {
        Some(out_path) => {
            if let Some(parent) = out_path.parent() {
                if !parent.as_os_str().is_empty() {
                    let _ = fs::create_dir_all(parent);
                }
            }
            fs::write(out_path, html)?;
        }
        None => {
            io::stdout().write_all(html.as_bytes())?;
            let _ = io::stdout().flush();
        }
    }

    Ok(())
}

#[derive(Debug)]
pub enum UserEvent {
    ShellReady,
    DiagramRequest(String),
    DiagramCancel,
    DiagramMessage(String),
    DiagramRuntimeReady(String, Result<&'static str, &'static str>),
    FileChanged,
    OpenFile(PathBuf),
    OpenFileWithFragment(PathBuf, Option<String>),
    OpenRelativePath(String),
    OpenFolder(PathBuf),
    OpenExternal(String),
    TriggerOpenFile,
    TriggerOpenFolder,
    ToggleTOC,
    ToggleNav,
    ToggleFullWidth,
    SetDialectAuto,
    SetDialect(MarkdownDialect),
    SetTheme(String),
    ZoomIn,
    ZoomOut,
    ZoomReset,
    SetZoom(String),
    ToggleFullscreen,
    GoBack,
    GoForward,
    Find,
    FindNext,
    FindPrev,
    EditUndo,
    EditRedo,
    EditCut,
    EditCopy,
    EditPaste,
    EditSelectAll,
    ShowAbout,
    OpenRepo,
    Exit,
    DocumentReady(Box<PreparedDocument>),
    FolderReady(PathBuf, Vec<navigator::VaultItem>, Option<PathBuf>),
    SmokeResult(String),
    ArticleReady(String),
    UiTestResult(String),
    SystemThemeChanged(bool),
    RuntimeReady(&'static str, Result<&'static str, &'static str>),
}

#[derive(Deserialize)]
struct DiagramCacheMsg {
    key: String,
    svg: String,
}

#[derive(Debug)]
pub struct PreparedDocument {
    generation: u64,
    path: PathBuf,
    preserve_scroll: bool,
    title: String,
    base: Option<String>,
    doc: RenderedDocument,
    dialect: MarkdownDialect,
    vault: Option<(PathBuf, Vec<navigator::VaultItem>)>,
}
struct RenderRequest {
    generation: u64,
    path: PathBuf,
    preserve_scroll: bool,
    dialect: MarkdownDialect,
    explicit: bool,
    theme: String,
    diagrams: bool,
    scan_root: Option<PathBuf>,
}
struct AppState {
    render_sender: Option<std::sync::mpsc::Sender<RenderRequest>>,
    generation: u64,
    system_dark: bool,
    current_file: Option<PathBuf>,
    pending_fragment: Option<String>,
    vault_root: Option<PathBuf>,
    vault_items: Vec<navigator::VaultItem>,
    current_title: String,
    zoom_level: f64,
    last_toggle: Instant,
    last_rendered: Option<RenderedDocument>,
    dialect: MarkdownDialect,
    effective_dialect: MarkdownDialect,
    is_dialect_explicit: bool,
    enable_diagrams: bool,
    theme: String,
    full_width: bool,
    is_toc_visible: bool,
    is_nav_visible: bool,
    history: NavigationHistory<PathBuf>,
    katex_injected: bool,
    mermaid_injected: bool,
    plantuml_injected: bool,
}

fn watch_target(watcher: &mut RecommendedWatcher, target: &Path) {
    if let Some(parent) = target.parent() {
        if parent.exists() {
            let _ = watcher.watch(parent, RecursiveMode::NonRecursive);
            return;
        }
    }
    let _ = watcher.watch(target, RecursiveMode::NonRecursive);
}

fn unwatch_target(watcher: &mut RecommendedWatcher, target: &Path) {
    if let Some(parent) = target.parent() {
        let _ = watcher.unwatch(parent);
    }
    let _ = watcher.unwatch(target);
}

fn render_body_for_state(
    path: &Path,
    st: &AppState,
) -> (String, Option<String>, RenderedDocument, MarkdownDialect) {
    read_document(
        path,
        st.dialect,
        st.is_dialect_explicit,
        &st.theme,
        st.enable_diagrams,
    )
}
fn read_document(
    path: &Path,
    dialect: MarkdownDialect,
    explicit: bool,
    theme: &str,
    diagrams: bool,
) -> (String, Option<String>, RenderedDocument, MarkdownDialect) {
    let source = fs::read_to_string(path).unwrap_or_else(|e| {
        format!(
            "# Error Opening Document\n\nFailed to read `{}`: {e}",
            path.display()
        )
    });
    let base_url = get_base_url_for_file(path);
    let (doc, effective_dialect) =
        render_markdown_body(&source, dialect, explicit, theme, diagrams);
    let title = doc
        .title
        .clone()
        .or_else(|| path.file_name().map(|f| f.to_string_lossy().to_string()))
        .unwrap_or_else(|| "mdvu".to_string());
    let window_title = format!("{title} — mdvu");
    (window_title, base_url, doc, effective_dialect)
}

fn build_gui_page(
    file_path: Option<&Path>,
    st: &mut AppState,
) -> (String, String, Option<RenderedDocument>) {
    if let Some(path) = file_path {
        let (window_title, base_url, doc, effective_dialect) = render_body_for_state(path, st);
        st.effective_dialect = effective_dialect;

        let raw_html = mdvu_core::make_html_selective(
            &doc.body,
            &window_title,
            &st.theme,
            st.full_width,
            base_url.as_deref(),
            false,
            false,
            false,
        );

        let vault_name = st
            .vault_root
            .as_ref()
            .and_then(|r| r.file_name())
            .map(|f| f.to_string_lossy().to_string())
            .unwrap_or_else(|| "Workspace".to_string());

        let cur_path_str = path.to_string_lossy().replace('\\', "/");

        let full_gui_html = gui_shell::build_gui_html(
            &raw_html,
            &doc.toc,
            &vault_name,
            &st.vault_items,
            Some(&cur_path_str),
            st.is_toc_visible,
            st.is_nav_visible,
            st.full_width,
            st.zoom_level,
            st.history.can_go_back(),
            st.history.can_go_forward(),
        );

        (full_gui_html, window_title, Some(doc))
    } else {
        let empty_article = r#"<div class="empty">
            <h1>mdvu</h1>
            <p style="color:var(--muted);font-size:1.12rem;margin:12px 0 24px;">Ultra-fast native Markdown &amp; Mermaid viewer</p>
            <div style="display:flex;gap:12px;justify-content:center;flex-wrap:wrap;">
                <button id="mdvu-open-btn" style="padding:10px 22px;background:var(--accent);color:#fff;border:none;border-radius:8px;font-size:0.96rem;font-weight:600;cursor:pointer;">Open Markdown File (Ctrl+O)</button>
                <button id="mdvu-open-folder-btn" style="padding:10px 22px;background:var(--soft);color:var(--fg);border:1px solid var(--line);border-radius:8px;font-size:0.96rem;font-weight:600;cursor:pointer;">Open Folder / Vault (Ctrl+Shift+O)</button>
            </div>
            <p style="color:var(--muted);font-size:0.86rem;margin-top:18px;">or drag and drop a file or folder anywhere into this window</p>
        </div>"#;

        let base_html = mdvu_core::make_html_selective(
            empty_article,
            "mdvu",
            &st.theme,
            st.full_width,
            None,
            false,
            false,
            false,
        );

        let vault_name = st
            .vault_root
            .as_ref()
            .and_then(|r| r.file_name())
            .map(|f| f.to_string_lossy().to_string())
            .unwrap_or_else(|| "Workspace".to_string());

        let full_gui_html = gui_shell::build_gui_html(
            &base_html,
            &[],
            &vault_name,
            &st.vault_items,
            None,
            st.is_toc_visible,
            st.is_nav_visible,
            st.full_width,
            st.zoom_level,
            st.history.can_go_back(),
            st.history.can_go_forward(),
        );

        (full_gui_html, "mdvu".to_string(), None)
    }
}

/// Injects KaTeX, Mermaid, or PlantUML JS runtimes on demand into the active WebView
/// only when the document requires them and they have not yet been injected.
fn inject_needed_runtimes(
    webview: &wry::WebView,
    st: &mut AppState,
    proxy: &tao::event_loop::EventLoopProxy<UserEvent>,
) {
    let (needs_math, needs_mermaid, needs_plantuml) = match st.last_rendered {
        Some(ref doc) => (
            doc.has_math,
            st.enable_diagrams && doc.has_mermaid && !cfg!(windows),
            st.enable_diagrams && doc.has_plantuml && !cfg!(windows),
        ),
        None => return,
    };

    for (needed, injected, name, getter) in [
        (
            needs_math,
            &mut st.katex_injected,
            "katex",
            get_katex_js as fn() -> Result<&'static str, &'static str>,
        ),
        (
            needs_mermaid,
            &mut st.mermaid_injected,
            "mermaid",
            get_mermaid_js as fn() -> Result<&'static str, &'static str>,
        ),
        (
            needs_plantuml,
            &mut st.plantuml_injected,
            "plantuml",
            get_plantuml_js as fn() -> Result<&'static str, &'static str>,
        ),
    ] {
        if needed && !*injected {
            *injected = true;
            let proxy = proxy.clone();
            std::thread::spawn(move || {
                let _ = proxy.send_event(UserEvent::RuntimeReady(name, getter()));
            });
        }
    }

    if needs_math || needs_mermaid || needs_plantuml {
        let _ = webview
            .evaluate_script("window.__mdvuRenderMath?.(); window.__mdvuRenderDiagrams?.();");
    }
}

/// Updates the active document inside the WebView in-place without destroying the GUI shell or reloading JS engines.
fn update_webview_document(
    webview: &wry::WebView,
    window: &tao::window::Window,
    st: &mut AppState,
    path: &Path,
    preserve_scroll: bool,
) {
    st.generation += 1;
    if !st
        .vault_root
        .as_ref()
        .is_some_and(|root| path.starts_with(root))
    {
        st.vault_root = Some(navigator::find_vault_root(path));
        st.vault_items.clear();
    }
    let scan_root = if st.is_nav_visible && st.vault_items.is_empty() {
        st.vault_root.clone()
    } else {
        None
    };
    if let Some(sender) = &st.render_sender {
        let _ = sender.send(RenderRequest {
            generation: st.generation,
            path: path.to_path_buf(),
            preserve_scroll,
            dialect: st.dialect,
            explicit: st.is_dialect_explicit,
            theme: if st.theme == "system" {
                if st.system_dark { "dark" } else { "light" }.to_string()
            } else {
                st.theme.clone()
            },
            diagrams: st.enable_diagrams,
            scan_root,
        });
    }
    let _ = (webview, window);
}
fn apply_document(
    webview: &wry::WebView,
    window: &tao::window::Window,
    st: &mut AppState,
    ready: PreparedDocument,
    proxy: &tao::event_loop::EventLoopProxy<UserEvent>,
) {
    if ready.generation != st.generation || st.current_file.as_ref() != Some(&ready.path) {
        return;
    }
    let PreparedDocument {
        path,
        preserve_scroll,
        title: window_title,
        base: base_url,
        doc,
        dialect: effective_dialect,
        vault,
        ..
    } = ready;
    if let Some((root, items)) = vault {
        if st.vault_root.as_ref() == Some(&root) {
            st.vault_items = items;
        }
    }

    st.effective_dialect = effective_dialect;
    window.set_title(&window_title);
    st.current_title = window_title;

    let vault_name = st
        .vault_root
        .as_ref()
        .and_then(|r| r.file_name())
        .map(|f| f.to_string_lossy().to_string())
        .unwrap_or_else(|| "Workspace".to_string());
    let cur_path_str = path.to_string_lossy().replace('\\', "/");
    let fragment = st.pending_fragment.take();

    let payload = serde_json::json!({
        "generation": st.generation,
        "bodyHtml": doc.body,
        "toc": doc.toc,
        "vaultName": vault_name,
        "vaultItems": st.vault_items,
        "currentPath": cur_path_str,
        "baseUrl": base_url.unwrap_or_default(),
        "canBack": st.history.can_go_back(),
        "canFwd": st.history.can_go_forward(),
        "preserveScroll": preserve_scroll,
        "fragment": fragment,
    });

    st.last_rendered = Some(doc);
    if let Ok(json_str) = serde_json::to_string(&payload) {
        let script = format!("window.__mdvuUpdateDocument?.({json_str});");
        let _ = webview.evaluate_script(&script);
    }
    inject_needed_runtimes(webview, st, proxy);
}

#[cfg(windows)]
fn sync_win32_menu(hwnd: windows_sys::Win32::Foundation::HWND, st: &AppState) {
    unsafe {
        win32::update_menu_state(
            hwnd,
            st.effective_dialect,
            st.is_dialect_explicit,
            &st.theme,
            st.full_width,
            st.is_toc_visible,
            st.is_nav_visible,
            st.history.can_go_back(),
            st.history.can_go_forward(),
        );
    }
}

#[cfg(windows)]
fn find_latest_webview2_dir(base: &Path) -> Option<PathBuf> {
    if !base.exists() {
        return None;
    }
    if let Ok(entries) = fs::read_dir(base) {
        let mut dirs: Vec<PathBuf> = entries
            .flatten()
            .map(|e| e.path())
            .filter(|p| {
                p.is_dir()
                    && (p.join("msedgewebview2.exe").exists()
                        || p.join("msedge.exe").exists()
                        || p.join("EmbeddedBrowserWebView.dll").exists())
            })
            .collect();
        dirs.sort();
        return dirs.pop();
    }
    None
}

fn get_webview2_user_data_dir() -> PathBuf {
    if let Ok(custom) = std::env::var("WEBVIEW2_USER_DATA_FOLDER") {
        if !custom.trim().is_empty() {
            let p = PathBuf::from(custom.trim());
            let _ = fs::create_dir_all(&p);
            return p;
        }
    }

    let base = if let Ok(local_app_data) = std::env::var("LOCALAPPDATA") {
        PathBuf::from(local_app_data)
    } else if let Ok(user_profile) = std::env::var("USERPROFILE") {
        PathBuf::from(user_profile).join("AppData").join("Local")
    } else {
        std::env::temp_dir()
    };

    let dir = base.join("MDVu").join("WebView2");
    let _ = fs::create_dir_all(&dir);
    dir
}

#[cfg(windows)]
fn ensure_webview2_runtime_env() {
    // A different site keeps the DOM-bound engines off the reading renderer's
    // thread while retaining the shared browser/GPU process and data folder.
    let isolation = "--isolate-origins=http://mdvu-diagram.localhost --disable-background-timer-throttling --disable-renderer-backgrounding";
    let arguments = std::env::var("WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS").unwrap_or_default();
    if !arguments.contains("--isolate-origins=http://mdvu-diagram.localhost") {
        std::env::set_var(
            "WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS",
            format!("{arguments} {isolation}"),
        );
    }
    // 1. Mandatory user data folder configuration:
    // When mdvu is installed in C:\Program Files\MDVu, default UDF creation (<exe_dir>\<exe>.WebView2)
    // fails with E_ACCESSDENIED (0x80070005) for standard users. We redirect UDF to %LOCALAPPDATA%\MDVu\WebView2.
    let user_data = get_webview2_user_data_dir();
    std::env::set_var("WEBVIEW2_USER_DATA_FOLDER", &user_data);

    // 2. Discover WebView2 browser executable folder if not already explicitly configured
    if std::env::var_os("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER").is_none() {
        if let Ok(exe_path) = std::env::current_exe() {
            if let Some(parent) = exe_path.parent() {
                for candidate in ["webview2", "runtime"] {
                    let dir = parent.join(candidate);
                    if dir.join("msedgewebview2.exe").exists() {
                        std::env::set_var("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", dir);
                        return;
                    }
                }
            }
        }

        if let Ok(userprofile) = std::env::var("USERPROFILE") {
            let scoop_wv2 = PathBuf::from(&userprofile).join("scoop\\apps\\webview2\\current");
            if scoop_wv2.join("msedgewebview2.exe").exists() {
                std::env::set_var("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", scoop_wv2);
                return;
            }
        }

        let global_scoop = PathBuf::from(r"C:\ProgramData\scoop\apps\webview2\current");
        if global_scoop.join("msedgewebview2.exe").exists() {
            std::env::set_var("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", global_scoop);
            return;
        }

        // Check per-user EdgeWebView
        if let Ok(localappdata) = std::env::var("LOCALAPPDATA") {
            let edge_wv = PathBuf::from(localappdata).join(r"Microsoft\EdgeWebView\Application");
            if let Some(dir) = find_latest_webview2_dir(&edge_wv) {
                std::env::set_var("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", dir);
                return;
            }
        }

        // Check system-wide Evergreen WebView2 Runtime in Program Files (x86) and Program Files
        let pf_candidates = [
            std::env::var("ProgramFiles(x86)").ok(),
            std::env::var("ProgramFiles").ok(),
            Some(r"C:\Program Files (x86)".to_string()),
            Some(r"C:\Program Files".to_string()),
        ];

        for pf in pf_candidates.into_iter().flatten() {
            let edge_wv = PathBuf::from(&pf).join(r"Microsoft\EdgeWebView\Application");
            if let Some(dir) = find_latest_webview2_dir(&edge_wv) {
                std::env::set_var("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", dir);
                return;
            }
        }

        // Fallback: Check Microsoft Edge browser (Stable, Beta, Dev, Canary)
        for pf in [
            std::env::var("ProgramFiles(x86)").ok(),
            std::env::var("ProgramFiles").ok(),
            Some(r"C:\Program Files (x86)".to_string()),
            Some(r"C:\Program Files".to_string()),
        ]
        .into_iter()
        .flatten()
        {
            for edge_channel in [
                r"Microsoft\Edge\Application",
                r"Microsoft\Edge Dev\Application",
                r"Microsoft\Edge Beta\Application",
                r"Microsoft\Edge Canary\Application",
            ] {
                let edge_app = PathBuf::from(&pf).join(edge_channel);
                if let Some(dir) = find_latest_webview2_dir(&edge_app) {
                    std::env::set_var("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", dir);
                    return;
                }
            }
        }
    }
}

#[cfg(not(windows))]
fn ensure_webview2_runtime_env() {}

fn run_gui(args: Args) -> Result<(), Box<dyn std::error::Error>> {
    let startup = Instant::now();
    let metrics_file = std::env::var_os("MDVU_METRICS_FILE").map(PathBuf::from);
    let gui_smoke = std::env::var_os("MDVU_GUI_SMOKE").is_some();
    let ui_script =
        std::env::var_os("MDVU_UI_SCRIPT").and_then(|path| fs::read_to_string(path).ok());
    let ui_result = std::env::var_os("MDVU_UI_RESULT_FILE").map(PathBuf::from);
    let startup_folder = args.input.as_ref().filter(|path| path.is_dir()).cloned();
    let clean_dialect = args.dialect.trim().to_ascii_lowercase();
    let is_dialect_explicit = clean_dialect != "auto" && clean_dialect != "automatic";
    let dialect = MarkdownDialect::from_str_name(&args.dialect).unwrap_or(MarkdownDialect::Generic);
    let theme = args.theme;
    let full_width = args.full_width;
    let nav_requested = args.navigator;
    let enable_diagrams = !args.no_mermaid;

    let (initial_file, initial_vault_root, initial_vault_items, is_nav_visible) = match args.input {
        Some(ref p) if p.is_dir() => {
            let root = dunce::canonicalize(p).unwrap_or_else(|_| p.clone());
            let items = Vec::new();
            let first_md = None;
            (first_md, Some(root), items, true)
        }
        Some(ref p) if p.exists() => {
            let file = dunce::canonicalize(p).unwrap_or_else(|_| p.clone());
            let root = navigator::find_vault_root(&file);
            let items = Vec::new();
            (Some(file), Some(root), items, nav_requested)
        }
        _ => (None, None, Vec::new(), nav_requested),
    };

    let mut history = NavigationHistory::new();
    if let Some(ref f) = initial_file {
        history.record(f.clone());
    }

    let state = Arc::new(Mutex::new(AppState {
        render_sender: None,
        generation: 0,
        system_dark: false,
        current_file: initial_file.clone(),
        pending_fragment: None,
        vault_root: initial_vault_root,
        vault_items: initial_vault_items,
        current_title: "mdvu".to_string(),
        zoom_level: ZoomPolicy::DEFAULT_ZOOM,
        last_toggle: Instant::now() - Duration::from_secs(1),
        last_rendered: None,
        dialect,
        effective_dialect: dialect,
        is_dialect_explicit,
        enable_diagrams,
        theme,
        full_width,
        is_toc_visible: initial_file.is_some(),
        is_nav_visible,
        history,
        katex_injected: false,
        mermaid_injected: false,
        plantuml_injected: false,
    }));

    let (initial_html, initial_title) = {
        let mut st = state.lock().unwrap();
        let (html, title, doc) = build_gui_page(None, &mut st);
        st.current_title = title.clone();
        st.last_rendered = doc;
        (html, title)
    };

    let event_loop: EventLoop<UserEvent> = EventLoopBuilder::<UserEvent>::with_user_event().build();
    let proxy = event_loop.create_proxy();
    let (render_tx, render_rx) = channel::<RenderRequest>();
    state.lock().unwrap().render_sender = Some(render_tx);
    let render_proxy = proxy.clone();
    std::thread::spawn(move || {
        while let Ok(mut request) = render_rx.recv() {
            for newer in render_rx.try_iter() {
                request = newer;
            }
            let (title, base, doc, dialect) = read_document(
                &request.path,
                request.dialect,
                request.explicit,
                &request.theme,
                request.diagrams,
            );
            let vault = request.scan_root.map(|root| {
                let items = navigator::scan_directory_tree(&root, 6);
                (root, items)
            });
            let _ = render_proxy.send_event(UserEvent::DocumentReady(Box::new(PreparedDocument {
                generation: request.generation,
                path: request.path,
                preserve_scroll: request.preserve_scroll,
                title,
                base,
                doc,
                dialect,
                vault,
            })));
        }
    });

    let window = WindowBuilder::new()
        .with_title(&initial_title)
        .with_inner_size(LogicalSize::new(1120.0, 800.0))
        .with_min_inner_size(LogicalSize::new(460.0, 360.0))
        .build(&event_loop)?;

    #[cfg(windows)]
    let hwnd = {
        use tao::platform::windows::WindowExtWindows;
        use windows_sys::Win32::UI::WindowsAndMessaging::{
            DrawMenuBar, SetForegroundWindow, ShowWindow, SW_SHOWNORMAL,
        };
        let h = window.hwnd() as windows_sys::Win32::Foundation::HWND;
        unsafe {
            let st = state.lock().unwrap();
            win32::apply_window_icon(h);
            win32::apply_dark_mode(h, &st.theme);
            win32::create_main_menu(
                h,
                st.effective_dialect,
                st.is_dialect_explicit,
                &st.theme,
                st.full_width,
                st.is_toc_visible,
                st.is_nav_visible,
                st.history.can_go_back(),
                st.history.can_go_forward(),
            );
            win32::attach_menu_subclass(h, proxy.clone());
            DrawMenuBar(h);
            ShowWindow(h, SW_SHOWNORMAL);
            SetForegroundWindow(h);
        }
        h
    };

    let proxy_ipc = proxy.clone();
    let proxy_nav = proxy.clone();
    let user_data_dir = get_webview2_user_data_dir();
    let shell_path = user_data_dir.join(format!("shell-{}.html", std::process::id()));
    fs::write(&shell_path, &initial_html)?;
    let shell_url = url::Url::from_file_path(&shell_path)
        .map_err(|_| "Invalid shell file path")?
        .to_string();
    let allowed_shell_url = shell_url.clone();
    let web_context = Box::leak(Box::new(wry::WebContext::new(Some(user_data_dir))));
    let handle_message = move |msg: &str| {
        if let Some(json) = msg.strip_prefix("diagram_render:") {
            let _ = proxy_ipc.send_event(UserEvent::DiagramRequest(json.to_owned()));
        } else if msg == "diagram_cancel" {
            let _ = proxy_ipc.send_event(UserEvent::DiagramCancel);
        } else if let Some(json) = msg.strip_prefix("ui_test:") {
            let _ = proxy_ipc.send_event(UserEvent::UiTestResult(json.to_string()));
        } else if let Some(json) = msg.strip_prefix("article_ready:") {
            let _ = proxy_ipc.send_event(UserEvent::ArticleReady(json.to_string()));
        } else if gui_smoke && msg.starts_with("smoke_result:") {
            let _ = proxy_ipc.send_event(UserEvent::SmokeResult(msg[13..].to_string()));
        } else if let Some(theme) = msg.strip_prefix("system_theme:") {
            let _ = proxy_ipc.send_event(UserEvent::SystemThemeChanged(theme == "dark"));
        } else if msg == "shell_ready" {
            let _ = proxy_ipc.send_event(UserEvent::ShellReady);
        } else if msg == "trigger_open_file" || msg == "open" {
            let _ = proxy_ipc.send_event(UserEvent::TriggerOpenFile);
        } else if msg == "trigger_open_folder" {
            let _ = proxy_ipc.send_event(UserEvent::TriggerOpenFolder);
        } else if let Some(path_str) = msg.strip_prefix("open_path:") {
            let p = PathBuf::from(path_str);
            let _ = proxy_ipc.send_event(UserEvent::OpenFile(p));
        } else if let Some(rel_str) = msg.strip_prefix("open_rel_path:") {
            let _ = proxy_ipc.send_event(UserEvent::OpenRelativePath(rel_str.to_string()));
        } else if let Some(ext_url) = msg.strip_prefix("open_external:") {
            let _ = proxy_ipc.send_event(UserEvent::OpenExternal(ext_url.to_string()));
        } else if let Some(cache_json) = msg.strip_prefix("cache_diagram:") {
            if let Ok(entry) = serde_json::from_str::<DiagramCacheMsg>(cache_json) {
                DiagramCache::global().write(&entry.key, &entry.svg);
            }
        } else if let Some(zoom_str) = msg.strip_prefix("set_zoom:") {
            let _ = proxy_ipc.send_event(UserEvent::SetZoom(zoom_str.to_string()));
        } else if msg == "go_back" {
            let _ = proxy_ipc.send_event(UserEvent::GoBack);
        } else if msg == "go_forward" {
            let _ = proxy_ipc.send_event(UserEvent::GoForward);
        } else if msg == "toggle_toc" {
            let _ = proxy_ipc.send_event(UserEvent::ToggleTOC);
        } else if msg == "toggle_nav" {
            let _ = proxy_ipc.send_event(UserEvent::ToggleNav);
        } else if msg == "toggle_full_width" {
            let _ = proxy_ipc.send_event(UserEvent::ToggleFullWidth);
        } else if msg == "zoom_in" {
            let _ = proxy_ipc.send_event(UserEvent::ZoomIn);
        } else if msg == "zoom_out" {
            let _ = proxy_ipc.send_event(UserEvent::ZoomOut);
        } else if msg == "zoom_reset" {
            let _ = proxy_ipc.send_event(UserEvent::ZoomReset);
        } else if msg == "reload" {
            let _ = proxy_ipc.send_event(UserEvent::FileChanged);
        } else if msg == "toggle_fullscreen" {
            let _ = proxy_ipc.send_event(UserEvent::ToggleFullscreen);
        } else if msg == "close_window" {
            let _ = proxy_ipc.send_event(UserEvent::Exit);
        }
    };
    let builder = WebViewBuilder::with_web_context(web_context)
        .with_hotkeys_zoom(false)
        .with_url(&shell_url)
        .with_navigation_handler(move |uri: String| {
            let lower = uri.to_ascii_lowercase();
            if uri == "about:srcdoc" || uri.split('#').next() == Some(allowed_shell_url.as_str()) {
                return true;
            }
            if lower.starts_with("http://")
                || lower.starts_with("https://")
                || lower.starts_with("mailto:")
            {
                let _ = proxy_nav.send_event(UserEvent::OpenExternal(uri));
                return false;
            }
            if lower.starts_with("file://") {
                if let Ok(url) = url::Url::parse(&uri) {
                    if let Ok(p) = url.to_file_path() {
                        if navigator::is_markdown_file(&p) {
                            let _ = proxy_nav.send_event(UserEvent::OpenFileWithFragment(
                                p,
                                url.fragment().map(|s| s.to_string()),
                            ));
                        }
                    }
                }
                return false;
            }
            false
        });
    #[cfg(windows)]
    let builder = builder.with_initialization_script(
        "window.ipc={postMessage:message=>window.chrome.webview.postMessage(message)};window.__mdvuNativeDiagramTransport={post:job=>window.ipc.postMessage('diagram_render:'+JSON.stringify(job)),cancel:()=>window.ipc.postMessage('diagram_cancel')};",
    );
    #[cfg(not(windows))]
    let builder = builder.with_ipc_handler(move |request| handle_message(request.body()));
    let webview = match builder.with_devtools(cfg!(debug_assertions)).build(&window) {
        Ok(wv) => {
            window.set_visible(true);
            window.set_focus();
            wv
        }
        Err(err) => {
            #[cfg(windows)]
            unsafe {
                use windows_sys::Win32::UI::WindowsAndMessaging::{
                    MessageBoxW, IDYES, MB_ICONERROR, MB_YESNO,
                };
                let title = win32::to_wide_null("mdvu - WebView2 Runtime Required");
                let err_msg = err.to_string();
                let text = win32::to_wide_null(&format!(
                    "Microsoft Edge WebView2 Runtime is required to display Markdown documents in mdvu.\n\n\
                    Error details:\n{err_msg}\n\n\
                    Would you like to open the official Microsoft download page to install or update it now?"
                ));
                if MessageBoxW(hwnd, text.as_ptr(), title.as_ptr(), MB_YESNO | MB_ICONERROR)
                    == IDYES
                {
                    win32::open_url_in_browser("https://go.microsoft.com/fwlink/p/?LinkId=2124703");
                }
            }
            return Err(err.into());
        }
    };

    #[cfg(windows)]
    win32::attach_web_message_handler(&webview, &shell_url, handle_message)?;

    #[cfg(windows)]
    let mut diagram_worker = diagram_worker::DiagramWorker::default();

    // Setup file watcher with trailing-edge debounce (150ms) so multi-step saves never drop final writes
    let watcher_state = Arc::clone(&state);
    let mut watcher: Option<RecommendedWatcher> = {
        let proxy_clone = proxy.clone();
        let (tx, rx) = channel();
        match RecommendedWatcher::new(
            tx,
            notify::Config::default().with_poll_interval(Duration::from_millis(200)),
        ) {
            Ok(mut w) => {
                if let Some(ref path) = initial_file {
                    watch_target(&mut w, path);
                }

                std::thread::spawn(move || {
                    let mut pending_reload = false;
                    loop {
                        let timeout = if pending_reload {
                            Duration::from_millis(150)
                        } else {
                            Duration::from_secs(3600)
                        };
                        match rx.recv_timeout(timeout) {
                            Ok(Ok(event)) => {
                                if matches!(
                                    event.kind,
                                    notify::EventKind::Modify(_) | notify::EventKind::Create(_)
                                ) {
                                    let matched = if let Ok(st) = watcher_state.lock() {
                                        if let Some(ref cur) = st.current_file {
                                            let cur_name = cur.file_name();
                                            event.paths.is_empty()
                                                || event.paths.iter().any(|p| {
                                                    p == cur
                                                        || (cur_name.is_some()
                                                            && p.file_name() == cur_name)
                                                })
                                        } else {
                                            false
                                        }
                                    } else {
                                        true
                                    };
                                    if matched {
                                        pending_reload = true;
                                    }
                                }
                            }
                            Ok(Err(_)) => {}
                            Err(RecvTimeoutError::Timeout) => {
                                if pending_reload {
                                    pending_reload = false;
                                    let _ = proxy_clone.send_event(UserEvent::FileChanged);
                                }
                            }
                            Err(RecvTimeoutError::Disconnected) => break,
                        }
                    }
                });

                Some(w)
            }
            Err(err) => {
                eprintln!("Warning: Failed to initialize file watcher: {err}");
                None
            }
        }
    };

    let mut modifiers = ModifiersState::default();

    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::Wait;

        match event {
            TaoEvent::UserEvent(user_event) => match user_event {
                UserEvent::DiagramRequest(json) => {
                    #[cfg(windows)]
                    if let Some(result) = diagram_worker.submit(&json, &window, web_context, &proxy) { let _ = webview.evaluate_script(&format!("window.__mdvuDiagramResult?.({result});void 0")); }
                    #[cfg(not(windows))] let _ = json;
                }
                UserEvent::DiagramCancel => { #[cfg(windows)] diagram_worker.cancel(); }
                UserEvent::DiagramMessage(json) => {
                    #[cfg(windows)]
                    if let Some(result) = diagram_worker.message(&json, &proxy) { let _ = webview.evaluate_script(&format!("window.__mdvuDiagramResult?.({result});void 0")); }
                    #[cfg(not(windows))] let _ = json;
                }
                UserEvent::DiagramRuntimeReady(id, source) => {
                    #[cfg(windows)]
                    if let Some(result) = diagram_worker.runtime_ready(&id, source) { let _ = webview.evaluate_script(&format!("window.__mdvuDiagramResult?.({result});void 0")); }
                    #[cfg(not(windows))] let _ = (id, source);
                }
                UserEvent::ShellReady => {
                    let mut st = state.lock().unwrap();
                    st.katex_injected = false;
                    st.mermaid_injected = false;
                    st.plantuml_injected = false;
                    if let Some(folder) = &startup_folder { if st.current_file.is_none() { let _ = proxy.send_event(UserEvent::OpenFolder(folder.clone())); } }
                    if let Some(path) = st.current_file.clone() { update_webview_document(&webview, &window, &mut st, &path, false); }
                }
                UserEvent::UiTestResult(json) => {
                    if let Some(path) = &ui_result {
                        if let Ok(mut result) = serde_json::from_str::<serde_json::Value>(&json) {
                            #[cfg(windows)]
                            if result["idleProbe"] == true {
                                let released = !diagram_worker.has_renderer();
                                result["checks"]["rendererReleased"] = serde_json::json!(released);
                                if !released { result["passed"] = serde_json::json!(false); }
                            }
                            result["allRenderedMs"] = serde_json::json!(startup.elapsed().as_secs_f64()*1000.0);
                            let _ = fs::write(path, result.to_string());
                        }
                    }
                }
                UserEvent::ArticleReady(json) => {
                    if let Some(path) = &metrics_file {
                        if let Ok(mut metrics) = serde_json::from_str::<serde_json::Value>(&json) {
                            if metrics["generation"].as_u64() == Some(state.lock().unwrap().generation) {
                                metrics["documentReadyMs"] = serde_json::json!(startup.elapsed().as_secs_f64()*1000.0);
                                let _ = fs::write(path, metrics.to_string());
                            }
                        }
                    }
                }
                UserEvent::SmokeResult(json) => {
                    attach_console();
                    let result: serde_json::Value = serde_json::from_str(&json).unwrap_or_default();
                    let passed = ["ready", "safe", "large", "image", "toc", "diagrams", "isolated"].iter().all(|key| result[key] == true);
                    println!("GUI smoke: {json}");
                    let _ = fs::remove_file(&shell_path);
                    *control_flow = ControlFlow::ExitWithCode(if passed { 0 } else { 1 });
                }
                UserEvent::SystemThemeChanged(dark) => {
                    let mut st = state.lock().unwrap(); st.system_dark = dark;
                    if st.theme == "system" {
                        #[cfg(windows)] unsafe { win32::apply_dark_mode(hwnd, if dark { "dark" } else { "light" }); }
                        if let Some(path) = st.current_file.clone() { update_webview_document(&webview, &window, &mut st, &path, true); }
                    }
                }
                UserEvent::DocumentReady(ready) => {
                    let mut st = state.lock().unwrap();
                    let current = ready.generation == st.generation;
                    apply_document(&webview, &window, &mut st, *ready, &proxy);
                    if current { if let Some(script) = &ui_script { let _ = webview.evaluate_script(script); } }
                    if gui_smoke && current {
                        let _ = webview.evaluate_script(r#"setTimeout(async()=>{window.__mdvuInitArticle();await window.__mdvuRenderDiagrams({all:true});window.ipc.postMessage('smoke_result:'+JSON.stringify({ready:typeof window.__mdvuUpdateDocument==='function',safe:window.auditExecuted!==true,large:document.querySelector('article').innerHTML.length>2097152,image:document.getElementById('smoke-img')?.naturalWidth>0,toc:document.getElementById('target-heading')!==null,diagrams:document.querySelectorAll('figure.diagram-rendered').length===2&&!document.querySelector('.diagram-error'),isolated:!window.mermaid&&!window.PlantUML}));},1000);"#);
                    }
                    #[cfg(windows)] sync_win32_menu(hwnd, &st);
                }
                UserEvent::RuntimeReady(name, result) => {
                    let mut st = state.lock().unwrap();
                    let success = result.ok().is_some_and(|js| webview.evaluate_script(js).is_ok());
                    if !success { match name { "katex" => st.katex_injected = false, "mermaid" => st.mermaid_injected = false, _ => st.plantuml_injected = false } }
                    let _ = webview.evaluate_script("window.__mdvuRenderMath?.(); window.__mdvuRenderDiagrams?.();");
                }
                UserEvent::FolderReady(root, items, first) => {
                    let mut st = state.lock().unwrap();
                    if st.vault_root.as_ref() != Some(&root) { return; }
                    st.vault_items = items;
                    drop(st);
                    if let Some(path) = first { let _ = proxy.send_event(UserEvent::OpenFile(path)); }
                    else {
                        let items = serde_json::to_string(&state.lock().unwrap().vault_items).unwrap_or_default();
                        let _ = webview.evaluate_script(&format!("window.__mdvuUpdateDocument?.({{bodyHtml:'<p>No Markdown files found</p>',toc:[],vaultItems:{items}}});"));
                    }
                }
                UserEvent::TriggerOpenFile => {
                    #[cfg(windows)]
                    if let Some(path) = win32::prompt_open_file() {
                        let _ = proxy.send_event(UserEvent::OpenFile(path));
                    }
                }
                UserEvent::TriggerOpenFolder => {
                    #[cfg(windows)]
                    if let Some(folder) = win32::prompt_open_folder() {
                        let _ = proxy.send_event(UserEvent::OpenFolder(folder));
                    }
                }
                UserEvent::OpenExternal(url) => {
                    open_external_url(&url);
                }
                UserEvent::OpenRelativePath(raw_rel) => {
                    let (rel_path, frag) = split_path_and_fragment(&raw_rel);
                    let frag_owned = frag.map(|s| s.to_string());
                    let resolved = {
                        let st = state.lock().unwrap();
                        st.current_file
                            .as_ref()
                            .and_then(|cur| cur.parent())
                            .map(|dir| dir.join(rel_path))
                            .or_else(|| st.vault_root.as_ref().map(|root| root.join(rel_path)))
                    };
                    if let Some(p) = resolved {
                        let _ = proxy.send_event(UserEvent::OpenFileWithFragment(p, frag_owned));
                    }
                }
                UserEvent::OpenFolder(folder) => {
                    let mut st = state.lock().unwrap();
                    let canonical = dunce::canonicalize(&folder).unwrap_or(folder);
                    if let Some(ref mut w) = watcher { if let Some(old) = &st.current_file { unwatch_target(w, old); } }
                    st.generation += 1;
                    st.current_file = None;
                    st.vault_items.clear();
                    st.vault_root = Some(canonical.clone());
                    st.is_nav_visible = true;
                    let _ = webview.evaluate_script("window.__mdvuToggleNavSidebar?.(true);");
                    let proxy = proxy.clone();
                    std::thread::spawn(move || {
                        let items = navigator::scan_directory_tree(&canonical, 6);
                        let first = navigator::find_first_markdown(&canonical);
                        let _ = proxy.send_event(UserEvent::FolderReady(canonical, items, first));
                    });
                }

                UserEvent::FileChanged => {
                    let mut st = state.lock().unwrap();
                    if let Some(path) = st.current_file.clone() {
                        update_webview_document(&webview, &window, &mut st, &path, true);
                        #[cfg(windows)]
                        sync_win32_menu(hwnd, &st);
                    }
                }
                UserEvent::OpenFile(new_path) => {
                    let _ = proxy.send_event(UserEvent::OpenFileWithFragment(new_path, None));
                }
                UserEvent::OpenFileWithFragment(new_path, fragment) => {
                    let mut st = state.lock().unwrap();
                    let canonical = dunce::canonicalize(&new_path).unwrap_or(new_path);

                    if let Some(ref mut w) = watcher {
                        if let Some(ref old_path) = st.current_file {
                            unwatch_target(w, old_path);
                        }
                        watch_target(w, &canonical);
                    }

                    let needs_scan = match st.vault_root {
                        Some(ref root) => !canonical.starts_with(root),
                        None => true,
                    };
                    if needs_scan {
                        let root = navigator::find_vault_root(&canonical);
                        st.vault_items.clear();
                        st.vault_root = Some(root);
                    }

                    let had_file = st.current_file.is_some();
                    st.history.record(canonical.clone());
                    st.current_file = Some(canonical.clone());
                    st.pending_fragment = fragment;

                    if !had_file && !st.is_toc_visible {
                        st.is_toc_visible = true;
                        let _ = webview.evaluate_script("window.__mdvuToggleTOCSidebar?.(true);");
                    }

                    update_webview_document(&webview, &window, &mut st, &canonical, false);

                    #[cfg(windows)]
                    sync_win32_menu(hwnd, &st);
                }
                UserEvent::GoBack => {
                    let mut st = state.lock().unwrap();
                    if let Some(prev) = st.history.go_back().cloned() {
                        if let Some(ref mut w) = watcher {
                            if let Some(ref old_path) = st.current_file {
                                unwatch_target(w, old_path);
                            }
                            watch_target(w, &prev);
                        }
                        st.current_file = Some(prev.clone());
                        update_webview_document(&webview, &window, &mut st, &prev, false);

                        #[cfg(windows)]
                        sync_win32_menu(hwnd, &st);
                    }
                }
                UserEvent::GoForward => {
                    let mut st = state.lock().unwrap();
                    if let Some(next) = st.history.go_forward().cloned() {
                        if let Some(ref mut w) = watcher {
                            if let Some(ref old_path) = st.current_file {
                                unwatch_target(w, old_path);
                            }
                            watch_target(w, &next);
                        }
                        st.current_file = Some(next.clone());
                        update_webview_document(&webview, &window, &mut st, &next, false);

                        #[cfg(windows)]
                        sync_win32_menu(hwnd, &st);
                    }
                }
                UserEvent::ToggleTOC => {
                    let mut st = state.lock().unwrap();
                    if st.last_toggle.elapsed() < Duration::from_millis(60) {
                        return;
                    }
                    st.last_toggle = Instant::now();
                    st.is_toc_visible = !st.is_toc_visible;
                    let vis = st.is_toc_visible;
                    let _ = webview.evaluate_script(&format!("window.__mdvuToggleTOCSidebar?.({vis});"));
                    #[cfg(windows)]
                    sync_win32_menu(hwnd, &st);
                }
                UserEvent::ToggleNav => {
                    let mut st = state.lock().unwrap();
                    if st.last_toggle.elapsed() < Duration::from_millis(60) {
                        return;
                    }
                    st.last_toggle = Instant::now();
                    st.is_nav_visible = !st.is_nav_visible;
                    if st.is_nav_visible && st.vault_items.is_empty() {
                        if let Some(path) = st.current_file.clone() { update_webview_document(&webview, &window, &mut st, &path, true); }
                    }
                    let vis = st.is_nav_visible;
                    let _ = webview.evaluate_script(&format!("window.__mdvuToggleNavSidebar?.({vis});"));
                    #[cfg(windows)]
                    sync_win32_menu(hwnd, &st);
                }
                UserEvent::ToggleFullWidth => {
                    let mut st = state.lock().unwrap();
                    if st.last_toggle.elapsed() < Duration::from_millis(60) {
                        return;
                    }
                    st.last_toggle = Instant::now();
                    st.full_width = !st.full_width;
                    let fw = st.full_width;
                    let _ = webview.evaluate_script(&format!("window.__mdvuToggleFullWidth?.({fw});"));
                    #[cfg(windows)]
                    sync_win32_menu(hwnd, &st);
                }
                UserEvent::SetDialectAuto => {
                    let mut st = state.lock().unwrap();
                    st.dialect = MarkdownDialect::Generic;
                    st.is_dialect_explicit = false;
                    if let Some(path) = st.current_file.clone() {
                        update_webview_document(&webview, &window, &mut st, &path, true);
                    }
                    #[cfg(windows)]
                    sync_win32_menu(hwnd, &st);
                }
                UserEvent::SetDialect(dialect) => {
                    let mut st = state.lock().unwrap();
                    st.dialect = dialect;
                    st.effective_dialect = dialect;
                    st.is_dialect_explicit = true;
                    if let Some(path) = st.current_file.clone() {
                        update_webview_document(&webview, &window, &mut st, &path, true);
                    }
                    #[cfg(windows)]
                    sync_win32_menu(hwnd, &st);
                }
                UserEvent::SetTheme(theme) => {
                    let mut st = state.lock().unwrap();
                    st.theme = theme.clone();
                    #[cfg(windows)]
                    unsafe {
                        win32::apply_dark_mode(hwnd, &st.theme);
                    }
                    let _ = webview.evaluate_script(&format!("window.__mdvuSetTheme?.({theme:?});"));
                    if let Some(path) = st.current_file.clone() {
                        update_webview_document(&webview, &window, &mut st, &path, true);
                    }
                    #[cfg(windows)]
                    sync_win32_menu(hwnd, &st);
                }
                UserEvent::ZoomIn => {
                    let mut st = state.lock().unwrap();
                    st.zoom_level = ZoomPolicy::next_step(st.zoom_level);
                    let label = ZoomPolicy::format_percentage(st.zoom_level);
                    let _ = webview.evaluate_script(&format!(
                        "window.__mdvuSetZoom?.({}, {label:?});",
                        st.zoom_level
                    ));
                }
                UserEvent::ZoomOut => {
                    let mut st = state.lock().unwrap();
                    st.zoom_level = ZoomPolicy::previous_step(st.zoom_level);
                    let label = ZoomPolicy::format_percentage(st.zoom_level);
                    let _ = webview.evaluate_script(&format!(
                        "window.__mdvuSetZoom?.({}, {label:?});",
                        st.zoom_level
                    ));
                }
                UserEvent::ZoomReset => {
                    let mut st = state.lock().unwrap();
                    st.zoom_level = ZoomPolicy::DEFAULT_ZOOM;
                    let _ = webview.evaluate_script("window.__mdvuSetZoom?.(1.0, '100%');");
                }
                UserEvent::SetZoom(raw_input) => {
                    let mut st = state.lock().unwrap();
                    st.zoom_level = ZoomPolicy::parse_manual_input(&raw_input, st.zoom_level);
                    let label = ZoomPolicy::format_percentage(st.zoom_level);
                    let _ = webview.evaluate_script(&format!(
                        "window.__mdvuSetZoom?.({}, {label:?});",
                        st.zoom_level
                    ));
                }
                UserEvent::Find => {
                    let _ = webview.evaluate_script("window.__mdvuFocusFind?.();");
                }
                UserEvent::FindNext => {
                    let _ = webview.evaluate_script("window.__mdvuFindNext?.();");
                }
                UserEvent::FindPrev => {
                    let _ = webview.evaluate_script("window.__mdvuFindPrev?.();");
                }
                UserEvent::EditUndo => {
                    let _ = webview.evaluate_script("document.execCommand('undo');");
                }
                UserEvent::EditRedo => {
                    let _ = webview.evaluate_script("document.execCommand('redo');");
                }
                UserEvent::EditCut => {
                    let _ = webview.evaluate_script("document.execCommand('cut');");
                }
                UserEvent::EditCopy => {
                    let _ = webview.evaluate_script("document.execCommand('copy');");
                }
                UserEvent::EditPaste => {
                    let _ = webview.evaluate_script("document.execCommand('paste');");
                }
                UserEvent::EditSelectAll => {
                    let _ = webview.evaluate_script("document.execCommand('selectAll');");
                }
                UserEvent::ToggleFullscreen => {
                    let is_fullscreen = window.fullscreen().is_some();
                    window.set_fullscreen(if is_fullscreen {
                        None
                    } else {
                        Some(tao::window::Fullscreen::Borderless(None))
                    });
                }
                UserEvent::ShowAbout => {
                    let _ = webview.evaluate_script("window.__mdvuShowAbout?.();");
                }
                UserEvent::OpenRepo => {
                    open_external_url("https://github.com/stpork/mdvu");
                }
                UserEvent::Exit => {
                    let _ = fs::remove_file(&shell_path);
                    *control_flow = ControlFlow::Exit;
                }
            },

            TaoEvent::WindowEvent { event: win_event, .. } => match win_event {
                WindowEvent::CloseRequested => {
                    let _ = fs::remove_file(&shell_path);
                    *control_flow = ControlFlow::Exit;
                }
                WindowEvent::DroppedFile(path) => {
                    if path.is_dir() {
                        let _ = proxy.send_event(UserEvent::OpenFolder(path));
                    } else {
                        let _ = proxy.send_event(UserEvent::OpenFile(path));
                    }
                }
                WindowEvent::MouseInput {
                    state: ElementState::Released,
                    button,
                    ..
                } => match button {
                    MouseButton::Other(1) => {
                        let _ = proxy.send_event(UserEvent::GoBack);
                    }
                    MouseButton::Other(2) => {
                        let _ = proxy.send_event(UserEvent::GoForward);
                    }
                    _ => {}
                },
                WindowEvent::ModifiersChanged(new_mods) => {
                    modifiers = new_mods;
                }
                WindowEvent::KeyboardInput { event: key_event, .. } if key_event.state == ElementState::Pressed => {
                        let is_ctrl = modifiers.control_key() || modifiers.super_key();
                        let is_shift = modifiers.shift_key();
                        let is_alt = modifiers.alt_key();

                        match key_event.physical_key {
                            KeyCode::F5 => {
                                let _ = proxy.send_event(UserEvent::FileChanged);
                            }
                            KeyCode::F11 => {
                                let _ = proxy.send_event(UserEvent::ToggleFullscreen);
                            }
                            KeyCode::F3 => {
                                if is_shift {
                                    let _ = proxy.send_event(UserEvent::FindPrev);
                                } else {
                                    let _ = proxy.send_event(UserEvent::FindNext);
                                }
                            }
                            KeyCode::KeyG if is_ctrl => {
                                if is_shift {
                                    let _ = proxy.send_event(UserEvent::FindPrev);
                                } else {
                                    let _ = proxy.send_event(UserEvent::FindNext);
                                }
                            }
                            KeyCode::KeyO if is_ctrl => {
                                if is_shift {
                                    let _ = proxy.send_event(UserEvent::TriggerOpenFolder);
                                } else {
                                    let _ = proxy.send_event(UserEvent::TriggerOpenFile);
                                }
                            }
                            KeyCode::KeyR if is_ctrl => {
                                let _ = proxy.send_event(UserEvent::FileChanged);
                            }
                            KeyCode::KeyF if is_ctrl => {
                                let _ = proxy.send_event(UserEvent::Find);
                            }
                            KeyCode::KeyB if is_ctrl && !is_shift => {
                                let _ = proxy.send_event(UserEvent::ToggleTOC);
                            }
                            KeyCode::KeyS if is_ctrl && is_shift => {
                                let _ = proxy.send_event(UserEvent::ToggleTOC);
                            }
                            KeyCode::KeyD if is_ctrl && is_shift => {
                                let _ = proxy.send_event(UserEvent::ToggleNav);
                            }
                            KeyCode::KeyW if is_ctrl => {
                                if is_shift {
                                    let _ = proxy.send_event(UserEvent::ToggleFullWidth);
                                } else {
                                    let _ = proxy.send_event(UserEvent::Exit);
                                }
                            }
                            KeyCode::Equal | KeyCode::NumpadAdd if is_ctrl => {
                                let _ = proxy.send_event(UserEvent::ZoomIn);
                            }
                            KeyCode::Minus | KeyCode::NumpadSubtract if is_ctrl => {
                                let _ = proxy.send_event(UserEvent::ZoomOut);
                            }
                            KeyCode::Digit0 | KeyCode::Numpad0 if is_ctrl => {
                                let _ = proxy.send_event(UserEvent::ZoomReset);
                            }
                            KeyCode::ArrowLeft if is_alt => {
                                let _ = proxy.send_event(UserEvent::GoBack);
                            }
                            KeyCode::ArrowRight if is_alt => {
                                let _ = proxy.send_event(UserEvent::GoForward);
                            }
                            KeyCode::BracketLeft if is_ctrl => {
                                let _ = proxy.send_event(UserEvent::GoBack);
                            }
                            KeyCode::BracketRight if is_ctrl => {
                                let _ = proxy.send_event(UserEvent::GoForward);
                            }
                            KeyCode::Escape if window.fullscreen().is_some() => {
                                window.set_fullscreen(None);
                            }
                            _ => {}
                        }
                }
                _ => {}
            },
            _ => {}
        }
        #[cfg(windows)]
        if !matches!(*control_flow, ControlFlow::ExitWithCode(_)) {
            if let Some(result) = diagram_worker.poll() { let _ = webview.evaluate_script(&format!("window.__mdvuDiagramResult?.({result});void 0")); }
            if let Some(deadline) = diagram_worker.deadline() { *control_flow = ControlFlow::WaitUntil(deadline); }
        }
        #[cfg(coverage)]
        if matches!(*control_flow, ControlFlow::ExitWithCode(_)) {
            dump_coverage_before_exit();
        }
    });
}

// Windows process::exit (also used by Tao) calls ExitProcess, bypassing the
// profiling runtime's C atexit writer. This hook exists only in coverage builds.
#[cfg(coverage)]
fn dump_coverage_before_exit() {
    unsafe extern "C" {
        fn __llvm_profile_dump() -> std::ffi::c_int;
    }
    // SAFETY: instrument-coverage links LLVM's documented, argument-free API.
    // dump marks the profile as written, preventing a second dump at C exit.
    if unsafe { __llvm_profile_dump() } != 0 {
        eprintln!("Cannot write LLVM coverage profile");
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    ensure_webview2_runtime_env();

    let args = match Args::try_parse() {
        Ok(a) => a,
        Err(err) => {
            attach_console();
            let _ = err.print();
            #[cfg(coverage)]
            dump_coverage_before_exit();
            std::process::exit(err.exit_code());
        }
    };

    if args.is_headless() {
        attach_console();
        if let Err(e) = run_headless(args) {
            eprintln!("mdvu error: {e}");
            let _ = io::stderr().flush();
            #[cfg(coverage)]
            dump_coverage_before_exit();
            std::process::exit(1);
        }
        let _ = io::stdout().flush();
        #[cfg(coverage)]
        dump_coverage_before_exit();
        std::process::exit(0);
    }

    if let Err(e) = run_gui(args) {
        attach_console();
        eprintln!("mdvu error: {e}");
        #[cfg(coverage)]
        dump_coverage_before_exit();
        std::process::exit(1);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use mdvu_core::{TocEntry, VaultItem};

    #[test]
    fn test_cli_args_mac_and_windows_parity() {
        // Test -t (macOS style) and -T (legacy Windows alias) for theme
        let a1 = Args::try_parse_from([
            "mdvu",
            "-t",
            "dark",
            "-d",
            "obsidian",
            "--full-width",
            "README.md",
        ])
        .unwrap();
        assert_eq!(a1.theme, "dark");
        assert_eq!(a1.dialect, "obsidian");
        assert!(a1.full_width);
        assert!(!a1.is_headless());

        let a2 =
            Args::try_parse_from(["mdvu", "-T", "light", "--no-mermaid", "--navigator", "docs"])
                .unwrap();
        assert_eq!(a2.theme, "light");
        assert!(a2.no_mermaid);
        assert!(a2.navigator);

        // Test headless detection
        let a_stdout = Args::try_parse_from(["mdvu", "--stdout", "README.md"]).unwrap();
        assert!(a_stdout.is_headless());

        let a_toc = Args::try_parse_from(["mdvu", "--toc", "README.md"]).unwrap();
        assert!(a_toc.is_headless());

        let a_stdin = Args::try_parse_from(["mdvu", "-"]).unwrap();
        assert!(a_stdin.is_headless());

        let a_out =
            Args::try_parse_from(["mdvu", "README.md", "-o", "out.html", "--standalone"]).unwrap();
        assert!(a_out.is_headless());
        assert!(a_out.standalone);
    }

    #[test]
    fn test_gui_shell_generation_and_features() {
        let base_html = mdvu_core::make_html_selective(
            "<h1 id=\"intro\">Introduction</h1><p>Hello world</p>",
            "Test Doc",
            "dark",
            true,
            Some("file:///C:/docs/"),
            false,
            false,
            false,
        );
        let toc = vec![TocEntry {
            level: 1,
            title: "Introduction".to_string(),
            id: "intro".to_string(),
        }];
        let vault_items = vec![VaultItem {
            name: "README.md".to_string(),
            path: "C:/docs/README.md".to_string(),
            is_dir: false,
            rel_path: Some("README.md".to_string()),
            children: None,
        }];

        let shell = gui_shell::build_gui_html(
            &base_html,
            &toc,
            "docs",
            &vault_items,
            Some("C:/docs/README.md"),
            true,
            true,
            true,
            1.2,
            true,
            false,
        );

        assert!(shell.contains("id=\"mdvu-toolbar\""));
        assert!(shell.contains("id=\"mdvu-toc-sidebar\""));
        assert!(shell.contains("id=\"mdvu-navigator-sidebar\""));
        assert!(shell.contains("id=\"mdvu-about-backdrop\""));
        assert!(shell.contains("value=\"120%\""));
        assert!(shell.contains("https://github.com/stpork/mdvu"));
        assert!(shell.contains("mailto:finndebear@gmail.com"));
        assert!(shell.contains("shell_ready"));
        assert!(shell.contains("preserveReadingAnchor"));
        assert!(shell
            .contains("<article><h1 id=\"intro\">Introduction</h1><p>Hello world</p></article>"));
    }
    #[test]
    fn shell_json_cannot_close_script_and_is_nonce_authorized() {
        let (_, doc) = mdvu_core::render_markdown(
            "# `</script><script>window.auditExecuted=true</script>`",
            None,
            MarkdownDialect::Generic,
            "light",
            false,
            None,
            false,
        );
        let html = mdvu_core::make_html_selective(
            &doc.body, "test", "light", false, None, false, false, false,
        );
        let shell = gui_shell::build_gui_html(
            &html,
            &doc.toc,
            "vault",
            &[],
            None,
            true,
            false,
            false,
            1.0,
            false,
            false,
        );
        assert!(shell.contains("\\u003c/script\\u003e"));
        assert!(!shell.contains("<script>window.auditExecuted"));
        assert!(!shell.contains("<script>"));
        if let Some(path) = std::env::var_os("MDVU_TEST_SHELL_OUTPUT") {
            std::fs::write(path, shell).unwrap();
        }
    }
}
