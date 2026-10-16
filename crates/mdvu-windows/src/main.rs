#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod gui_shell;
mod navigator;

#[cfg(windows)]
mod win32;

use clap::Parser as ClapParser;
use mdvu_core::{render_markdown, MarkdownDialect, RenderedDocument};
use notify::{RecommendedWatcher, RecursiveMode, Watcher};
use std::fs;
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::mpsc::channel;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use tao::{
    dpi::LogicalSize,
    event::{ElementState, Event as TaoEvent, WindowEvent},
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

    /// Markdown dialect: generic, obsidian, mkdocs, docusaurus, gfm, commonmark
    #[arg(short, long, default_value = "generic")]
    dialect: String,

    /// Color theme: light, dark, system
    #[arg(short = 'T', long, default_value = "system")]
    theme: String,

    /// Enable full-width view (removes article max-width)
    #[arg(long)]
    full_width: bool,

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
    use windows_sys::Win32::Foundation::INVALID_HANDLE_VALUE;
    use windows_sys::Win32::System::Console::{
        AttachConsole, GetStdHandle, SetStdHandle, ATTACH_PARENT_PROCESS,
        STD_ERROR_HANDLE, STD_INPUT_HANDLE, STD_OUTPUT_HANDLE,
    };
    unsafe {
        if AttachConsole(ATTACH_PARENT_PROCESS) != 0 {
            let out_h = GetStdHandle(STD_OUTPUT_HANDLE);
            if out_h.is_null() || out_h == INVALID_HANDLE_VALUE {
                if let Ok(file) = fs::OpenOptions::new().write(true).open("CONOUT$") {
                    SetStdHandle(STD_OUTPUT_HANDLE, file.into_raw_handle() as _);
                }
            }

            let err_h = GetStdHandle(STD_ERROR_HANDLE);
            if err_h.is_null() || err_h == INVALID_HANDLE_VALUE {
                if let Ok(file) = fs::OpenOptions::new().write(true).open("CONOUT$") {
                    SetStdHandle(STD_ERROR_HANDLE, file.into_raw_handle() as _);
                }
            }

            let in_h = GetStdHandle(STD_INPUT_HANDLE);
            if in_h.is_null() || in_h == INVALID_HANDLE_VALUE {
                if let Ok(file) = fs::File::open("CONIN$") {
                    SetStdHandle(STD_INPUT_HANDLE, file.into_raw_handle() as _);
                }
            }
        }
    }
}

#[cfg(not(windows))]
fn attach_console() {}

