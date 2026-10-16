#![cfg(windows)]

use std::ffi::OsStr;
use std::os::windows::ffi::OsStrExt;
use std::path::PathBuf;
use tao::event_loop::EventLoopProxy;
use windows_sys::Win32::Foundation::{HWND, LPARAM, LRESULT, WPARAM};
use windows_sys::Win32::Graphics::Dwm::DwmSetWindowAttribute;
use windows_sys::Win32::UI::Shell::{
    DefSubclassProc, RemoveWindowSubclass, SetWindowSubclass, ShellExecuteW,
};
use windows_sys::Win32::UI::WindowsAndMessaging::*;

use crate::UserEvent;
use mdvu_core::MarkdownDialect;

// Menu IDs
pub const IDM_FILE_OPEN: usize = 1001;
pub const IDM_FILE_OPEN_FOLDER: usize = 1002;
pub const IDM_FILE_RELOAD: usize = 1003;
pub const IDM_FILE_EXIT: usize = 1004;
pub const IDM_FILE_CLOSE: usize = 1005;

pub const IDM_EDIT_UNDO: usize = 1101;
pub const IDM_EDIT_REDO: usize = 1102;
pub const IDM_EDIT_CUT: usize = 1103;
pub const IDM_EDIT_COPY: usize = 1104;
pub const IDM_EDIT_PASTE: usize = 1105;
pub const IDM_EDIT_SELECT_ALL: usize = 1106;
pub const IDM_EDIT_FIND: usize = 1107;
pub const IDM_EDIT_FIND_NEXT: usize = 1108;
pub const IDM_EDIT_FIND_PREV: usize = 1109;

pub const IDM_VIEW_RELOAD: usize = 2001;
pub const IDM_VIEW_TOGGLE_TOC: usize = 2002;
pub const IDM_VIEW_TOGGLE_NAV: usize = 2003;
pub const IDM_VIEW_FULL_WIDTH: usize = 2004;
pub const IDM_DIALECT_AUTO: usize = 2100;
pub const IDM_DIALECT_GENERIC: usize = 2101;
pub const IDM_DIALECT_GFM: usize = 2102;
pub const IDM_DIALECT_OBSIDIAN: usize = 2103;
pub const IDM_DIALECT_MKDOCS: usize = 2104;
pub const IDM_DIALECT_DOCUSAURUS: usize = 2105;
pub const IDM_DIALECT_COMMONMARK: usize = 2106;

pub const IDM_THEME_SYSTEM: usize = 2150;
pub const IDM_THEME_LIGHT: usize = 2151;
pub const IDM_THEME_DARK: usize = 2152;

pub const IDM_VIEW_ZOOM_IN: usize = 2201;
pub const IDM_VIEW_ZOOM_OUT: usize = 2202;
pub const IDM_VIEW_ZOOM_RESET: usize = 2203;
pub const IDM_VIEW_FULLSCREEN: usize = 2204;

pub const IDM_GO_BACK: usize = 3001;
pub const IDM_GO_FORWARD: usize = 3002;

pub const IDM_HELP_ABOUT: usize = 4001;
pub const IDM_HELP_REPO: usize = 4002;

pub const SUBCLASS_ID: usize = 101;

pub fn to_wide_null(s: &str) -> Vec<u16> {
    OsStr::new(s).encode_wide().chain(Some(0)).collect()
}

pub unsafe fn apply_window_icon(hwnd: HWND) {
    let hinstance = GetWindowLongPtrW(hwnd, GWLP_HINSTANCE) as *mut core::ffi::c_void;
    let big_icon = LoadImageW(
        hinstance,
        1 as *const u16,
        IMAGE_ICON,
        GetSystemMetrics(SM_CXICON),
        GetSystemMetrics(SM_CYICON),
        LR_DEFAULTCOLOR | LR_SHARED,
    );
    if !big_icon.is_null() {
        SendMessageW(hwnd, WM_SETICON, ICON_BIG as usize, big_icon as isize);
    }
    let small_icon = LoadImageW(
        hinstance,
        1 as *const u16,
        IMAGE_ICON,
        GetSystemMetrics(SM_CXSMICON),
        GetSystemMetrics(SM_CYSMICON),
        LR_DEFAULTCOLOR | LR_SHARED,
    );
    if !small_icon.is_null() {
        SendMessageW(hwnd, WM_SETICON, ICON_SMALL as usize, small_icon as isize);
    }
}

