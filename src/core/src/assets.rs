use std::ffi::{CStr, CString};
use std::io::Cursor;
use std::sync::OnceLock;

pub static MARKDOWN_CSS: &str = include_str!("../../../assets/markdown.css");
pub static APP_JS: &str = include_str!("../../../assets/app.js");

pub static MERMAID_LZMA: &[u8] = include_bytes!("../../../assets/mermaid.lzma");
pub static PLANTUML_LZMA: &[u8] = include_bytes!("../../../assets/plantuml.lzma");
pub static KATEX_LZMA: &[u8] = include_bytes!("../../../assets/katex.lzma");

static MARKDOWN_CSS_C: OnceLock<Option<CString>> = OnceLock::new();
static APP_JS_C: OnceLock<Option<CString>> = OnceLock::new();
static MERMAID_JS: OnceLock<Option<CString>> = OnceLock::new();
static PLANTUML_JS: OnceLock<Option<CString>> = OnceLock::new();
static KATEX_JS: OnceLock<Option<CString>> = OnceLock::new();

fn decompress_lzma(bytes: &[u8]) -> Option<CString> {
    const XZ_MAGIC: &[u8] = &[0xFD, b'7', b'z', b'X', b'Z', 0x00];
    let mut reader = Cursor::new(bytes);
    let mut output = Vec::with_capacity(bytes.len() * 4);
    let res = if bytes.starts_with(XZ_MAGIC) {
        lzma_rs::xz_decompress(&mut reader, &mut output)
    } else {
        lzma_rs::lzma_decompress(&mut reader, &mut output)
    };
    if res.is_err() {
        return None;
    }
    CString::new(output).ok()
}

pub fn get_markdown_css_c_str() -> Option<&'static CStr> {
    MARKDOWN_CSS_C
        .get_or_init(|| CString::new(MARKDOWN_CSS).ok())
        .as_deref()
}

pub fn get_app_js_c_str() -> Option<&'static CStr> {
    APP_JS_C
        .get_or_init(|| CString::new(APP_JS).ok())
        .as_deref()
}

pub fn get_mermaid_c_str() -> Option<&'static CStr> {
    MERMAID_JS
        .get_or_init(|| {
            let source = decompress_lzma(MERMAID_LZMA)?;
            let literal = serde_json::to_string(source.to_str().ok()?).ok()?.replace('<', "\\u003c");
            CString::new(format!("(()=>{{const load=()=>window.__mdvuLoadMermaid({literal});if(window.__mdvuLoadMermaid)load();else document.addEventListener('DOMContentLoaded',load,{{once:true}})}})();")).ok()
        })
        .as_deref()
}

pub fn get_plantuml_c_str() -> Option<&'static CStr> {
    PLANTUML_JS
        .get_or_init(|| decompress_lzma(PLANTUML_LZMA))
        .as_deref()
}

pub fn get_katex_c_str() -> Option<&'static CStr> {
    KATEX_JS
        .get_or_init(|| decompress_lzma(KATEX_LZMA))
        .as_deref()
}

pub fn get_mermaid_js() -> Result<&'static str, &'static str> {
    get_mermaid_c_str()
        .and_then(|cs| cs.to_str().ok())
        .ok_or("Failed to decompress Mermaid bundle")
}

pub fn get_plantuml_js() -> Result<&'static str, &'static str> {
    get_plantuml_c_str()
        .and_then(|cs| cs.to_str().ok())
        .ok_or("Failed to decompress PlantUML bundle")
}

pub fn get_katex_js() -> Result<&'static str, &'static str> {
    get_katex_c_str()
        .and_then(|cs| cs.to_str().ok())
        .ok_or("Failed to decompress KaTeX bundle")
}
