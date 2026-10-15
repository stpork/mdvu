#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

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
use wry::{WebView, WebViewBuilder};

#[derive(ClapParser, Debug)]
#[command(name = "mdvu")]
#[command(
    about = "Ultra-fast native Markdown viewer & headless renderer",
    version = env!("CARGO_PKG_VERSION"),
    long_about = None
)]
struct Args {
    /// Input Markdown file path (reads from stdin if omitted with -o/--stdout or "-")
    #[arg(value_name = "FILE")]
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
}

impl Args {
    fn is_headless(&self) -> bool {
        self.output.is_some()
            || self.stdout
            || self.toc
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
    TriggerOpenDialog,
    ToggleTOC,
    ZoomIn,
    ZoomOut,
    ZoomReset,
    ToggleFullscreen,
    ShowAbout,
    OpenRepo,
    Exit,
}

struct AppState {
    current_file: Option<PathBuf>,
    current_title: String,
    zoom_level: f64,
    last_reload: Instant,
    last_rendered: Option<RenderedDocument>,
    dialect: MarkdownDialect,
    theme: String,
    full_width: bool,
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

fn load_document(
    file_path: &Path,
    dialect: MarkdownDialect,
    theme: &str,
    full_width: bool,
) -> Result<(String, RenderedDocument), Box<dyn std::error::Error>> {
    let source = fs::read_to_string(file_path)?;
    let base_url = get_base_url_for_file(file_path);

    let (html, rendered) = render_markdown(
        &source,
        None,
        dialect,
        theme,
        full_width,
        base_url.as_deref(),
        false,
    );

    Ok((html, rendered))
}

fn adjust_zoom(state: &Arc<Mutex<AppState>>, webview: &WebView, delta: Option<f64>) {
    let mut st = state.lock().unwrap();
    if let Some(d) = delta {
        st.zoom_level = (st.zoom_level + d).clamp(0.2, 5.0);
    } else {
        st.zoom_level = 1.0;
    }
    let zoom = st.zoom_level;
    let _ = webview.evaluate_script(&format!("document.body.style.zoom = '{zoom}';"));
}

fn prompt_open_file() -> Option<PathBuf> {
    rfd::FileDialog::new()
        .set_title("Open Markdown Document - MDVu")
        .add_filter("Markdown Files", &["md", "markdown", "mdown", "mkd", "txt"])
        .pick_file()
}

#[cfg(windows)]
fn ensure_webview2_runtime_env() {
    if std::env::var_os("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER").is_none() {
        // 1. Check adjacent runtime or webview2 directory (for portable / bundled distribution)
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

        // 2. Check user Scoop installation
        if let Ok(userprofile) = std::env::var("USERPROFILE") {
            let scoop_wv2 = PathBuf::from(&userprofile).join("scoop\\apps\\webview2\\current");
            if scoop_wv2.join("msedgewebview2.exe").exists() {
                std::env::set_var("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", scoop_wv2);
                return;
            }
        }

        // 3. Check system / global Scoop installation
        let global_scoop = PathBuf::from(r"C:\ProgramData\scoop\apps\webview2\current");
        if global_scoop.join("msedgewebview2.exe").exists() {
            std::env::set_var("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", global_scoop);
            return;
        }

        // 4. Check LocalAppData Edge WebView
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

    let initial_file: Option<PathBuf> = match args.input {
        Some(p) if p.exists() => Some(p),
        _ => None,
    };

    let event_loop: EventLoop<UserEvent> = EventLoopBuilder::<UserEvent>::with_user_event().build();
    let proxy = event_loop.create_proxy();

    let (initial_html, initial_title, initial_rendered) = if let Some(ref path) = initial_file {
        match load_document(path, dialect, &theme, full_width) {
            Ok((h, doc)) => {
                let title = doc
                    .title
                    .clone()
                    .or_else(|| path.file_name().map(|f| f.to_string_lossy().to_string()))
                    .unwrap_or_else(|| "MDVu".to_string());
                (h, format!("{title} — MDVu"), Some(doc))
            }
            Err(e) => (
                format!("<h1>Error opening document</h1><p>{e}</p>"),
                "MDVu - Error".to_string(),
                None,
            ),
        }
    } else {
        (
            mdvu_core::make_html_selective(
                r#"<div class="empty">
                    <h1>MDVu</h1>
                    <p style="color:var(--muted);font-size:1.15rem;margin:14px 0 24px;">Ultra-fast Markdown viewer & offline diagram engine</p>
                    <p><button id="mdvu-open-btn" style="padding:10px 24px;background:var(--accent);color:#fff;border:none;border-radius:8px;font-size:1rem;font-weight:600;cursor:pointer;">Open Markdown File (Ctrl+O)</button></p>
                    <p style="color:var(--muted);font-size:0.88rem;margin-top:18px;">or drag and drop a file anywhere into this window</p>
                </div>
                <script>document.getElementById('mdvu-open-btn')?.addEventListener('click', () => window.ipc.postMessage('open'));</script>"#,
                "MDVu",
                &theme,
                full_width,
                None,
                false,
                false,
                false,
            ),
            "MDVu".to_string(),
            None,
        )
    };

    let window = WindowBuilder::new()
        .with_title(&initial_title)
        .with_inner_size(LogicalSize::new(1060.0, 780.0))
        .with_min_inner_size(LogicalSize::new(420.0, 320.0))
        .build(&event_loop)?;

    #[cfg(windows)]
    {
        use tao::platform::windows::WindowExtWindows;
        use windows_sys::Win32::UI::WindowsAndMessaging::{
            DrawMenuBar, SetForegroundWindow, ShowWindow, SW_SHOWNORMAL,
        };
        let hwnd = window.hwnd() as windows_sys::Win32::Foundation::HWND;
        unsafe {
            win32::apply_dark_mode(hwnd);
            win32::create_main_menu(hwnd);
            win32::attach_menu_subclass(hwnd, proxy.clone());
            DrawMenuBar(hwnd);
            ShowWindow(hwnd, SW_SHOWNORMAL);
            SetForegroundWindow(hwnd);
        }
    }

    let proxy_ipc = proxy.clone();
    let webview = match WebViewBuilder::new()
        .with_html(&initial_html)
        .with_ipc_handler(move |req| {
            if req.body() == "open" {
                let _ = proxy_ipc.send_event(UserEvent::TriggerOpenDialog);
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
                use tao::platform::windows::WindowExtWindows;
                use windows_sys::Win32::UI::WindowsAndMessaging::{
                    MessageBoxW, IDYES, MB_ICONERROR, MB_YESNO,
                };
                let hwnd = window.hwnd() as windows_sys::Win32::Foundation::HWND;
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

    let state = Arc::new(Mutex::new(AppState {
        current_file: initial_file.clone(),
        current_title: initial_title,
        zoom_level: 1.0,
        last_reload: Instant::now(),
        last_rendered: initial_rendered,
        dialect,
        theme,
        full_width,
    }));

    // Setup file watcher with targeted file filtering
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
                UserEvent::TriggerOpenDialog => {
                    if let Some(path) = prompt_open_file() {
                        let _ = proxy.send_event(UserEvent::OpenFile(path));
                    }
                }
                UserEvent::FileChanged => {
                    let mut st = state.lock().unwrap();
                    if st.last_reload.elapsed() < Duration::from_millis(150) {
                        return;
                    }
                    st.last_reload = Instant::now();

                    if let Some(ref path) = st.current_file {
                        let d = st.dialect;
                        let t = st.theme.clone();
                        let fw = st.full_width;
                        if let Ok((new_html, doc)) = load_document(path, d, &t, fw) {
                            let title = doc
                                .title
                                .clone()
                                .or_else(|| path.file_name().map(|f| f.to_string_lossy().to_string()))
                                .unwrap_or_else(|| "MDVu".to_string());
                            let window_title = format!("{title} — MDVu");
                            window.set_title(&window_title);
                            st.current_title = window_title;

                            let escaped_js_str = serde_json::to_string(&new_html).unwrap_or_default();
                            let script = format!(
                                r#"(function() {{
                                    const prevRatio = window.scrollY / (document.documentElement.scrollHeight || 1);
                                    document.open();
                                    document.write({escaped_js_str});
                                    document.close();
                                    requestAnimationFrame(() => {{
                                        window.scrollTo(0, document.documentElement.scrollHeight * prevRatio);
                                    }});
                                }})()"#
                            );
                            let _ = webview.evaluate_script(&script);
                            st.last_rendered = Some(doc);
                        }
                    }
                }
                UserEvent::OpenFile(new_path) => {
                    let mut st = state.lock().unwrap();
                    if let Some(ref mut w) = watcher {
                        if let Some(ref old_path) = st.current_file {
                            unwatch_target(w, old_path);
                        }
                        watch_target(w, &new_path);
                    }

                    let d = st.dialect;
                    let t = st.theme.clone();
                    let fw = st.full_width;
                    match load_document(&new_path, d, &t, fw) {
                        Ok((new_html, doc)) => {
                            let title = doc
                                .title
                                .clone()
                                .or_else(|| new_path.file_name().map(|f| f.to_string_lossy().to_string()))
                                .unwrap_or_else(|| "MDVu".to_string());
                            let window_title = format!("{title} — MDVu");
                            window.set_title(&window_title);
                            st.current_file = Some(new_path);
                            st.current_title = window_title;
                            let _ = webview.load_html(&new_html);
                            st.last_rendered = Some(doc);
                        }
                        Err(e) => {
                            eprintln!("Failed to open document: {e}");
                        }
                    }
                }
                UserEvent::ToggleTOC => {
                    let _ = webview.evaluate_script("window.__mdvuToggleTOC?.();");
                }
                UserEvent::ZoomIn => {
                    adjust_zoom(&state, &webview, Some(0.10));
                }
                UserEvent::ZoomOut => {
                    adjust_zoom(&state, &webview, Some(-0.10));
                }
                UserEvent::ZoomReset => {
                    adjust_zoom(&state, &webview, None);
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
                    {
                        use tao::platform::windows::WindowExtWindows;
                        let hwnd = window.hwnd() as windows_sys::Win32::Foundation::HWND;
                        unsafe {
                            win32::show_about_box(hwnd);
                        }
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
                    let _ = proxy.send_event(UserEvent::OpenFile(path));
                }
                WindowEvent::ModifiersChanged(new_mods) => {
                    modifiers = new_mods;
                }
                WindowEvent::KeyboardInput { event: key_event, .. } => {
                    if key_event.state == ElementState::Pressed {
                        let is_ctrl_or_cmd = modifiers.control_key() || modifiers.super_key();

                        match key_event.physical_key {
                            KeyCode::F5 => {
                                let _ = proxy.send_event(UserEvent::FileChanged);
                            }
                            KeyCode::F11 => {
                                let _ = proxy.send_event(UserEvent::ToggleFullscreen);
                            }
                            KeyCode::KeyO if is_ctrl_or_cmd => {
                                let _ = proxy.send_event(UserEvent::TriggerOpenDialog);
                            }
                            KeyCode::KeyR if is_ctrl_or_cmd => {
                                let _ = proxy.send_event(UserEvent::FileChanged);
                            }
                            KeyCode::KeyB if is_ctrl_or_cmd => {
                                let _ = proxy.send_event(UserEvent::ToggleTOC);
                            }
                            KeyCode::Equal | KeyCode::NumpadAdd if is_ctrl_or_cmd => {
                                let _ = proxy.send_event(UserEvent::ZoomIn);
                            }
                            KeyCode::Minus | KeyCode::NumpadSubtract if is_ctrl_or_cmd => {
                                let _ = proxy.send_event(UserEvent::ZoomOut);
                            }
                            KeyCode::Digit0 | KeyCode::Numpad0 if is_ctrl_or_cmd => {
                                let _ = proxy.send_event(UserEvent::ZoomReset);
                            }
                            KeyCode::Escape => {
                                if window.fullscreen().is_some() {
                                    window.set_fullscreen(None);
                                } else {
                                    let _ = webview.evaluate_script("document.getElementById('mdvu-toc-panel')?.classList.remove('visible');");
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
