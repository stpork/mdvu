use std::ffi::{CStr, CString};
use std::io::Read;
use std::sync::OnceLock;

pub static MARKDOWN_CSS: &str = include_str!("../../../assets/markdown.css");
pub static APP_JS: &str = include_str!("../../../assets/app.js");

pub const RUNTIME_MANIFEST: &str = include_str!("../../../scripts/runtime-assets/manifest.json");

static MARKDOWN_CSS_C: OnceLock<Option<CString>> = OnceLock::new();
static APP_JS_C: OnceLock<Option<CString>> = OnceLock::new();
static MERMAID_SOURCE: OnceLock<Option<CString>> = OnceLock::new();
static MERMAID_JS: OnceLock<Option<CString>> = OnceLock::new();
static PLANTUML_JS: OnceLock<Option<CString>> = OnceLock::new();
static KATEX_JS: OnceLock<Option<CString>> = OnceLock::new();

// A macOS Universal bundle shares one copy across both CPU slices. Other builds
// remain self-contained, including the Windows executable and cargo test tools.
fn runtime_bytes(name: &str) -> Option<std::borrow::Cow<'static, [u8]>> {
    #[cfg(feature = "bundle-assets")]
    {
        let executable = std::env::current_exe().ok()?;
        let resources = executable.parent()?.parent()?.join("Resources");
        std::fs::read(resources.join(format!("{name}.lzma")))
            .ok()
            .map(std::borrow::Cow::Owned)
    }
    #[cfg(not(feature = "bundle-assets"))]
    Some(std::borrow::Cow::Borrowed(match name {
        "mermaid" => include_bytes!("../../../assets/mermaid.lzma"),
        "plantuml" => include_bytes!("../../../assets/plantuml.lzma"),
        "katex" => include_bytes!("../../../assets/katex.lzma"),
        _ => return None,
    }))
}

fn runtime(name: &str) -> Option<CString> {
    let metadata: serde_json::Value = serde_json::from_str(RUNTIME_MANIFEST).ok()?;
    let size = metadata["assets"][name]["sourceBytes"].as_u64()?;
    decompress_lzma(&runtime_bytes(name)?, size)
}

fn decompress_lzma(bytes: &[u8], size: u64) -> Option<CString> {
    let header = bytes.get(..13)?;
    let dictionary = u32::from_le_bytes(header[1..5].try_into().ok()?);
    // The manifest knows the output length even when the LZMA header does not.
    // This bounds the history buffer to actual content, not the 64 MiB preset.
    let mut reader =
        lzma_rust2::LzmaReader::new_with_props(&bytes[13..], size, header[0], dictionary, None)
            .ok()?;
    let mut output = Vec::with_capacity(usize::try_from(size).ok()?);
    reader.read_to_end(&mut output).ok()?;
    if output.len() as u64 != size {
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

/// Native workers evaluate the bundle directly; HTML exports need the escaped loader below.
pub fn get_mermaid_source_c_str() -> Option<&'static CStr> {
    MERMAID_SOURCE.get_or_init(|| runtime("mermaid")).as_deref()
}

pub fn get_mermaid_source() -> Result<&'static str, &'static str> {
    get_mermaid_source_c_str()
        .and_then(|s| s.to_str().ok())
        .ok_or("Failed to decompress Mermaid bundle")
}

pub fn get_mermaid_c_str() -> Option<&'static CStr> {
    MERMAID_JS
        .get_or_init(|| {
            let source = get_mermaid_source_c_str()?;
            let literal = serde_json::to_string(source.to_str().ok()?).ok()?.replace('<', "\\u003c");
            CString::new(format!("(()=>{{const load=()=>window.__mdvuLoadMermaid({literal});if(window.__mdvuLoadMermaid)load();else document.addEventListener('DOMContentLoaded',load,{{once:true}})}})();")).ok()
        })
        .as_deref()
}

pub fn get_plantuml_c_str() -> Option<&'static CStr> {
    PLANTUML_JS.get_or_init(|| runtime("plantuml")).as_deref()
}

pub fn get_katex_c_str() -> Option<&'static CStr> {
    KATEX_JS.get_or_init(|| runtime("katex")).as_deref()
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

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn bounded_lzma_decoder_rejects_truncation_and_preserves_bytes() {
        let bytes = [
            93, 0, 0, 128, 0, 255, 255, 255, 255, 255, 255, 255, 255, 0, 36, 25, 73, 152, 111, 22,
            2, 140, 232, 230, 91, 177, 71, 198, 206, 183, 99, 255, 255, 60, 172, 0, 0,
        ];
        assert_eq!(
            decompress_lzma(&bytes, 13).unwrap().as_bytes(),
            b"Hello, world!"
        );
        assert!(decompress_lzma(&bytes[..10], 13).is_none());
        assert!(decompress_lzma(&bytes[..20], 13).is_none());
        assert!(decompress_lzma(&bytes, 100).is_none());
    }
    #[test]
    fn native_mermaid_uses_raw_source_and_exports_keep_the_html_safe_loader() {
        let source = get_mermaid_source().unwrap();
        assert_eq!(
            source.len(),
            serde_json::from_str::<serde_json::Value>(RUNTIME_MANIFEST).unwrap()["assets"]
                ["mermaid"]["sourceBytes"]
                .as_u64()
                .unwrap() as usize
        );
        let export = get_mermaid_js().unwrap();
        assert!(export.contains("window.__mdvuLoadMermaid("));
        assert!(!export.contains('<'));
        assert_eq!(get_mermaid_source().unwrap().as_ptr(), source.as_ptr());
    }
}
