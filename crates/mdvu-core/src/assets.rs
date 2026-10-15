use std::io::Cursor;
use std::sync::OnceLock;

pub static MARKDOWN_CSS: &str = include_str!("../../../Sources/mdvu/Resources/markdown.css");
pub static APP_JS: &str = include_str!("../../../Sources/mdvu/Resources/app.js");

pub static MERMAID_LZMA: &[u8] = include_bytes!("../../../Sources/mdvu/Resources/mermaid.lzma");
pub static PLANTUML_LZMA: &[u8] = include_bytes!("../../../Sources/mdvu/Resources/plantuml.lzma");
pub static KATEX_LZMA: &[u8] = include_bytes!("../../../Sources/mdvu/Resources/katex.lzma");

static MERMAID_JS: OnceLock<Option<String>> = OnceLock::new();
static PLANTUML_JS: OnceLock<Option<String>> = OnceLock::new();
static KATEX_JS: OnceLock<Option<String>> = OnceLock::new();

fn decompress_lzma(bytes: &[u8]) -> Option<String> {
    let mut reader = Cursor::new(bytes);
    let mut output = Vec::new();
    if lzma_rs::lzma_decompress(&mut reader, &mut output).is_err() {
        return None;
    }
    String::from_utf8(output).ok()
}

pub fn get_mermaid_js() -> Result<&'static str, &'static str> {
    MERMAID_JS
        .get_or_init(|| decompress_lzma(MERMAID_LZMA))
        .as_deref()
        .ok_or("Failed to decompress Mermaid bundle")
}

pub fn get_plantuml_js() -> Result<&'static str, &'static str> {
    PLANTUML_JS
        .get_or_init(|| decompress_lzma(PLANTUML_LZMA))
        .as_deref()
        .ok_or("Failed to decompress PlantUML bundle")
}

pub fn get_katex_js() -> Result<&'static str, &'static str> {
    KATEX_JS
        .get_or_init(|| decompress_lzma(KATEX_LZMA))
        .as_deref()
        .ok_or("Failed to decompress KaTeX bundle")
}