pub unsafe fn apply_dark_mode(hwnd: HWND, theme: &str) {
    let use_dark_mode: i32 = match theme.trim().to_ascii_lowercase().as_str() {
        "light" => 0,
        _ => 1,
    };
    // DWMWA_USE_IMMERSIVE_DARK_MODE = 20
    DwmSetWindowAttribute(
        hwnd,
        20,
        &use_dark_mode as *const _ as *const _,
        std::mem::size_of::<i32>() as u32,
    );
}

pub unsafe fn create_main_menu(
    hwnd: HWND,
    dialect: MarkdownDialect,
    is_dialect_explicit: bool,
    theme: &str,
    is_full_width: bool,
    is_toc: bool,
    is_nav: bool,
    can_back: bool,
    can_fwd: bool,
) {
    let menu = CreateMenu();
    let file_menu = CreatePopupMenu();
    let edit_menu = CreatePopupMenu();
    let view_menu = CreatePopupMenu();
    let dialect_menu = CreatePopupMenu();
    let theme_menu = CreatePopupMenu();
    let go_menu = CreatePopupMenu();
    let help_menu = CreatePopupMenu();

    // --- File Menu ---
    let open_file = to_wide_null("&Open File...\tCtrl+O");
    let open_folder = to_wide_null("Open &Folder / Vault...\tCtrl+Shift+O");
    let reload_text = to_wide_null("&Reload\tCtrl+R");
    let close_text = to_wide_null("&Close\tCtrl+W");
    let exit_text = to_wide_null("E&xit\tAlt+F4");

    AppendMenuW(file_menu, MF_STRING, IDM_FILE_OPEN, open_file.as_ptr());
    AppendMenuW(
        file_menu,
        MF_STRING,
        IDM_FILE_OPEN_FOLDER,
        open_folder.as_ptr(),
    );
    AppendMenuW(file_menu, MF_SEPARATOR, 0, std::ptr::null());
    AppendMenuW(file_menu, MF_STRING, IDM_FILE_RELOAD, reload_text.as_ptr());
    AppendMenuW(file_menu, MF_SEPARATOR, 0, std::ptr::null());
    AppendMenuW(file_menu, MF_STRING, IDM_FILE_CLOSE, close_text.as_ptr());
    AppendMenuW(file_menu, MF_STRING, IDM_FILE_EXIT, exit_text.as_ptr());

    // --- Edit Menu ---
    let undo_text = to_wide_null("&Undo\tCtrl+Z");
    let redo_text = to_wide_null("&Redo\tCtrl+Y");
    let cut_text = to_wide_null("Cu&t\tCtrl+X");
    let copy_text = to_wide_null("&Copy\tCtrl+C");
    let paste_text = to_wide_null("&Paste\tCtrl+V");
    let select_all_text = to_wide_null("Select &All\tCtrl+A");
    let find_text = to_wide_null("&Find...\tCtrl+F");
    let find_next_text = to_wide_null("Find &Next\tF3");
    let find_prev_text = to_wide_null("Find &Previous\tShift+F3");

    AppendMenuW(edit_menu, MF_STRING, IDM_EDIT_UNDO, undo_text.as_ptr());
    AppendMenuW(edit_menu, MF_STRING, IDM_EDIT_REDO, redo_text.as_ptr());
    AppendMenuW(edit_menu, MF_SEPARATOR, 0, std::ptr::null());
    AppendMenuW(edit_menu, MF_STRING, IDM_EDIT_CUT, cut_text.as_ptr());
    AppendMenuW(edit_menu, MF_STRING, IDM_EDIT_COPY, copy_text.as_ptr());
    AppendMenuW(edit_menu, MF_STRING, IDM_EDIT_PASTE, paste_text.as_ptr());
    AppendMenuW(
        edit_menu,
        MF_STRING,
        IDM_EDIT_SELECT_ALL,
        select_all_text.as_ptr(),
    );
    AppendMenuW(edit_menu, MF_SEPARATOR, 0, std::ptr::null());
    AppendMenuW(edit_menu, MF_STRING, IDM_EDIT_FIND, find_text.as_ptr());
    AppendMenuW(
        edit_menu,
        MF_STRING,
        IDM_EDIT_FIND_NEXT,
        find_next_text.as_ptr(),
    );
    AppendMenuW(
        edit_menu,
        MF_STRING,
        IDM_EDIT_FIND_PREV,
        find_prev_text.as_ptr(),
    );

    // --- Dialect Submenu ---
    let d_auto = to_wide_null("&Automatic");
    let d_generic = to_wide_null("&Generic (CommonMark)");
    let d_gfm = to_wide_null("Git&Hub (GFM)");
    let d_obsidian = to_wide_null("&Obsidian");
    let d_mkdocs = to_wide_null("&MkDocs");
    let d_docusaurus = to_wide_null("&Docusaurus");
    let d_commonmark = to_wide_null("&CommonMark");

    AppendMenuW(dialect_menu, MF_STRING, IDM_DIALECT_AUTO, d_auto.as_ptr());
    AppendMenuW(dialect_menu, MF_SEPARATOR, 0, std::ptr::null());
    AppendMenuW(
        dialect_menu,
        MF_STRING,
        IDM_DIALECT_GENERIC,
        d_generic.as_ptr(),
    );
    AppendMenuW(dialect_menu, MF_STRING, IDM_DIALECT_GFM, d_gfm.as_ptr());
    AppendMenuW(
        dialect_menu,
        MF_STRING,
        IDM_DIALECT_OBSIDIAN,
        d_obsidian.as_ptr(),
    );
    AppendMenuW(
        dialect_menu,
        MF_STRING,
        IDM_DIALECT_MKDOCS,
        d_mkdocs.as_ptr(),
    );
    AppendMenuW(
        dialect_menu,
        MF_STRING,
        IDM_DIALECT_DOCUSAURUS,
        d_docusaurus.as_ptr(),
    );
    AppendMenuW(
        dialect_menu,
        MF_STRING,
        IDM_DIALECT_COMMONMARK,
        d_commonmark.as_ptr(),
    );

    // --- Theme Submenu ---
    let t_system = to_wide_null("&System");
    let t_light = to_wide_null("&Light");
    let t_dark = to_wide_null("&Dark");

    AppendMenuW(theme_menu, MF_STRING, IDM_THEME_SYSTEM, t_system.as_ptr());
    AppendMenuW(theme_menu, MF_STRING, IDM_THEME_LIGHT, t_light.as_ptr());
    AppendMenuW(theme_menu, MF_STRING, IDM_THEME_DARK, t_dark.as_ptr());

    // --- View Menu ---
    let v_reload = to_wide_null("&Reload\tCtrl+R");
    let v_toc = to_wide_null("Table of &Contents\tCtrl+Shift+S");
    let v_nav = to_wide_null("File &Navigator\tCtrl+Shift+D");
    let v_fw = to_wide_null("Full &Width\tCtrl+Shift+W");
    let v_dialect = to_wide_null("&Dialect");
    let v_theme = to_wide_null("&Theme");
    let v_zoom_in = to_wide_null("Zoom &In\tCtrl++");
    let v_zoom_out = to_wide_null("Zoom &Out\tCtrl+-");
    let v_zoom_reset = to_wide_null("&Actual Size (100%)\tCtrl+0");
    let v_fs = to_wide_null("Toggle &Fullscreen\tF11");

    AppendMenuW(view_menu, MF_STRING, IDM_VIEW_RELOAD, v_reload.as_ptr());
    AppendMenuW(view_menu, MF_SEPARATOR, 0, std::ptr::null());
    AppendMenuW(view_menu, MF_STRING, IDM_VIEW_TOGGLE_TOC, v_toc.as_ptr());
    AppendMenuW(view_menu, MF_STRING, IDM_VIEW_TOGGLE_NAV, v_nav.as_ptr());
    AppendMenuW(view_menu, MF_STRING, IDM_VIEW_FULL_WIDTH, v_fw.as_ptr());
    AppendMenuW(view_menu, MF_SEPARATOR, 0, std::ptr::null());
    AppendMenuW(
        view_menu,
        MF_POPUP,
        dialect_menu as usize,
        v_dialect.as_ptr(),
    );
    AppendMenuW(view_menu, MF_POPUP, theme_menu as usize, v_theme.as_ptr());
    AppendMenuW(view_menu, MF_SEPARATOR, 0, std::ptr::null());
    AppendMenuW(view_menu, MF_STRING, IDM_VIEW_ZOOM_IN, v_zoom_in.as_ptr());
    AppendMenuW(view_menu, MF_STRING, IDM_VIEW_ZOOM_OUT, v_zoom_out.as_ptr());
    AppendMenuW(
        view_menu,
        MF_STRING,
        IDM_VIEW_ZOOM_RESET,
        v_zoom_reset.as_ptr(),
    );
    AppendMenuW(view_menu, MF_SEPARATOR, 0, std::ptr::null());
    AppendMenuW(view_menu, MF_STRING, IDM_VIEW_FULLSCREEN, v_fs.as_ptr());

    // --- Go Menu ---
    let go_back = to_wide_null("&Back\tAlt+Left");
    let go_fwd = to_wide_null("&Forward\tAlt+Right");
    AppendMenuW(go_menu, MF_STRING, IDM_GO_BACK, go_back.as_ptr());
    AppendMenuW(go_menu, MF_STRING, IDM_GO_FORWARD, go_fwd.as_ptr());

    // --- Help Menu ---
    let about_text = to_wide_null("&About MDVu");
    let repo_text = to_wide_null("&GitHub Repository");
    AppendMenuW(help_menu, MF_STRING, IDM_HELP_ABOUT, about_text.as_ptr());
    AppendMenuW(help_menu, MF_STRING, IDM_HELP_REPO, repo_text.as_ptr());

    // --- Top Menu Bar ---
    let file_title = to_wide_null("&File");
    let edit_title = to_wide_null("&Edit");
    let view_title = to_wide_null("&View");
    let go_title = to_wide_null("&Go");
    let help_title = to_wide_null("&Help");

    AppendMenuW(menu, MF_POPUP, file_menu as usize, file_title.as_ptr());
    AppendMenuW(menu, MF_POPUP, edit_menu as usize, edit_title.as_ptr());
    AppendMenuW(menu, MF_POPUP, view_menu as usize, view_title.as_ptr());
    AppendMenuW(menu, MF_POPUP, go_menu as usize, go_title.as_ptr());
    AppendMenuW(menu, MF_POPUP, help_menu as usize, help_title.as_ptr());

    SetMenu(hwnd, menu);

    // Apply initial checked / enabled state
    update_menu_state(
        hwnd,
        dialect,
        is_dialect_explicit,
        theme,
        is_full_width,
        is_toc,
        is_nav,
        can_back,
        can_fwd,
    );
}

