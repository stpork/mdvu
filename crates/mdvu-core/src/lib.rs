pub mod assets;
pub mod ffi;
pub mod navigator;
pub mod parser;
pub mod pipeline;
pub mod template;

pub use assets::*;
pub use navigator::*;
pub use parser::{escape_html, MarkdownParser, RenderedDocument, TocEntry};
pub use pipeline::{FastScan, MarkdownDialect, MarkdownPipeline};
pub use template::{make_html, make_html_selective};

pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Renders Markdown into `RenderedDocument` (HTML body, title, TOC, and runtime flags)
/// without wrapping in a full `<!doctype html>` shell. Ideal for fast in-place WebView updates.
pub fn render_markdown_body(
    source: &str,
    dialect: MarkdownDialect,
    is_dialect_explicit: bool,
    theme: &str,
    enable_diagrams: bool,
) -> (RenderedDocument, MarkdownDialect) {
    let pipeline = MarkdownPipeline::new(dialect, is_dialect_explicit);
    let (preprocessed, effective_dialect) = pipeline.preprocess_cow(source);
    let parser = MarkdownParser::with_options(theme, enable_diagrams);
    let rendered = parser.render(&preprocessed);
    (rendered, effective_dialect)
}

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
    render_markdown_full_options(
        source,
        title_override,
        dialect,
        is_dialect_explicit,
        theme,
        full_width,
        base_url,
        embed_diagram_engines,
        true,
    )
}

