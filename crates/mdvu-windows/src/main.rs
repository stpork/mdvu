#[cfg(windows)]
mod win32;

use mdvu_core::{render_markdown, MarkdownDialect, RenderedDocument};
use notify::{Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::mpsc::{channel, Receiver};
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

#[derive(Debug)]
enum UserEvent {
    FileChanged,
    OpenFile(PathBuf),
    ToggleTOC,
}

struct AppState {
    current_file: Option<PathBuf>,
    current_title: String,
    zoom_level: f64,
    last_reload: Instant,
    last_rendered: Option<RenderedDocument>,
    toc_visible: bool,
}

fn load_document(file_path: &Path) -> Result<(String, RenderedDocument), Box<dyn std::error::Error>> {
    let source = fs::read_to_string(file_path)?;
    let abs_path = fs::canonicalize(file_path).unwrap_or_else(|_| file_path.to_path_buf());
    let base_url = format!("file://{}", abs_path.display());

    // embed_diagram_engines is false: we inject engines lazily on demand
    let (html, rendered) = render_markdown(
        &source,
        None,
        MarkdownDialect::Generic,
        "system",
        false,
        Some(&base_url),
        false,
    );

    Ok((html, rendered))
}

fn inject_engines_if_needed(webview: &WebView, doc: &RenderedDocument) {
    if doc.has_math {
        if let Ok(katex) = mdvu_core::get_katex_js() {
            let escaped_js = serde_json::to_string(katex).unwrap_or_default();
            let script = format!(
                r#"(function() {{
                    if (!window.__katexLoaded) {{
                        const s = document.createElement('script');
                        s.textContent = {escaped_js};
                        document.head.appendChild(s);
                        window.__katexLoaded = true;
                    }}
                    window.__mdvuRenderMath?.();
                }})();"#
            );
            let _ = webview.evaluate_script(&script);
        }
    }

    if doc.has_mermaid {
        if let Ok(mermaid) = mdvu_core::get_mermaid_js() {
            let escaped_js = serde_json::to_string(mermaid).unwrap_or_default();
            let script = format!(
                r#"(function() {{
                    if (!window.__mermaidLoaded) {{
                        const s = document.createElement('script');
                        s.textContent = {escaped_js};
                        document.head.appendChild(s);
                        window.__mermaidLoaded = true;
                    }}
                    window.__mdvuRenderDiagrams?.();
                }})();"#
            );
            let _ = webview.evaluate_script(&script);
        }
    }

    if doc.has_plantuml {
        if let Ok(plantuml) = mdvu_core::get_plantuml_js() {
            let escaped_js = serde_json::to_string(plantuml).unwrap_or_default();
            let script = format!(
                r#"(function() {{
                    if (!window.__plantumlLoaded) {{
                        const s = document.createElement('script');
                        s.textContent = {escaped_js};
                        document.head.appendChild(s);
                        window.__plantumlLoaded = true;
                    }}
                    window.__mdvuRenderDiagrams?.();
                }})();"#
            );
            let _ = webview.evaluate_script(&script);
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    let initial_file: Option<PathBuf> = if args.len() > 1 {
        let p = PathBuf::from(&args[1]);
        if p.exists() {
            Some(p)
        } else {
            None
        }
    } else {
        rfd::FileDialog::new()
            .set_title("Open Markdown Document - MDVu")
            .add_filter("Markdown Files", &["md", "markdown", "mdown", "mkd", "txt"])
            .pick_file()
    };

    let event_loop: EventLoop<UserEvent> = EventLoopBuilder::<UserEvent>::with_user_event().build();
    let proxy = event_loop.create_proxy();

    let (initial_html, initial_title, initial_rendered) = if let Some(ref path) = initial_file {
        match load_document(path) {
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
            r#"<div style="text-align:center;margin-top:20vh;font-family:sans-serif;">
                <h1>MDVu</h1>
                <p style="color:#666;">No file opened. Press <b>Ctrl+O</b> to open a Markdown file.</p>
            </div>"#
                .to_string(),
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
        let hwnd = window.hwnd() as isize;
        unsafe {
            win32::apply_dark_mode(hwnd);
            win32::create_main_menu(hwnd);
            win32::create_status_bar(hwnd);
        }
    }

    let webview = WebViewBuilder::new()
        .with_html(&initial_html)
        .with_devtools(cfg!(debug_assertions))
        .build(&window)?;

    // Lazy injection for initial document
    if let Some(ref doc) = initial_rendered {
        inject_engines_if_needed(&webview, doc);
    }

    let state = Arc::new(Mutex::new(AppState {
        current_file: initial_file.clone(),
        current_title: initial_title,
        zoom_level: 1.0,
        last_reload: Instant::now(),
        last_rendered: initial_rendered,
        toc_visible: true,
    }));

    // Setup file watcher
    let (tx_watch, rx_watch): (
        std::sync::mpsc::Sender<notify::Result<Event>>,
        Receiver<notify::Result<Event>>,
    ) = channel();
    let mut watcher: Option<RecommendedWatcher> =
        match RecommendedWatcher::new(tx_watch, notify::Config::default()) {
            Ok(mut w) => {
                if let Some(ref p) = initial_file {
                    let _ = w.watch(p, RecursiveMode::NonRecursive);
                }
                Some(w)
            }
            Err(err) => {
                eprintln!("Warning: Failed to initialize file watcher: {err}");
                None
            }
        };

    // Background thread to relay file modification events
    let proxy_clone = proxy.clone();
    std::thread::spawn(move || {
        while let Ok(event_res) = rx_watch.recv() {
            if let Ok(event) = event_res {
                match event.kind {
                    EventKind::Modify(_) | EventKind::Create(_) => {
                        let _ = proxy_clone.send_event(UserEvent::FileChanged);
                    }
                    _ => {}
                }
            }
        }
    });

    let mut modifiers = ModifiersState::empty();

    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::Wait;

        match event {
            TaoEvent::UserEvent(user_event) => match user_event {
                UserEvent::FileChanged => {
                    let mut st = state.lock().unwrap();
                    if st.last_reload.elapsed() < Duration::from_millis(150) {
                        return;
                    }
                    st.last_reload = Instant::now();

                    if let Some(ref path) = st.current_file {
                        if let Ok((new_html, doc)) = load_document(path) {
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
                            inject_engines_if_needed(&webview, &doc);
                            st.last_rendered = Some(doc);
                        }
                    }
                }
                UserEvent::OpenFile(new_path) => {
                    let mut st = state.lock().unwrap();
                    if let Some(ref mut w) = watcher {
                        if let Some(ref old_path) = st.current_file {
                            let _ = w.unwatch(old_path);
                        }
                        let _ = w.watch(&new_path, RecursiveMode::NonRecursive);
                    }

                    match load_document(&new_path) {
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
                            inject_engines_if_needed(&webview, &doc);
                            st.last_rendered = Some(doc);
                        }
                        Err(e) => {
                            eprintln!("Failed to open document: {e}");
                        }
                    }
                }
                UserEvent::ToggleTOC => {
                    let mut st = state.lock().unwrap();
                    st.toc_visible = !st.toc_visible;
                }
            },

            TaoEvent::WindowEvent { event: win_event, .. } => match win_event {
                WindowEvent::CloseRequested => {
                    *control_flow = ControlFlow::Exit;
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
                                let is_fullscreen = window.fullscreen().is_some();
                                window.set_fullscreen(if is_fullscreen {
                                    None
                                } else {
                                    Some(tao::window::Fullscreen::Borderless(None))
                                });
                            }
                            KeyCode::KeyO if is_ctrl_or_cmd => {
                                if let Some(path) = rfd::FileDialog::new()
                                    .set_title("Open Markdown Document")
                                    .add_filter("Markdown Files", &["md", "markdown", "mdown", "mkd", "txt"])
                                    .pick_file()
                                {
                                    let _ = proxy.send_event(UserEvent::OpenFile(path));
                                }
                            }
                            KeyCode::KeyR if is_ctrl_or_cmd => {
                                let _ = proxy.send_event(UserEvent::FileChanged);
                            }
                            KeyCode::KeyB if is_ctrl_or_cmd => {
                                let _ = proxy.send_event(UserEvent::ToggleTOC);
                            }
                            KeyCode::Equal | KeyCode::NumpadAdd if is_ctrl_or_cmd => {
                                let mut st = state.lock().unwrap();
                                st.zoom_level = (st.zoom_level + 0.10).min(5.0);
                                let zoom = st.zoom_level;
                                let _ = webview.evaluate_script(&format!(
                                    "document.body.style.zoom = '{zoom}';"
                                ));
                            }
                            KeyCode::Minus | KeyCode::NumpadSubtract if is_ctrl_or_cmd => {
                                let mut st = state.lock().unwrap();
                                st.zoom_level = (st.zoom_level - 0.10).max(0.2);
                                let zoom = st.zoom_level;
                                let _ = webview.evaluate_script(&format!(
                                    "document.body.style.zoom = '{zoom}';"
                                ));
                            }
                            KeyCode::Digit0 | KeyCode::Numpad0 if is_ctrl_or_cmd => {
                                let mut st = state.lock().unwrap();
                                st.zoom_level = 1.0;
                                let _ = webview.evaluate_script("document.body.style.zoom = '1.0';");
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