pub unsafe fn update_menu_state(
    hwnd: HWND,
    dialect: MarkdownDialect,
    is_dialect_explicit: bool,
    theme: &str,
    is_full_width: bool,
    is_toc: bool,
    is_nav: bool,
    can_back: bool,
    can_fwd: bool,
) {
    let menu = GetMenu(hwnd);
    if menu.is_null() {
        return;
    }

    CheckMenuItem(
        menu,
        IDM_DIALECT_AUTO as u32,
        if !is_dialect_explicit {
            MF_CHECKED
        } else {
            MF_UNCHECKED
        },
    );

    // Dialect radio check
    let dialect_id = match dialect {
        MarkdownDialect::Generic => IDM_DIALECT_GENERIC,
        MarkdownDialect::Gfm => IDM_DIALECT_GFM,
        MarkdownDialect::Obsidian => IDM_DIALECT_OBSIDIAN,
        MarkdownDialect::Mkdocs => IDM_DIALECT_MKDOCS,
        MarkdownDialect::Docusaurus => IDM_DIALECT_DOCUSAURUS,
        MarkdownDialect::Commonmark => IDM_DIALECT_COMMONMARK,
        _ => IDM_DIALECT_GENERIC,
    };
    CheckMenuRadioItem(
        menu,
        IDM_DIALECT_GENERIC as u32,
        IDM_DIALECT_COMMONMARK as u32,
        dialect_id as u32,
        MF_BYCOMMAND,
    );

    // Theme radio check
    let theme_id = match theme.to_ascii_lowercase().as_str() {
        "light" => IDM_THEME_LIGHT,
        "dark" => IDM_THEME_DARK,
        _ => IDM_THEME_SYSTEM,
    };
    CheckMenuRadioItem(
        menu,
        IDM_THEME_SYSTEM as u32,
        IDM_THEME_DARK as u32,
        theme_id as u32,
        MF_BYCOMMAND,
    );

    // View toggles
    CheckMenuItem(
        menu,
        IDM_VIEW_TOGGLE_TOC as u32,
        if is_toc { MF_CHECKED } else { MF_UNCHECKED },
    );
    CheckMenuItem(
        menu,
        IDM_VIEW_TOGGLE_NAV as u32,
        if is_nav { MF_CHECKED } else { MF_UNCHECKED },
    );
    CheckMenuItem(
        menu,
        IDM_VIEW_FULL_WIDTH as u32,
        if is_full_width {
            MF_CHECKED
        } else {
            MF_UNCHECKED
        },
    );

    // Go history buttons
    EnableMenuItem(
        menu,
        IDM_GO_BACK as u32,
        if can_back { MF_ENABLED } else { MF_GRAYED },
    );
    EnableMenuItem(
        menu,
        IDM_GO_FORWARD as u32,
        if can_fwd { MF_ENABLED } else { MF_GRAYED },
    );

    DrawMenuBar(hwnd);
}

