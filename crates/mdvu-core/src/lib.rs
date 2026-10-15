pub mod assets;
pub mod ffi;
pub mod parser;
pub mod pipeline;
pub mod template;

pub use assets::*;
pub use parser::{MarkdownParser, RenderedDocument, TocEntry};
pub use pipeline::{FastScan, MarkdownDialect, MarkdownPipeline};
pub use template::{make_html, make_html_selective};

pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// High-level function to render markdown into a complete, standalone HTML document.
pub fn render_markdown(
    source: &str,
    title_override: Option<&str>,
    dialect: MarkdownDialect,
    theme: &str,
    full_width: bool,
    base_url: Option<&str>,
    embed_diagram_engines: bool,
) -> (String, RenderedDocument) {
    let pipeline = MarkdownPipeline::new(dialect, false);
    let (preprocessed, _effective_dialect) = pipeline.preprocess(source);

    let parser = MarkdownParser::new(theme);
    let rendered = parser.render(&preprocessed);

    let title = title_override
        .map(|s| s.to_string())
        .or_else(|| rendered.title.clone())
        .unwrap_or_else(|| "MDVu Document".to_string());

    let (embed_katex, embed_mermaid, embed_plantuml) = if embed_diagram_engines {
        (true, true, true)
    } else {
        (rendered.has_math, rendered.has_mermaid, rendered.has_plantuml)
    };

    let html = make_html_selective(
        &rendered.body,
        &title,
        theme,
        full_width,
        base_url,
        embed_katex,
        embed_mermaid,
        embed_plantuml,
    );

    (html, rendered)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_obsidian_callout_and_wikilinks() {
        let md = "> [!NOTE] Custom Note\n> Callout content\n\n[[Target Note|Custom Label]]";
        let pipeline = MarkdownPipeline::new(MarkdownDialect::Obsidian, true);
        let (preprocessed, _) = pipeline.preprocess(md);
        assert!(preprocessed.contains("MDVU-CALLOUT-NOTE"));
        assert!(preprocessed.contains("[Custom Label](Target Note.md)"));

        let parser = MarkdownParser::new("light");
        let doc = parser.render(&preprocessed);
        assert!(doc.body.contains("callout callout-note"));
        assert!(doc.body.contains("Custom Note"));
    }

    #[test]
    fn test_math_inline_and_display() {
        let md = "Inline $E=mc^2$ and display:\n\n$$\\int_0^1 x dx$$";
        let pipeline = MarkdownPipeline::new(MarkdownDialect::Generic, false);
        let (preprocessed, _) = pipeline.preprocess(md);
        assert!(preprocessed.contains("math-inline"));
        assert!(preprocessed.contains("math-display"));
    }

    #[test]
    fn test_critic_markup() {
        let md = "Test {++addition++} and {--deletion--}";
        let pipeline = MarkdownPipeline::new(MarkdownDialect::Generic, false);
        let (preprocessed, _) = pipeline.preprocess(md);
        assert!(preprocessed.contains("<ins class=\"critic-add\">addition</ins>"));
        assert!(preprocessed.contains("<del class=\"critic-del\">deletion</del>"));
    }

    #[test]
    fn test_sub_superscript() {
        let md = "H~2~O and E=mc^2^ and ^^underlined^^";
        let pipeline = MarkdownPipeline::new(MarkdownDialect::Generic, false);
        let (preprocessed, _) = pipeline.preprocess(md);
        assert!(preprocessed.contains("<sub>2</sub>"));
        assert!(preprocessed.contains("<sup>2</sup>"));
        assert!(preprocessed.contains("<u>underlined</u>"));
    }
}