fn get_base_url_for_file(file_path: &Path) -> Option<String> {
    let abs_path = dunce::canonicalize(file_path).unwrap_or_else(|_| {
        if file_path.is_absolute() {
            file_path.to_path_buf()
        } else {
            std::env::current_dir()
                .map(|cwd| cwd.join(file_path))
                .unwrap_or_else(|_| file_path.to_path_buf())
        }
    });

    let dir = abs_path.parent().unwrap_or(&abs_path);
    let mut dir_str = dir.to_string_lossy().replace('\\', "/");
    if let Some(stripped) = dir_str.strip_prefix("//?/") {
        dir_str = stripped.to_string();
    }
    if !dir_str.ends_with('/') {
        dir_str.push('/');
    }
    if dir_str.starts_with('/') {
        Some(format!("file://{dir_str}"))
    } else {
        Some(format!("file:///{dir_str}"))
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

    let dialect = MarkdownDialect::from_str_name(&args.dialect).unwrap_or(MarkdownDialect::Generic);

    if args.benchmark {
        let size_bytes = content.len();
        let size_mb = size_bytes as f64 / 1_048_576.0;

        // Warmup run
        let _ = render_markdown(&content, None, dialect, &args.theme, args.full_width, base_url.as_deref(), false);

        let runs = std::env::var("MDVU_BENCHMARK_RUNS")
            .ok()
            .and_then(|s| s.parse::<usize>().ok())
            .unwrap_or(10)
            .max(1);

        let mut samples = Vec::with_capacity(runs);
        for _ in 0..runs {
            let start = Instant::now();
            let _ = render_markdown(&content, None, dialect, &args.theme, args.full_width, base_url.as_deref(), false);
            samples.push(start.elapsed().as_secs_f64() * 1000.0);
        }

        samples.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let median = samples[samples.len() / 2];
        let min = samples.first().copied().unwrap_or(0.0);
        let max = samples.last().copied().unwrap_or(0.0);
        let throughput = if median > 0.0 { size_mb / (median / 1000.0) } else { 0.0 };

        let file_name = args
            .input
            .as_ref()
            .and_then(|p| p.file_name())
            .map(|f| f.to_string_lossy().to_string())
            .unwrap_or_else(|| "stdin".to_string());
        println!("{size_mb:7.2} MB  median {median:8.2} ms (min {min:6.2} ms, max {max:6.2} ms)  {throughput:8.1} MB/s  [{file_name}]");
        let _ = io::stdout().flush();
        return Ok(());
    }

    let (html, rendered) = render_markdown(
        &content,
        args.title.as_deref(),
        dialect,
        &args.theme,
        args.full_width,
        base_url.as_deref(),
        args.standalone,
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
    FileChanged,
    OpenFile(PathBuf),
    OpenFolder(PathBuf),
    TriggerOpenFile,
    TriggerOpenFolder,
    ToggleTOC,
    ToggleNav,
    ToggleFullWidth,
    SetDialect(MarkdownDialect),
    ZoomIn,
    ZoomOut,
    ZoomReset,
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
}

#[derive(Debug, Default, Clone)]
pub struct NavigationHistory {
    pub entries: Vec<PathBuf>,
    pub index: usize,
}

impl NavigationHistory {
    pub fn new(initial: Option<PathBuf>) -> Self {
        let mut entries = Vec::new();
        if let Some(p) = initial {
            entries.push(p);
        }
        Self { entries, index: 0 }
    }

    pub fn push(&mut self, path: PathBuf) {
        if self.current() == Some(&path) {
            return;
        }
        if !self.entries.is_empty() && self.index + 1 < self.entries.len() {
            self.entries.truncate(self.index + 1);
        }
        self.entries.push(path);
        self.index = self.entries.len() - 1;
    }

    pub fn can_go_back(&self) -> bool {
        self.index > 0
    }

    pub fn can_go_forward(&self) -> bool {
        !self.entries.is_empty() && self.index + 1 < self.entries.len()
    }

    pub fn current(&self) -> Option<&PathBuf> {
        self.entries.get(self.index)
    }

    pub fn back(&mut self) -> Option<PathBuf> {
        if self.can_go_back() {
            self.index -= 1;
            Some(self.entries[self.index].clone())
        } else {
            None
        }
    }

    pub fn forward(&mut self) -> Option<PathBuf> {
        if self.can_go_forward() {
            self.index += 1;
            Some(self.entries[self.index].clone())
        } else {
            None
        }
    }
}

struct AppState {
    current_file: Option<PathBuf>,
    vault_root: Option<PathBuf>,
    vault_items: Vec<navigator::VaultItem>,
    current_title: String,
    zoom_level: f64,
    last_reload: Instant,
    last_rendered: Option<RenderedDocument>,
    dialect: MarkdownDialect,
    theme: String,
    full_width: bool,
    is_toc_visible: bool,
    is_nav_visible: bool,
    history: NavigationHistory,
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

fn build_gui_page(
    file_path: Option<&Path>,
    st: &AppState,
) -> (String, String, Option<RenderedDocument>) {
    if let Some(path) = file_path {
        let source = fs::read_to_string(path)
            .unwrap_or_else(|e| format!("# Error Opening Document\n\nFailed to read `{}`: {e}", path.display()));
        let base_url = get_base_url_for_file(path);
        let (raw_html, doc) = render_markdown(
            &source,
            None,
            st.dialect,
            &st.theme,
            st.full_width,
            base_url.as_deref(),
            false,
        );
        let title = doc
            .title
            .clone()
            .or_else(|| path.file_name().map(|f| f.to_string_lossy().to_string()))
            .unwrap_or_else(|| "MDVu".to_string());
        let window_title = format!("{title} — MDVu");

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
        let empty_article = r#"<article><div class="empty">
            <h1>MDVu</h1>
            <p style="color:var(--muted);font-size:1.15rem;margin:14px 0 24px;">Ultra-fast native Markdown viewer & offline diagram engine</p>
            <div style="display:flex;gap:12px;justify-content:center;flex-wrap:wrap;">
                <button id="mdvu-open-btn" style="padding:10px 24px;background:var(--accent);color:#fff;border:none;border-radius:8px;font-size:1rem;font-weight:600;cursor:pointer;">Open Markdown File (Ctrl+O)</button>
                <button id="mdvu-open-folder-btn" style="padding:10px 24px;background:var(--soft);color:var(--fg);border:1px solid var(--line);border-radius:8px;font-size:1rem;font-weight:600;cursor:pointer;">Open Folder / Vault (Ctrl+Shift+O)</button>
            </div>
            <p style="color:var(--muted);font-size:0.88rem;margin-top:18px;">or drag and drop a file anywhere into this window</p>
        </div></article>
        <script>
            document.getElementById('mdvu-open-btn')?.addEventListener('click', () => window.ipc?.postMessage('trigger_open_file'));
            document.getElementById('mdvu-open-folder-btn')?.addEventListener('click', () => window.ipc?.postMessage('trigger_open_folder'));
        </script>"#;

        let base_html = mdvu_core::make_html_selective(
            empty_article,
            "MDVu",
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

        (full_gui_html, "MDVu".to_string(), None)
    }
}

#[cfg(windows)]
fn ensure_webview2_runtime_env() {
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

        if let Ok(localappdata) = std::env::var("LOCALAPPDATA") {
            let edge_wv = PathBuf::from(localappdata).join(r"Microsoft\EdgeWebView\Application");
            if edge_wv.exists() {
                if let Ok(entries) = fs::read_dir(&edge_wv) {
                    for entry in entries.flatten() {
                        if entry.path().is_dir() && entry.path().join("msedgewebview2.exe").exists() {
                            std::env::set_var("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", entry.path());
                            return;
                        }
                    }
                }
            }
        }
    }
}

#[cfg(not(windows))]
fn ensure_webview2_runtime_env() {}

fn run_gui(args: Args) -> Result<(), Box<dyn std::error::Error>> {
    let dialect = MarkdownDialect::from_str_name(&args.dialect).unwrap_or(MarkdownDialect::Generic);
    let theme = args.theme;
    let full_width = args.full_width;
    let nav_requested = args.navigator;

    let (initial_file, initial_vault_root, initial_vault_items, is_nav_visible) = match args.input {
        Some(ref p) if p.is_dir() => {
            let root = dunce::canonicalize(p).unwrap_or_else(|_| p.clone());
            let items = navigator::scan_directory_tree(&root, 6);
            let first_md = navigator::find_first_markdown(&root);
            (first_md, Some(root), items, true)
        }
        Some(ref p) if p.exists() => {
            let file = dunce::canonicalize(p).unwrap_or_else(|_| p.clone());
            let root = navigator::find_vault_root(&file);
            let items = navigator::scan_directory_tree(&root, 6);
            (Some(file), Some(root), items, nav_requested)
        }
        _ => (None, None, Vec::new(), nav_requested),
    };

    let history = NavigationHistory::new(initial_file.clone());

    let state = Arc::new(Mutex::new(AppState {
        current_file: initial_file.clone(),
        vault_root: initial_vault_root,
        vault_items: initial_vault_items,
        current_title: "MDVu".to_string(),
        zoom_level: 1.0,
        last_reload: Instant::now(),
        last_rendered: None,
        dialect,
        theme,
        full_width,
        is_toc_visible: true,
        is_nav_visible,
        history,
    }));

    let (initial_html, initial_title, _initial_rendered) = {
        let mut st = state.lock().unwrap();
        let (html, title, doc) = build_gui_page(initial_file.as_deref(), &st);
        st.current_title = title.clone();
        st.last_rendered = doc.clone();
        (html, title, doc)
    };

    let event_loop: EventLoop<UserEvent> = EventLoopBuilder::<UserEvent>::with_user_event().build();
    let proxy = event_loop.create_proxy();

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
            win32::apply_dark_mode(h);
            let st = state.lock().unwrap();
            win32::create_main_menu(
                h,
                st.dialect,
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
    let webview = match WebViewBuilder::new()
        .with_html(&initial_html)
        .with_ipc_handler(move |req| {
            let msg = req.body();
            if msg == "trigger_open_file" || msg == "open" {
                let _ = proxy_ipc.send_event(UserEvent::TriggerOpenFile);
            } else if msg == "trigger_open_folder" {
                let _ = proxy_ipc.send_event(UserEvent::TriggerOpenFolder);
            } else if let Some(path_str) = msg.strip_prefix("open_path:") {
                let p = PathBuf::from(path_str);
                let _ = proxy_ipc.send_event(UserEvent::OpenFile(p));
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
            }
        })
        .with_devtools(cfg!(debug_assertions))
        .build(&window)
    {
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
                let title = win32::to_wide_null("MDVu - WebView2 Runtime Required");
                let text = win32::to_wide_null(
                    "Microsoft Edge WebView2 Runtime is required to display Markdown documents in MDVu.\n\n\
                    Would you like to open the official Microsoft download page to install it now?"
                );
                if MessageBoxW(hwnd, text.as_ptr(), title.as_ptr(), MB_YESNO | MB_ICONERROR) == IDYES {
                    win32::open_url_in_browser("https://go.microsoft.com/fwlink/p/?LinkId=2124703");
                }
            }
            return Err(err.into());
        }
    };

    // Setup file watcher
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
                    while let Ok(res) = rx.recv() {
                        if let Ok(event) = res {
                            match event.kind {
                                notify::EventKind::Modify(_)
                                | notify::EventKind::Create(_) => {
                                    let matched = if let Ok(st) = watcher_state.lock() {
                                        if let Some(ref cur) = st.current_file {
                                            let cur_name = cur.file_name();
                                            event.paths.is_empty()
                                                || event.paths.iter().any(|p| {
                                                    p == cur || (cur_name.is_some() && p.file_name() == cur_name)
                                                })
                                        } else {
                                            false
                                        }
                                    } else {
                                        true
                                    };

                                    if matched {
                                        let _ = proxy_clone.send_event(UserEvent::FileChanged);
                                    }
                                }
                                _ => {}
                            }
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
                UserEvent::OpenFolder(folder) => {
                    let mut st = state.lock().unwrap();
                    let canonical = dunce::canonicalize(&folder).unwrap_or(folder);
                    st.vault_items = navigator::scan_directory_tree(&canonical, 6);
                    st.vault_root = Some(canonical.clone());
                    st.is_nav_visible = true;

                    if let Some(first_md) = navigator::find_first_markdown(&canonical) {
                        drop(st);
                        let _ = proxy.send_event(UserEvent::OpenFile(first_md));
                    } else {
                        st.current_file = None;
                        let (new_html, title, doc) = build_gui_page(None, &st);
                        window.set_title(&title);
                        st.current_title = title;
                        st.last_rendered = doc;
                        let _ = webview.load_html(&new_html);

                        #[cfg(windows)]
                        unsafe {
                            win32::update_menu_state(
                                hwnd,
                                st.dialect,
                                st.full_width,
                                st.is_toc_visible,
                                st.is_nav_visible,
                                st.history.can_go_back(),
                                st.history.can_go_forward(),
                            );
                        }
                    }
                }
                UserEvent::FileChanged => {
                    let mut st = state.lock().unwrap();
                    if st.last_reload.elapsed() < Duration::from_millis(150) {
                        return;
                    }
                    st.last_reload = Instant::now();

                    if let Some(ref path) = st.current_file.clone() {
                        let (new_html, title, doc) = build_gui_page(Some(path), &st);
                        window.set_title(&title);
                        st.current_title = title;
                        st.last_rendered = doc;

                        let escaped_js_str = serde_json::to_string(&new_html).unwrap_or_default();
                        let script = format!(
                            r#"(function() {{
                                const prevMain = document.getElementById('mdvu-main-content');
                                const prevRatio = prevMain ? prevMain.scrollTop / (prevMain.scrollHeight || 1) : window.scrollY / (document.documentElement.scrollHeight || 1);
                                document.open();
                                document.write({escaped_js_str});
                                document.close();
                                requestAnimationFrame(() => {{
                                    const newMain = document.getElementById('mdvu-main-content');
                                    if (newMain) newMain.scrollTop = newMain.scrollHeight * prevRatio;
                                    else window.scrollTo(0, document.documentElement.scrollHeight * prevRatio);
                                }});
                            }})()"#
                        );
                        let _ = webview.evaluate_script(&script);
                    }
                }
                UserEvent::OpenFile(new_path) => {
                    let mut st = state.lock().unwrap();
                    let canonical = dunce::canonicalize(&new_path).unwrap_or(new_path);

                    if let Some(ref mut w) = watcher {
                        if let Some(ref old_path) = st.current_file {
                            unwatch_target(w, old_path);
                        }
                        watch_target(w, &canonical);
                    }

                    // If outside current vault root or no vault root, discover vault root
                    let needs_scan = match st.vault_root {
                        Some(ref root) => !canonical.starts_with(root),
                        None => true,
                    };
                    if needs_scan {
                        let root = navigator::find_vault_root(&canonical);
                        st.vault_items = navigator::scan_directory_tree(&root, 6);
                        st.vault_root = Some(root);
                    }

                    st.history.push(canonical.clone());
                    st.current_file = Some(canonical.clone());

                    let (new_html, title, doc) = build_gui_page(Some(&canonical), &st);
                    window.set_title(&title);
                    st.current_title = title;
                    st.last_rendered = doc;
                    let _ = webview.load_html(&new_html);

                    #[cfg(windows)]
                    unsafe {
                        win32::update_menu_state(
                            hwnd,
                            st.dialect,
                            st.full_width,
                            st.is_toc_visible,
                            st.is_nav_visible,
                            st.history.can_go_back(),
                            st.history.can_go_forward(),
                        );
                    }
                }
                UserEvent::GoBack => {
                    let mut st = state.lock().unwrap();
                    if let Some(prev) = st.history.back() {
                        if let Some(ref mut w) = watcher {
                            if let Some(ref old_path) = st.current_file {
                                unwatch_target(w, old_path);
                            }
                            watch_target(w, &prev);
                        }
                        st.current_file = Some(prev.clone());
                        let (new_html, title, doc) = build_gui_page(Some(&prev), &st);
                        window.set_title(&title);
                        st.current_title = title;
                        st.last_rendered = doc;
                        let _ = webview.load_html(&new_html);

                        #[cfg(windows)]
                        unsafe {
                            win32::update_menu_state(
                                hwnd,
                                st.dialect,
                                st.full_width,
                                st.is_toc_visible,
                                st.is_nav_visible,
                                st.history.can_go_back(),
                                st.history.can_go_forward(),
                            );
                        }
                        let _ = webview.evaluate_script(&format!(
                            "window.__mdvuUpdateHistory?.({}, {});",
                            st.history.can_go_back(),
                            st.history.can_go_forward()
                        ));
                    }
                }
                UserEvent::GoForward => {
                    let mut st = state.lock().unwrap();
                    if let Some(next) = st.history.forward() {
                        if let Some(ref mut w) = watcher {
                            if let Some(ref old_path) = st.current_file {
                                unwatch_target(w, old_path);
                            }
                            watch_target(w, &next);
                        }
                        st.current_file = Some(next.clone());
                        let (new_html, title, doc) = build_gui_page(Some(&next), &st);
                        window.set_title(&title);
                        st.current_title = title;
                        st.last_rendered = doc;
                        let _ = webview.load_html(&new_html);

                        #[cfg(windows)]
                        unsafe {
                            win32::update_menu_state(
                                hwnd,
                                st.dialect,
                                st.full_width,
                                st.is_toc_visible,
                                st.is_nav_visible,
                                st.history.can_go_back(),
                                st.history.can_go_forward(),
                            );
                        }
                        let _ = webview.evaluate_script(&format!(
                            "window.__mdvuUpdateHistory?.({}, {});",
                            st.history.can_go_back(),
                            st.history.can_go_forward()
                        ));
                    }
                }
                UserEvent::ToggleTOC => {
                    let mut st = state.lock().unwrap();
                    st.is_toc_visible = !st.is_toc_visible;
                    let vis = st.is_toc_visible;
                    let _ = webview.evaluate_script(&format!("window.__mdvuToggleTOCSidebar?.({vis});"));
                    #[cfg(windows)]
                    unsafe {
                        win32::update_menu_state(
                            hwnd,
                            st.dialect,
                            st.full_width,
                            st.is_toc_visible,
                            st.is_nav_visible,
                            st.history.can_go_back(),
                            st.history.can_go_forward(),
                        );
                    }
                }
                UserEvent::ToggleNav => {
                    let mut st = state.lock().unwrap();
                    st.is_nav_visible = !st.is_nav_visible;
                    let vis = st.is_nav_visible;
                    let _ = webview.evaluate_script(&format!("window.__mdvuToggleNavSidebar?.({vis});"));
                    #[cfg(windows)]
                    unsafe {
                        win32::update_menu_state(
                            hwnd,
                            st.dialect,
                            st.full_width,
                            st.is_toc_visible,
                            st.is_nav_visible,
                            st.history.can_go_back(),
                            st.history.can_go_forward(),
                        );
                    }
                }
                UserEvent::ToggleFullWidth => {
                    let mut st = state.lock().unwrap();
                    st.full_width = !st.full_width;
                    let fw = st.full_width;
                    let _ = webview.evaluate_script(&format!("window.__mdvuToggleFullWidth?.({fw});"));
                    #[cfg(windows)]
                    unsafe {
                        win32::update_menu_state(
                            hwnd,
                            st.dialect,
                            st.full_width,
                            st.is_toc_visible,
                            st.is_nav_visible,
                            st.history.can_go_back(),
                            st.history.can_go_forward(),
                        );
                    }
                }
                UserEvent::SetDialect(dialect) => {
                    let mut st = state.lock().unwrap();
                    st.dialect = dialect;
                    #[cfg(windows)]
                    unsafe {
                        win32::update_menu_state(
                            hwnd,
                            st.dialect,
                            st.full_width,
                            st.is_toc_visible,
                            st.is_nav_visible,
                            st.history.can_go_back(),
                            st.history.can_go_forward(),
                        );
                    }
                    if let Some(ref path) = st.current_file.clone() {
                        let (new_html, title, doc) = build_gui_page(Some(path), &st);
                        st.current_title = title;
                        st.last_rendered = doc;
                        let _ = webview.load_html(&new_html);
                    }
                }
                UserEvent::ZoomIn => {
                    let mut st = state.lock().unwrap();
                    st.zoom_level = (st.zoom_level + 0.10).clamp(0.2, 5.0);
                    let pct = (st.zoom_level * 100.0).round() as i32;
                    let _ = webview.evaluate_script(&format!("window.__mdvuSetZoom?.({pct});"));
                }
                UserEvent::ZoomOut => {
                    let mut st = state.lock().unwrap();
                    st.zoom_level = (st.zoom_level - 0.10).clamp(0.2, 5.0);
                    let pct = (st.zoom_level * 100.0).round() as i32;
                    let _ = webview.evaluate_script(&format!("window.__mdvuSetZoom?.({pct});"));
                }
                UserEvent::ZoomReset => {
                    let mut st = state.lock().unwrap();
                    st.zoom_level = 1.0;
                    let _ = webview.evaluate_script("window.__mdvuSetZoom?.(100);");
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
                    #[cfg(windows)]
                    unsafe {
                        win32::show_about_box(hwnd);
                    }
                }
                UserEvent::OpenRepo => {
                    #[cfg(windows)]
                    unsafe {
                        win32::open_url_in_browser("https://github.com/stpork/mdvu");
                    }
                }
                UserEvent::Exit => {
                    *control_flow = ControlFlow::Exit;
                }
            },

            TaoEvent::WindowEvent { event: win_event, .. } => match win_event {
                WindowEvent::CloseRequested => {
                    *control_flow = ControlFlow::Exit;
                }
                WindowEvent::DroppedFile(path) => {
                    if path.is_dir() {
                        let _ = proxy.send_event(UserEvent::OpenFolder(path));
                    } else {
                        let _ = proxy.send_event(UserEvent::OpenFile(path));
                    }
                }
                WindowEvent::ModifiersChanged(new_mods) => {
                    modifiers = new_mods;
                }
                WindowEvent::KeyboardInput { event: key_event, .. } => {
                    if key_event.state == ElementState::Pressed {
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
                            KeyCode::KeyB if is_ctrl => {
                                let _ = proxy.send_event(UserEvent::ToggleTOC);
                            }
                            KeyCode::KeyS if is_ctrl && is_shift => {
                                let _ = proxy.send_event(UserEvent::ToggleTOC);
                            }
                            KeyCode::KeyD if is_ctrl && is_shift => {
                                let _ = proxy.send_event(UserEvent::ToggleNav);
                            }
                            KeyCode::KeyW if is_ctrl && is_shift => {
                                let _ = proxy.send_event(UserEvent::ToggleFullWidth);
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
                            KeyCode::Escape => {
                                if window.fullscreen().is_some() {
                                    window.set_fullscreen(None);
                                }
                            }
                            _ => {}
                        }
                    }
                }
                _ => {}
            },
            _ => {}
        }
    });
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    ensure_webview2_runtime_env();

    let args = match Args::try_parse() {
        Ok(a) => a,
        Err(err) => {
            attach_console();
            let _ = err.print();
            std::process::exit(err.exit_code());
        }
    };

    if args.is_headless() {
        attach_console();
        if let Err(e) = run_headless(args) {
            eprintln!("mdvu error: {e}");
            let _ = io::stderr().flush();
            std::process::exit(1);
        }
        let _ = io::stdout().flush();
        std::process::exit(0);
    }

    if let Err(e) = run_gui(args) {
        attach_console();
        eprintln!("mdvu error: {e}");
        std::process::exit(1);
    }

    Ok(())
}