pub unsafe fn attach_menu_subclass(hwnd: HWND, proxy: EventLoopProxy<UserEvent>) {
    let proxy_ptr = Box::into_raw(Box::new(proxy));
    SetWindowSubclass(
        hwnd,
        Some(menu_subclass_proc),
        SUBCLASS_ID,
        proxy_ptr as usize,
    );
}

pub unsafe extern "system" fn menu_subclass_proc(
    hwnd: HWND,
    msg: u32,
    wparam: WPARAM,
    lparam: LPARAM,
    _uid: usize,
    ref_data: usize,
) -> LRESULT {
    if msg == WM_COMMAND {
        let cmd_id = (wparam & 0xFFFF) as usize;
        let proxy = &*(ref_data as *const EventLoopProxy<UserEvent>);
        match cmd_id {
            // File
            IDM_FILE_OPEN => {
                let _ = proxy.send_event(UserEvent::TriggerOpenFile);
                return 0;
            }
            IDM_FILE_OPEN_FOLDER => {
                let _ = proxy.send_event(UserEvent::TriggerOpenFolder);
                return 0;
            }
            IDM_FILE_RELOAD | IDM_VIEW_RELOAD => {
                let _ = proxy.send_event(UserEvent::FileChanged);
                return 0;
            }
            IDM_FILE_EXIT | IDM_FILE_CLOSE => {
                let _ = proxy.send_event(UserEvent::Exit);
                return 0;
            }

            // Edit
            IDM_EDIT_UNDO => {
                let _ = proxy.send_event(UserEvent::EditUndo);
                return 0;
            }
            IDM_EDIT_REDO => {
                let _ = proxy.send_event(UserEvent::EditRedo);
                return 0;
            }
            IDM_EDIT_CUT => {
                let _ = proxy.send_event(UserEvent::EditCut);
                return 0;
            }
            IDM_EDIT_COPY => {
                let _ = proxy.send_event(UserEvent::EditCopy);
                return 0;
            }
            IDM_EDIT_PASTE => {
                let _ = proxy.send_event(UserEvent::EditPaste);
                return 0;
            }
            IDM_EDIT_SELECT_ALL => {
                let _ = proxy.send_event(UserEvent::EditSelectAll);
                return 0;
            }
            IDM_EDIT_FIND => {
                let _ = proxy.send_event(UserEvent::Find);
                return 0;
            }
            IDM_EDIT_FIND_NEXT => {
                let _ = proxy.send_event(UserEvent::FindNext);
                return 0;
            }
            IDM_EDIT_FIND_PREV => {
                let _ = proxy.send_event(UserEvent::FindPrev);
                return 0;
            }

            // View
            IDM_VIEW_TOGGLE_TOC => {
                let _ = proxy.send_event(UserEvent::ToggleTOC);
                return 0;
            }
            IDM_VIEW_TOGGLE_NAV => {
                let _ = proxy.send_event(UserEvent::ToggleNav);
                return 0;
            }
            IDM_VIEW_FULL_WIDTH => {
                let _ = proxy.send_event(UserEvent::ToggleFullWidth);
                return 0;
            }

            // Dialects
            IDM_DIALECT_AUTO => {
                let _ = proxy.send_event(UserEvent::SetDialectAuto);
                return 0;
            }
            IDM_DIALECT_GENERIC => {
                let _ = proxy.send_event(UserEvent::SetDialect(MarkdownDialect::Generic));
                return 0;
            }
            IDM_DIALECT_GFM => {
                let _ = proxy.send_event(UserEvent::SetDialect(MarkdownDialect::Gfm));
                return 0;
            }
            IDM_DIALECT_OBSIDIAN => {
                let _ = proxy.send_event(UserEvent::SetDialect(MarkdownDialect::Obsidian));
                return 0;
            }
            IDM_DIALECT_MKDOCS => {
                let _ = proxy.send_event(UserEvent::SetDialect(MarkdownDialect::Mkdocs));
                return 0;
            }
            IDM_DIALECT_DOCUSAURUS => {
                let _ = proxy.send_event(UserEvent::SetDialect(MarkdownDialect::Docusaurus));
                return 0;
            }
            IDM_DIALECT_COMMONMARK => {
                let _ = proxy.send_event(UserEvent::SetDialect(MarkdownDialect::Commonmark));
                return 0;
            }

            // Themes
            IDM_THEME_SYSTEM => {
                let _ = proxy.send_event(UserEvent::SetTheme("system".to_string()));
                return 0;
            }
            IDM_THEME_LIGHT => {
                let _ = proxy.send_event(UserEvent::SetTheme("light".to_string()));
                return 0;
            }
            IDM_THEME_DARK => {
                let _ = proxy.send_event(UserEvent::SetTheme("dark".to_string()));
                return 0;
            }

            // Zoom
            IDM_VIEW_ZOOM_IN => {
                let _ = proxy.send_event(UserEvent::ZoomIn);
                return 0;
            }
            IDM_VIEW_ZOOM_OUT => {
                let _ = proxy.send_event(UserEvent::ZoomOut);
                return 0;
            }
            IDM_VIEW_ZOOM_RESET => {
                let _ = proxy.send_event(UserEvent::ZoomReset);
                return 0;
            }
            IDM_VIEW_FULLSCREEN => {
                let _ = proxy.send_event(UserEvent::ToggleFullscreen);
                return 0;
            }

            // Go
            IDM_GO_BACK => {
                let _ = proxy.send_event(UserEvent::GoBack);
                return 0;
            }
            IDM_GO_FORWARD => {
                let _ = proxy.send_event(UserEvent::GoForward);
                return 0;
            }

            // Help
            IDM_HELP_ABOUT => {
                let _ = proxy.send_event(UserEvent::ShowAbout);
                return 0;
            }
            IDM_HELP_REPO => {
                let _ = proxy.send_event(UserEvent::OpenRepo);
                return 0;
            }
            _ => {}
        }
    } else if msg == WM_NCDESTROY {
        RemoveWindowSubclass(hwnd, Some(menu_subclass_proc), SUBCLASS_ID);
        drop(Box::from_raw(ref_data as *mut EventLoopProxy<UserEvent>));
    }

    DefSubclassProc(hwnd, msg, wparam, lparam)
}

