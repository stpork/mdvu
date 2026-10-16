pub mod assets;
pub mod ffi;
pub mod navigator;
pub mod parser;
pub mod pipeline;
pub mod template;

pub use assets::*;
pub use navigator::*;
pub use parser::{MarkdownParser, RenderedDocument, TocEntry};
pub use pipeline::{FastScan, MarkdownDialect, MarkdownPipeline};
pub use template::{make_html, make_html_selective};

pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// High-level function to render markdown into a complete HTML document.
/// When `embed_diagram_engines` is `true` (e.g. `--standalone` export), only the JS engines
/// actually needed by the document (`has_math`, `has_mermaid`, `has_plantuml`) are embedded.
/// When `embed_diagram_engines` is `false` (interactive WebView GUI), heavy JS engines are omitted
/// from the initial HTML and can be injected on demand.
pub fn render_markdown(
    source: &str,
    title_override: Option<&str>,
    dialect: MarkdownDialect,
    theme: &str,
    full_width: bool,
    base_url: Option<&str>,
    embed_diagram_engines: bool,
) -> (String, RenderedDocument) {
    render_markdown_with_options(
        source,
        title_override,
        dialect,
        false,
        theme,
        full_width,
        base_url,
        embed_diagram_engines,
    )
}

pub fn render_markdown_with_options(
    source: &str,
    title_override: Option<&str>,
    dialect: MarkdownDialect,
    is_dialect_explicit: bool,
    theme: &str,
    full_width: bool,
    base_url: Option<&str>,
    embed_diagram_engines: bool,
) -> (String, RenderedDocument) {
    let pipeline = MarkdownPipeline::new(dialect, is_dialect_explicit);
    let (preprocessed, _effective_dialect) = pipeline.preprocess_cow(source);

    let parser = MarkdownParser::new(theme);
    let rendered = parser.render(&preprocessed);

    let title = title_override
        .map(|s| s.to_string())
        .or_else(|| rendered.title.clone())
        .unwrap_or_else(|| "MDVu Document".to_string());

    let (embed_katex, embed_mermaid, embed_plantuml) = if embed_diagram_engines {
        (rendered.has_math, rendered.has_mermaid, rendered.has_plantuml)
    } else {
        (false, false, false)
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
    fn test_math_inline_and_display_not_corrupted_by_superscript() {
        let md = "Inline $a^2 + b^2 = c^2$ and $x_1 + x_2$ and display:\n\n$$\\int_0^1 x^2 + y^2 dx$$";
        let pipeline = MarkdownPipeline::new(MarkdownDialect::Generic, false);
        let (preprocessed, _) = pipeline.preprocess(md);
        assert!(preprocessed.contains("<span class=\"math-inline\">a^2 + b^2 = c^2</span>"));
        assert!(!preprocessed.contains("<sup>"));
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

    #[test]
    fn test_comment_dialect_directives() {
        use pipeline::MarkdownDocumentDirective;
        let md1 = "<!-- Open in Obsidian dialect for live wikilinks -->\n# Title";
        assert_eq!(MarkdownDocumentDirective::extract_dialect(md1), Some(MarkdownDialect::Obsidian));

        let md2 = "<!-- dialect: gfm -->\n# Title";
        assert_eq!(MarkdownDocumentDirective::extract_dialect(md2), Some(MarkdownDialect::Gfm));

        let md3 = "<!-- --dialect mkdocs -->\n# Title";
        assert_eq!(MarkdownDocumentDirective::extract_dialect(md3), Some(MarkdownDialect::Mkdocs));
    }
}
