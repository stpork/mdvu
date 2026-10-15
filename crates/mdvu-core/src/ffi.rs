use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use crate::assets::{get_katex_c_str, get_mermaid_c_str, get_plantuml_c_str};
use crate::parser::MarkdownParser;
use crate::pipeline::{MarkdownDialect, MarkdownPipeline};
use crate::template::make_html;

pub struct MdvuDocument {
    html: CString,
    body: CString,
    title: CString,
    toc_json: CString,
    has_mermaid: bool,
    has_plantuml: bool,
    has_math: bool,
}

unsafe fn c_str_to_rust<'a>(ptr: *const c_char) -> Option<&'a str> {
    if ptr.is_null() {
        None
    } else {
        CStr::from_ptr(ptr).to_str().ok()
    }
}

#[no_mangle]
pub extern "C" fn mdvu_version() -> *const c_char {
    static VERSION: &str = concat!(env!("CARGO_PKG_VERSION"), "\0");
    VERSION.as_ptr() as *const c_char
}

#[no_mangle]
pub extern "C" fn mdvu_get_mermaid_js() -> *const c_char {
    match get_mermaid_c_str() {
        Some(s) => s.as_ptr(),
        None => std::ptr::null(),
    }
}

#[no_mangle]
pub extern "C" fn mdvu_get_plantuml_js() -> *const c_char {
    match get_plantuml_c_str() {
        Some(s) => s.as_ptr(),
        None => std::ptr::null(),
    }
}

#[no_mangle]
pub extern "C" fn mdvu_get_katex_js() -> *const c_char {
    match get_katex_c_str() {
        Some(s) => s.as_ptr(),
        None => std::ptr::null(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn mdvu_render_to_html(
    source: *const c_char,
    title_override: *const c_char,
    dialect_str: *const c_char,
    theme_str: *const c_char,
    full_width: bool,
    base_url: *const c_char,
    embed_engines: bool,
) -> *mut MdvuDocument {
    let source_str = match c_str_to_rust(source) {
        Some(s) => s,
        None => return std::ptr::null_mut(),
    };

    let dialect_slice = c_str_to_rust(dialect_str);
    let dialect = dialect_slice
        .and_then(MarkdownDialect::from_str_name)
        .unwrap_or(MarkdownDialect::Generic);

    let is_dialect_explicit = dialect_slice.map(|s| !s.is_empty()).unwrap_or(false);
    let theme = c_str_to_rust(theme_str).unwrap_or("system");
    let base = c_str_to_rust(base_url);

    let pipeline = MarkdownPipeline::new(dialect, is_dialect_explicit);
    let (preprocessed, _effective_dialect) = pipeline.preprocess(source_str);

    let parser = MarkdownParser::new(theme);
    let rendered = parser.render(&preprocessed);

    let final_title = c_str_to_rust(title_override)
        .map(|s| s.to_string())
        .or(rendered.title)
        .unwrap_or_else(|| "MDVu Document".to_string());

    let html = make_html(
        &rendered.body,
        &final_title,
        theme,
        full_width,
        base,
        embed_engines,
    );

    let toc_json = serde_json::to_string(&rendered.toc).unwrap_or_else(|_| "[]".to_string());

    let doc = Box::new(MdvuDocument {
        html: CString::new(html).unwrap_or_default(),
        body: CString::new(rendered.body).unwrap_or_default(),
        title: CString::new(final_title).unwrap_or_default(),
        toc_json: CString::new(toc_json).unwrap_or_default(),
        has_mermaid: rendered.has_mermaid,
        has_plantuml: rendered.has_plantuml,
        has_math: rendered.has_math,
    });

    Box::into_raw(doc)
}

#[no_mangle]
pub unsafe extern "C" fn mdvu_document_get_html(doc: *const MdvuDocument) -> *const c_char {
    if doc.is_null() {
        std::ptr::null()
    } else {
        (*doc).html.as_ptr()
    }
}

#[no_mangle]
pub unsafe extern "C" fn mdvu_document_get_body(doc: *const MdvuDocument) -> *const c_char {
    if doc.is_null() {
        std::ptr::null()
    } else {
        (*doc).body.as_ptr()
    }
}

#[no_mangle]
pub unsafe extern "C" fn mdvu_document_get_title(doc: *const MdvuDocument) -> *const c_char {
    if doc.is_null() {
        std::ptr::null()
    } else {
        (*doc).title.as_ptr()
    }
}

#[no_mangle]
pub unsafe extern "C" fn mdvu_document_get_toc_json(doc: *const MdvuDocument) -> *const c_char {
    if doc.is_null() {
        std::ptr::null()
    } else {
        (*doc).toc_json.as_ptr()
    }
}

#[no_mangle]
pub unsafe extern "C" fn mdvu_document_has_mermaid(doc: *const MdvuDocument) -> bool {
    if doc.is_null() {
        false
    } else {
        (*doc).has_mermaid
    }
}

#[no_mangle]
pub unsafe extern "C" fn mdvu_document_has_plantuml(doc: *const MdvuDocument) -> bool {
    if doc.is_null() {
        false
    } else {
        (*doc).has_plantuml
    }
}

#[no_mangle]
pub unsafe extern "C" fn mdvu_document_has_math(doc: *const MdvuDocument) -> bool {
    if doc.is_null() {
        false
    } else {
        (*doc).has_math
    }
}

#[no_mangle]
pub unsafe extern "C" fn mdvu_document_free(doc: *mut MdvuDocument) {
    if !doc.is_null() {
        drop(Box::from_raw(doc));
    }
}