pub fn prompt_open_file() -> Option<PathBuf> {
    rfd::FileDialog::new()
        .set_title("Open Markdown File - MDVu")
        .add_filter("Markdown Files", &["md", "markdown", "mdown", "mkd", "txt"])
        .pick_file()
}

pub fn prompt_open_folder() -> Option<PathBuf> {
    rfd::FileDialog::new()
        .set_title("Open Markdown Folder / Vault - MDVu")
        .pick_folder()
}

pub unsafe fn open_url_in_browser(url: &str) {
    let wide_url = to_wide_null(url);
    let open_op = to_wide_null("open");
    ShellExecuteW(
        std::ptr::null_mut(),
        open_op.as_ptr(),
        wide_url.as_ptr(),
        std::ptr::null(),
        std::ptr::null(),
        SW_SHOWNORMAL,
    );
}

/// WebView2 IPC carries a browser URL, which is not necessarily an HTTP URI.
/// Bypass Wry 0.47's HTTP request adapter (it panics on file:/// URLs) and validate the source directly.
pub fn attach_web_message_handler(
    view: &wry::WebView,
    shell_url: &str,
    handler: impl Fn(&str) + 'static,
) -> Result<(), Box<dyn std::error::Error>> {
    use webview2_com::{take_pwstr, WebMessageReceivedEventHandler};
    use windows::core::PWSTR;
    use wry::WebViewExtWindows;
    let expected = url::Url::parse(shell_url)?;
    unsafe {
        let webview = view.controller().CoreWebView2()?;
        let mut token = Default::default();
        webview.add_WebMessageReceived(
            &WebMessageReceivedEventHandler::create(Box::new(move |_, args| {
                let Some(args) = args else { return Ok(()) };
                let mut source = PWSTR::null();
                args.Source(&mut source)?;
                let source = take_pwstr(source);
                let Ok(mut source) = url::Url::parse(&source) else {
                    return Ok(());
                };
                source.set_fragment(None);
                if source != expected {
                    return Ok(());
                }
                let mut message = PWSTR::null();
                args.TryGetWebMessageAsString(&mut message)?;
                handler(&take_pwstr(message));
                Ok(())
            })),
            &mut token,
        )?;
    }
    Ok(())
}
