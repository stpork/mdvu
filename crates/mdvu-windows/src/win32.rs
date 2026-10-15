#![cfg(windows)]

use std::ffi::OsStr;
use std::os::windows::ffi::OsStrExt;
use windows_sys::Win32::Foundation::{HWND, LPARAM, WPARAM};
use windows_sys::Win32::Graphics::Dwm::DwmSetWindowAttribute;
use windows_sys::Win32::UI::Controls::*;
use windows_sys::Win32::UI::WindowsAndMessaging::*;

pub const IDM_FILE_OPEN: usize = 1001;
pub const IDM_FILE_RELOAD: usize = 1002;
pub const IDM_FILE_EXIT: usize = 1003;
pub const IDM_VIEW_TOGGLE_TOC: usize = 2001;
pub const IDM_VIEW_ZOOM_IN: usize = 2002;
pub const IDM_VIEW_ZOOM_OUT: usize = 2003;
pub const IDM_VIEW_ZOOM_RESET: usize = 2004;
pub const IDM_VIEW_FULLSCREEN: usize = 2005;

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

    let open_text = to_wide_null("&Open...\tCtrl+O");
    let reload_text = to_wide_null("&Reload\tF5");
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

    let file_title = to_wide_null("&File");
    let view_title = to_wide_null("&View");

    AppendMenuW(menu, MF_POPUP, file_menu as usize, file_title.as_ptr());
    AppendMenuW(menu, MF_POPUP, view_menu as usize, view_title.as_ptr());

    SetMenu(hwnd, menu);
}

pub unsafe fn create_status_bar(hwnd: HWND) -> HWND {
    let mut icex = INITCOMMONCONTROLSEX {
        dwSize: std::mem::size_of::<INITCOMMONCONTROLSEX>() as u32,
        dwICC: ICC_BAR_CLASSES,
    };
    InitCommonControlsEx(&mut icex);

    let status_bar = CreateWindowExW(
        0,
        STATUSCLASSNAMEW,
        std::ptr::null(),
        WS_CHILD | WS_VISIBLE | SBARS_SIZEGRIP,
        0,
        0,
        0,
        0,
        hwnd,
        std::ptr::null_mut(),
        std::ptr::null_mut(),
        std::ptr::null(),
    );

    let parts = [300, 420, -1];
    SendMessageW(
        status_bar,
        SB_SETPARTS,
        parts.len() as WPARAM,
        parts.as_ptr() as LPARAM,
    );

    let ready_text = to_wide_null("Ready");
    let zoom_text = to_wide_null("Zoom: 100%");
    let offline_text = to_wide_null("Offline Engine: Active");

    SendMessageW(status_bar, SB_SETTEXTW, 0, ready_text.as_ptr() as LPARAM);
    SendMessageW(status_bar, SB_SETTEXTW, 1, zoom_text.as_ptr() as LPARAM);
    SendMessageW(status_bar, SB_SETTEXTW, 2, offline_text.as_ptr() as LPARAM);

    status_bar
}
