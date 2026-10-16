use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use crate::assets::{
    get_app_js_c_str, get_katex_c_str, get_markdown_css_c_str, get_mermaid_c_str,
    get_plantuml_c_str,
};
use crate::navigator::DiagramCache;
use crate::pipeline::MarkdownDialect;
use crate::template::make_html_selective;

pub struct MdvuDocument {
    html: CString,
    body: CString,
    title: CString,
    has_title: bool,
    dialect: CString,
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
pub extern "C" fn mdvu_get_markdown_css() -> *const c_char {
    match get_markdown_css_c_str() {
        Some(s) => s.as_ptr(),
        None => std::ptr::null(),
    }
}

#[no_mangle]
pub extern "C" fn mdvu_get_app_js() -> *const c_char {
    match get_app_js_c_str() {
        Some(s) => s.as_ptr(),
        None => std::ptr::null(),
    }
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
pub unsafe extern "C" fn mdvu_diagram_cache_write(key: *const c_char, svg: *const c_char) {
    if let (Some(k), Some(s)) = (c_str_to_rust(key), c_str_to_rust(svg)) {
        DiagramCache::global().write(k, s);
    }
}

/// Fast path for rendering Markdown body + title + effective dialect without building a full standalone HTML document.
#[no_mangle]
pub unsafe extern "C" fn mdvu_render_body_bytes(
    source: *const c_char,
    source_len: usize,
    dialect_str: *const c_char,
    is_dialect_explicit: bool,
    theme_str: *const c_char,
    enable_diagrams: bool,
) -> *mut MdvuDocument {
    let source_str = match source_bytes(source, source_len) {
        Some(s) => s,
        None => return std::ptr::null_mut(),
    };

    let dialect = c_str_to_rust(dialect_str)
        .and_then(MarkdownDialect::from_str_name)
        .unwrap_or(MarkdownDialect::Generic);

    let theme = c_str_to_rust(theme_str).unwrap_or("light");

    let (rendered, effective_dialect) = crate::render_markdown_body(
        source_str,
        dialect,
        is_dialect_explicit,
        theme,
        enable_diagrams,
    );

    let has_title = rendered.title.is_some();
    let final_title = rendered.title.unwrap_or_default();

    let doc = Box::new(MdvuDocument {
        html: CString::default(),
        body: CString::new(rendered.body).unwrap_or_default(),
        title: CString::new(final_title).unwrap_or_default(),
        has_title,
        dialect: CString::new(effective_dialect.as_str()).unwrap_or_default(),
        toc_json: CString::default(),
        has_mermaid: rendered.has_mermaid,
        has_plantuml: rendered.has_plantuml,
        has_math: rendered.has_math,
    });

    Box::into_raw(doc)
}

#[no_mangle]
pub unsafe extern "C" fn mdvu_render_to_html_bytes(
    source: *const c_char,
    source_len: usize,
    title_override: *const c_char,
    dialect_str: *const c_char,
    theme_str: *const c_char,
    full_width: bool,
    base_url: *const c_char,
    embed_engines: bool,
    is_dialect_explicit: bool,
    enable_diagrams: bool,
) -> *mut MdvuDocument {
    let source_str = match source_bytes(source, source_len) {
        Some(s) => s,
        None => return std::ptr::null_mut(),
    };

    let dialect_slice = c_str_to_rust(dialect_str);
    let dialect = dialect_slice
        .and_then(MarkdownDialect::from_str_name)
        .unwrap_or(MarkdownDialect::Generic);

    let theme = c_str_to_rust(theme_str).unwrap_or("system");
    let base = c_str_to_rust(base_url);

    let (rendered, effective_dialect) = crate::render_markdown_body(
        source_str,
        dialect,
        is_dialect_explicit,
        theme,
        enable_diagrams,
    );

    let override_title = c_str_to_rust(title_override).map(|s| s.to_string());
    let has_title = override_title.is_some() || rendered.title.is_some();
    let final_title = override_title
        .or(rendered.title)
        .unwrap_or_else(|| "MDVu Document".to_string());

    let (embed_katex, embed_mermaid, embed_plantuml) = if embed_engines {
        (
            rendered.has_math,
            rendered.has_mermaid,
            rendered.has_plantuml,
        )
    } else {
        (false, false, false)
    };

    let html = make_html_selective(
        &rendered.body,
        &final_title,
        theme,
        full_width,
        base,
        embed_katex,
        embed_mermaid,
        embed_plantuml,
    );

    let toc_json = serde_json::to_string(&rendered.toc).unwrap_or_else(|_| "[]".to_string());

    let doc = Box::new(MdvuDocument {
        html: CString::new(html).unwrap_or_default(),
        body: CString::new(rendered.body).unwrap_or_default(),
        title: CString::new(final_title).unwrap_or_default(),
        has_title,
        dialect: CString::new(effective_dialect.as_str()).unwrap_or_default(),
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
    if doc.is_null() || !(*doc).has_title {
        std::ptr::null()
    } else {
        (*doc).title.as_ptr()
    }
}

#[no_mangle]
pub unsafe extern "C" fn mdvu_document_get_dialect(doc: *const MdvuDocument) -> *const c_char {
    if doc.is_null() {
        std::ptr::null()
    } else {
        (*doc).dialect.as_ptr()
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

unsafe fn source_bytes<'a>(source: *const c_char, len: usize) -> Option<&'a str> {
    if source.is_null() {
        return if len == 0 { Some("") } else { None };
    }
    std::str::from_utf8(std::slice::from_raw_parts(source.cast::<u8>(), len)).ok()
}

// Legacy C ABI remains available. New clients must use the length-delimited entry points.
#[no_mangle]
pub unsafe extern "C" fn mdvu_render_body(
    source: *const c_char,
    dialect: *const c_char,
    explicit: bool,
    theme: *const c_char,
    diagrams: bool,
) -> *mut MdvuDocument {
    if source.is_null() {
        return std::ptr::null_mut();
    }
    mdvu_render_body_bytes(
        source,
        CStr::from_ptr(source).to_bytes().len(),
        dialect,
        explicit,
        theme,
        diagrams,
    )
}
#[no_mangle]
pub unsafe extern "C" fn mdvu_render_to_html(
    source: *const c_char,
    title: *const c_char,
    dialect: *const c_char,
    theme: *const c_char,
    full_width: bool,
    base: *const c_char,
    embed: bool,
) -> *mut MdvuDocument {
    if source.is_null() {
        return std::ptr::null_mut();
    }
    mdvu_render_to_html_bytes(
        source,
        CStr::from_ptr(source).to_bytes().len(),
        title,
        dialect,
        theme,
        full_width,
        base,
        embed,
        !dialect.is_null(),
        true,
    )
}
