#![cfg(windows)]

use std::ffi::OsStr;
use std::os::windows::ffi::OsStrExt;
use tao::event_loop::EventLoopProxy;
use windows_sys::Win32::Foundation::{HWND, LPARAM, LRESULT, WPARAM};
use windows_sys::Win32::Graphics::Dwm::DwmSetWindowAttribute;
use windows_sys::Win32::UI::Shell::{DefSubclassProc, RemoveWindowSubclass, SetWindowSubclass, ShellExecuteW};
use windows_sys::Win32::UI::WindowsAndMessaging::*;

use crate::UserEvent;

pub const IDM_FILE_OPEN: usize = 1001;
pub const IDM_FILE_RELOAD: usize = 1002;
pub const IDM_FILE_EXIT: usize = 1003;
pub const IDM_VIEW_TOGGLE_TOC: usize = 2001;
pub const IDM_VIEW_ZOOM_IN: usize = 2002;
pub const IDM_VIEW_ZOOM_OUT: usize = 2003;
pub const IDM_VIEW_ZOOM_RESET: usize = 2004;
pub const IDM_VIEW_FULLSCREEN: usize = 2005;
pub const IDM_HELP_ABOUT: usize = 3001;
pub const IDM_HELP_REPO: usize = 3002;

pub const SUBCLASS_ID: usize = 101;

pub fn to_wide_null(s: &str) -> Vec<u16> {
    OsStr::new(s).encode_wide().chain(Some(0)).collect()
}

pub unsafe fn apply_dark_mode(hwnd: HWND) {
    let use_dark_mode: i32 = 1;
    // DWMWA_USE_IMMERSIVE_DARK_MODE = 20
    DwmSetWindowAttribute(
        hwnd,
        20,
        &use_dark_mode as *const _ as *const _,
        std::mem::size_of::<i32>() as u32,
    );
}

pub unsafe fn create_main_menu(hwnd: HWND) {
    let menu = CreateMenu();
    let file_menu = CreatePopupMenu();
    let view_menu = CreatePopupMenu();
    let help_menu = CreatePopupMenu();

    let open_text = to_wide_null("&Open...\tCtrl+O");
    let reload_text = to_wide_null("&Reload\tCtrl+R");
    let exit_text = to_wide_null("E&xit\tAlt+F4");

    AppendMenuW(file_menu, MF_STRING, IDM_FILE_OPEN, open_text.as_ptr());
    AppendMenuW(file_menu, MF_STRING, IDM_FILE_RELOAD, reload_text.as_ptr());
    AppendMenuW(file_menu, MF_SEPARATOR, 0, std::ptr::null());
    AppendMenuW(file_menu, MF_STRING, IDM_FILE_EXIT, exit_text.as_ptr());

    let toc_text = to_wide_null("Toggle Table of Contents\tCtrl+B");
    let zoom_in = to_wide_null("Zoom &In\tCtrl++");
    let zoom_out = to_wide_null("Zoom &Out\tCtrl+-");
    let zoom_reset = to_wide_null("&Reset Zoom (100%)\tCtrl+0");
    let fs_text = to_wide_null("&Toggle Fullscreen\tF11");

    AppendMenuW(view_menu, MF_STRING, IDM_VIEW_TOGGLE_TOC, toc_text.as_ptr());
    AppendMenuW(view_menu, MF_SEPARATOR, 0, std::ptr::null());
    AppendMenuW(view_menu, MF_STRING, IDM_VIEW_ZOOM_IN, zoom_in.as_ptr());
    AppendMenuW(view_menu, MF_STRING, IDM_VIEW_ZOOM_OUT, zoom_out.as_ptr());
    AppendMenuW(view_menu, MF_STRING, IDM_VIEW_ZOOM_RESET, zoom_reset.as_ptr());
    AppendMenuW(view_menu, MF_SEPARATOR, 0, std::ptr::null());
    AppendMenuW(view_menu, MF_STRING, IDM_VIEW_FULLSCREEN, fs_text.as_ptr());

    let about_text = to_wide_null("&About MDVu");
    let repo_text = to_wide_null("&GitHub Repository");
    AppendMenuW(help_menu, MF_STRING, IDM_HELP_ABOUT, about_text.as_ptr());
    AppendMenuW(help_menu, MF_STRING, IDM_HELP_REPO, repo_text.as_ptr());

    let file_title = to_wide_null("&File");
    let view_title = to_wide_null("&View");
    let help_title = to_wide_null("&Help");

    AppendMenuW(menu, MF_POPUP, file_menu as usize, file_title.as_ptr());
    AppendMenuW(menu, MF_POPUP, view_menu as usize, view_title.as_ptr());
    AppendMenuW(menu, MF_POPUP, help_menu as usize, help_title.as_ptr());

    SetMenu(hwnd, menu);
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
            IDM_FILE_OPEN => {
                let _ = proxy.send_event(UserEvent::TriggerOpenDialog);
                return 0;
            }
            IDM_FILE_RELOAD => {
                let _ = proxy.send_event(UserEvent::FileChanged);
                return 0;
            }
            IDM_FILE_EXIT => {
                let _ = proxy.send_event(UserEvent::Exit);
                return 0;
            }
            IDM_VIEW_TOGGLE_TOC => {
                let _ = proxy.send_event(UserEvent::ToggleTOC);
                return 0;
            }
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

pub unsafe fn show_about_box(hwnd: HWND) {
    let title = to_wide_null("About MDVu");
    let version = env!("CARGO_PKG_VERSION");
    let msg = format!(
        "MDVu v{version}\nUltra-fast native Markdown viewer\nSingle-binary, zero bloat, offline diagrams & math.\n\nhttps://github.com/stpork/mdvu"
    );
    let text = to_wide_null(&msg);
    MessageBoxW(hwnd, text.as_ptr(), title.as_ptr(), MB_OK | MB_ICONINFORMATION);
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