pub fn render_markdown_full_options(
    source: &str,
    title_override: Option<&str>,
    dialect: MarkdownDialect,
    is_dialect_explicit: bool,
    theme: &str,
    full_width: bool,
    base_url: Option<&str>,
    embed_diagram_engines: bool,
    enable_diagrams: bool,
) -> (String, RenderedDocument) {
    let (rendered, _effective_dialect) = render_markdown_body(
        source,
        dialect,
        is_dialect_explicit,
        theme,
        enable_diagrams,
    );

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

    #[test]
    fn test_frontmatter_lf_and_crlf() {
        let crlf = "---\r\nTitle: Windows Document\r\nAuthor: Developer\r\n---\r\n# Hello World";
        let (doc, _) = render_markdown_body(crlf, MarkdownDialect::Gfm, true, "light", false);
        assert!(doc.body.contains("Document metadata"));
        assert!(doc.body.contains("Windows Document"));
        assert!(doc.body.contains("Developer"));
        assert!(doc.body.contains("Hello World"));

        let lf = "---\ndialect: obsidian\n---\n[[WikiTarget]]";
        let (doc_lf, eff) = render_markdown_body(lf, MarkdownDialect::Generic, false, "light", false);
        assert_eq!(eff, MarkdownDialect::Obsidian);
        assert!(doc_lf.body.contains("href=\"WikiTarget.md\""));
    }

    #[test]
    fn test_admonitions_and_gitlab_toc() {
        let md = "!!! note \"Custom Title\"\n    This is a note body.\n\n???+ tip\n    Collapsible tip.\n\n:::warning\nThis is a warning block.\n:::\n\n[[_TOC_]]\n\n```text\n[[_TOC_]]\n```";
        let (doc, _) = render_markdown_body(md, MarkdownDialect::Gfm, true, "light", false);
        assert!(doc.body.contains("callout-note"));
        assert!(doc.body.contains("Custom Title"));
        assert!(doc.body.contains("callout-tip"));
        assert!(doc.body.contains("callout-warning"));
        assert_eq!(doc.body.matches("toc-placeholder").count(), 1);
    }

    #[test]
    fn test_compressed_lzma_assets_decompress_cleanly() {
        let mermaid = get_mermaid_js().expect("Mermaid LZMA should decompress");
        assert!(mermaid.contains("mermaid"));
        assert!(mermaid.len() > 5_000_000);

        let plantuml = get_plantuml_js().expect("PlantUML LZMA should decompress");
        assert!(plantuml.contains("PlantUML"));
        assert!(plantuml.len() > 4_000_000);

        let katex = get_katex_js().expect("KaTeX LZMA should decompress");
        assert!(katex.contains("katex"));
        assert!(katex.len() > 200_000);
    }

    #[test]
    fn test_no_mermaid_option_disables_diagram_placeholders() {
        let md = "```mermaid\ngraph TD\nA-->B\n```";
        let (with_diag, _) = render_markdown_body(md, MarkdownDialect::Generic, true, "light", true);
        assert!(with_diag.has_mermaid);
        assert!(with_diag.body.contains("data-renderer=\"mermaid\""));

        let (no_diag, _) = render_markdown_body(md, MarkdownDialect::Generic, true, "light", false);
        assert!(!no_diag.has_mermaid);
        assert!(!no_diag.body.contains("data-renderer=\"mermaid\""));
    }

    #[test]
    fn test_all_42_math_cases_and_complete_fixture() {
        let manifest_dir = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let fixture_path = manifest_dir.join("../../Tests/Fixtures/test-complete.md");
        let source = std::fs::read_to_string(&fixture_path)
            .expect("Tests/Fixtures/test-complete.md must be readable");

        let (doc, _) = render_markdown_body(&source, MarkdownDialect::Gfm, true, "light", true);
        assert!(doc.title.is_some());
        assert!(doc.has_math);
        assert!(doc.has_mermaid);
        assert!(doc.has_plantuml);
        assert!(doc.body.contains("MDVU-COMPLETE-BEGIN"));
        assert!(doc.body.contains("MDVU-COMPLETE-MIDDLE"));
        assert!(doc.body.contains("MDVU-COMPLETE-END"));

        for i in 1..=42 {
            let case_id = format!("MATH-{i:03}");
            let begin_marker = format!("<!-- mdvu-case-begin: {case_id} -->");
            let end_marker = format!("<!-- mdvu-case-end: {case_id} -->");
            if let Some(b_pos) = source.find(&begin_marker) {
                let start = b_pos + begin_marker.len();
                if let Some(e_rel) = source[start..].find(&end_marker) {
                    let snippet = &source[start..start + e_rel];
                    let (snippet_doc, _) =
                        render_markdown_body(snippet, MarkdownDialect::Gfm, true, "light", false);
                    assert!(
                        snippet_doc.has_math
                            || snippet_doc.body.contains("math-inline")
                            || snippet_doc.body.contains("math-display"),
                        "Expected math in case {case_id}"
                    );
                }
            }
        }
    }

    #[test]
    fn test_runtime_security_and_error_fixtures() {
        let manifest_dir = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let runtime_dir = manifest_dir.join("../../Tests/Fixtures/runtime");
        let entries: Vec<_> = std::fs::read_dir(&runtime_dir)
            .expect("Tests/Fixtures/runtime must exist")
            .flatten()
            .filter(|e| e.path().extension().and_then(|s| s.to_str()) == Some("md"))
            .collect();

        assert!(entries.len() >= 25);

        for entry in entries {
            let path = entry.path();
            let content = std::fs::read_to_string(&path).unwrap();
            let (gh_doc, _) = render_markdown_body(&content, MarkdownDialect::Gfm, true, "light", true);
            assert!(!gh_doc.body.is_empty());

            let (obs_doc, _) =
                render_markdown_body(&content, MarkdownDialect::Obsidian, true, "dark", true);
            assert!(!obs_doc.body.is_empty());

            let fname = entry.file_name().to_string_lossy().to_string();
            if fname.starts_with("sec-") {
                assert!(
                    !gh_doc.body.contains("<script>alert("),
                    "Security fixture {fname} leaked <script> tag"
                );
                assert!(
                    !obs_doc.body.contains("<script>alert("),
                    "Security fixture {fname} leaked <script> tag"
                );
            }
        }
    }
}
