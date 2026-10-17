use mdvu_core::*;
use std::ffi::{CStr, CString};
use std::path::Path;
fn body(s: &str) -> RenderedDocument {
    render_markdown_body(s, MarkdownDialect::Obsidian, false, "light", true).0
}

#[test]
fn fast_scans_preserve_unicode_and_literal_tokens() {
    let text = "Åä 中文 العربية [!NOTE] $math$ ```code```";
    assert!(FastScan::contains_token(text, "[!"));
    assert!(FastScan::contains_token(text, "中文"));
    assert!(FastScan::count_ascii(text, b'$', 2));
    assert!(!FastScan::contains_ascii(text, b'%'));
    assert!(!FastScan::contains_token(text, "missing"));
}

#[test]
fn combined_inline_pass_preserves_math_code_links_and_attributes() {
    let rendered = body("{++H~2~O++} {>>t^2^<<} $x^{++y++}$ `H~2~O` [H~2~O](https://example.com/~user)");
    assert!(rendered.body.contains("<ins class=\"critic-add\">H<sub>2</sub>O</ins>"));
    assert!(rendered.body.contains("title=\"t^2^\""));
    assert!(rendered.body.contains("t<sup>2</sup>"));
    assert!(rendered.body.contains("x^{++y++}"));
    assert!(rendered.body.contains("<code>H~2~O</code>"));
    assert!(rendered.body.contains("href=\"https://example.com/~user\">H~2~O</a>"));
}

#[test]
fn document_execution_is_nonce_isolated() {
    let a = make_html(
        "<img src=x onerror=alert(1)>",
        "test",
        "light",
        false,
        None,
        false,
    );
    let b = make_html("", "test", "light", false, None, false);
    let nonce = |s: &str| {
        s.split("name=\"mdvu-script-nonce\" content=\"")
            .nth(1)
            .unwrap()
            .split('"')
            .next()
            .unwrap()
            .to_string()
    };
    assert_ne!(nonce(&a), nonce(&b));
    assert!(a.contains(&format!("script-src 'nonce-{}'", nonce(&a))));
    assert!(!a.contains("'unsafe-inline'; script"));
    assert!(a.contains(&format!("<script nonce=\"{}\">", nonce(&a))));
    assert!(a.contains("frame-src about:; object-src 'none'; form-action 'none'"));
}
#[test]
fn fence_language_cannot_create_an_attribute() {
    let d = body("```x\" onmouseover=\"alert(1)\ntext\n```");
    assert!(!d.body.contains(" onmouseover=\""));
    assert!(d.body.contains("&quot;"));
}
#[test]
fn extension_transforms_preserve_all_code_and_destinations() {
    for input in [
        "`[[Target]]`",
        "`{++literal++}`",
        "    $x$\n",
        "> ```text\n> $x$ [[Target]]\n> ```",
        "<a href=\"https://example.org/$a$\">link</a>",
    ] {
        let (prepared, _) =
            MarkdownPipeline::new(MarkdownDialect::Obsidian, false).preprocess(input);
        assert_eq!(prepared, input, "{input}");
    }
}
#[test]
fn wiki_links_with_spaces_and_unicode_are_links() {
    let d = body("[[Architecture Overview|Design]]\n\n![[assets/схема light.png]]");
    assert!(d.body.contains("href=\"Architecture%20Overview.md\""));
    assert!(d.body.contains("src=\"assets/"));
    assert!(d.body.contains("%20light.png\""));
    assert!(!d.body.contains("![["));
}
#[test]
fn gfm_links_are_not_nested_and_code_is_literal() {
    let d = body("https://example.org test@example.org www.example.org [existing](https://example.org) `https://example.org`");
    assert!(d.body.contains("href=\"https://example.org\""));
    assert!(d.body.contains("href=\"mailto:test@example.org\""));
    assert!(d.body.contains("href=\"https://www.example.org\""));
    assert!(!d.body.contains("<a href=\"https://example.org\"><a"));
    assert!(d.body.contains("<code>https://example.org</code>"));
}
#[test]
fn math_scanner_handles_large_unmatched_input() {
    // Previously 96 KB took seconds and scaled quadratically. This input also runs in debug CI.
    let s = "$a ".repeat(100_000);
    let start = std::time::Instant::now();
    let (prepared, _) = MarkdownPipeline::new(MarkdownDialect::Generic, false).preprocess_cow(&s);
    assert_eq!(prepared, s);
    assert!(
        start.elapsed().as_secs() < 5,
        "unmatched math must be bounded"
    );
    assert!(body("$a+b$ and $$c+d$$").has_math);
}
#[test]
fn frontmatter_preserves_first_key_with_both_line_endings() {
    for nl in ["\n", "\r\n"] {
        let s = format!("---{nl}dialect: obsidian{nl}---{nl}[[Target]]");
        let (doc, dialect) =
            render_markdown_body(&s, MarkdownDialect::Generic, false, "light", false);
        assert_eq!(dialect, MarkdownDialect::Obsidian);
        assert!(doc.body.contains("href=\"Target.md\""));
        assert!(!body(&format!("---{nl}")).body.is_empty());
    }
}
#[test]
fn file_urls_preserve_reserved_characters() {
    let root = tempfile::tempdir().unwrap();
    let dir = root.path().join("vault #1 %literal");
    std::fs::create_dir(&dir).unwrap();
    let file = dir.join("note.md");
    std::fs::write(&file, "# Note").unwrap();
    let base = get_base_url_for_file(&file).unwrap();
    assert!(base.contains("%23"));
    assert!(base.contains("%25literal"));
    assert!(base.contains("%20"));
    assert!(base.ends_with('/'));
    assert!(!get_base_url_for_file(Path::new("relative/note.md"))
        .unwrap()
        .contains(' '));
}
#[test]
fn operating_system_launches_only_web_and_mail() {
    for s in [
        "https://example.org",
        "http://example.org",
        "mailto:user@example.org",
    ] {
        assert!(navigator::is_external_url(s));
    }
    for s in [
        "file:///C:/Windows/notepad.exe",
        "C:\\Windows\\notepad.exe",
        "javascript:alert(1)",
        "ms-settings:",
        "https://example.org\nfile:test",
    ] {
        assert!(!navigator::is_external_url(s));
    }
}
#[test]
fn cache_rejects_spaced_handlers_and_oversized_svg() {
    for s in [
        "<svg onload =\"alert(1)\"></svg>",
        "<svg><image ONERROR\n=\"alert(1)\"/></svg>",
        "<svg><script >x</script></svg>",
    ] {
        assert!(!DiagramCache::is_safe_svg(s));
    }
    assert!(!DiagramCache::is_safe_svg(&format!(
        "<svg>{}</svg>",
        "x".repeat(10_000_000)
    )));
}
#[test]
fn ffi_preserves_nul_and_render_options() {
    use mdvu_core::ffi::*;
    let source =
        b"---\ndialect: obsidian\n---\n[[Target]]\n\0\n# After\n```mermaid\ngraph TD\nA-->B\n```";
    let generic = CString::new("generic").unwrap();
    unsafe {
        let doc = mdvu_render_to_html_bytes(
            source.as_ptr().cast(),
            source.len(),
            std::ptr::null(),
            generic.as_ptr(),
            std::ptr::null(),
            false,
            std::ptr::null(),
            false,
            false,
            false,
        );
        assert!(!doc.is_null());
        let html = CStr::from_ptr(mdvu_document_get_html(doc))
            .to_str()
            .unwrap();
        assert!(html.contains("Target.md"));
        assert!(html.contains("After"));
        assert!(!CStr::from_ptr(mdvu_document_get_body(doc))
            .to_str()
            .unwrap()
            .contains("diagram-pending"));
        mdvu_document_free(doc);
        assert!(mdvu_render_body_bytes(
            std::ptr::null(),
            1,
            std::ptr::null(),
            false,
            std::ptr::null(),
            true
        )
        .is_null());
        let doc = mdvu_render_body_bytes(
            [0xffu8].as_ptr().cast(),
            1,
            std::ptr::null(),
            false,
            std::ptr::null(),
            true,
        );
        assert!(doc.is_null());
    }
}

#[test]
fn ffi_ownership_nulls_flags_assets_and_legacy_clients() {
    use mdvu_core::ffi::*;
    let source = CString::new(
        "# Title\n\n$x$\n\n```mermaid\ngraph TD\nA-->B\n```\n\n```puml\nAlice->Bob\n```",
    )
    .unwrap();
    let dialect = CString::new("gfm").unwrap();
    unsafe {
        assert!(!mdvu_version().is_null());
        for ptr in [
            mdvu_get_markdown_css(),
            mdvu_get_app_js(),
            mdvu_get_mermaid_js(),
            mdvu_get_plantuml_js(),
            mdvu_get_katex_js(),
        ] {
            assert!(!CStr::from_ptr(ptr).to_bytes().is_empty());
        }
        for ptr in [
            mdvu_document_get_html(std::ptr::null()),
            mdvu_document_get_body(std::ptr::null()),
            mdvu_document_get_title(std::ptr::null()),
            mdvu_document_get_dialect(std::ptr::null()),
            mdvu_document_get_toc_json(std::ptr::null()),
        ] {
            assert!(ptr.is_null());
        }
        assert!(!mdvu_document_has_mermaid(std::ptr::null()));
        assert!(!mdvu_document_has_plantuml(std::ptr::null()));
        assert!(!mdvu_document_has_math(std::ptr::null()));
        mdvu_document_free(std::ptr::null_mut());
        let doc = mdvu_render_to_html(
            source.as_ptr(),
            std::ptr::null(),
            dialect.as_ptr(),
            std::ptr::null(),
            true,
            std::ptr::null(),
            true,
        );
        assert!(mdvu_document_has_mermaid(doc));
        assert!(mdvu_document_has_plantuml(doc));
        assert!(mdvu_document_has_math(doc));
        assert_eq!(
            CStr::from_ptr(mdvu_document_get_title(doc))
                .to_str()
                .unwrap(),
            "Title"
        );
        assert_eq!(
            CStr::from_ptr(mdvu_document_get_dialect(doc))
                .to_str()
                .unwrap(),
            "gfm"
        );
        assert!(CStr::from_ptr(mdvu_document_get_toc_json(doc))
            .to_str()
            .unwrap()
            .contains("title"));
        mdvu_document_free(doc);
        let doc = mdvu_render_body(
            source.as_ptr(),
            dialect.as_ptr(),
            true,
            std::ptr::null(),
            false,
        );
        assert!(!mdvu_document_has_mermaid(doc));
        mdvu_document_free(doc);
        assert!(mdvu_render_body(
            std::ptr::null(),
            std::ptr::null(),
            false,
            std::ptr::null(),
            true
        )
        .is_null());
        assert!(mdvu_render_to_html(
            std::ptr::null(),
            std::ptr::null(),
            std::ptr::null(),
            std::ptr::null(),
            false,
            std::ptr::null(),
            false
        )
        .is_null());
    }
}
#[test]
fn public_render_paths_and_selective_standalone_assets() {
    let (html, doc) = render_markdown(
        "# Title",
        None,
        MarkdownDialect::Gfm,
        "",
        false,
        None,
        false,
    );
    assert_eq!(doc.title.as_deref(), Some("Title"));
    assert!(html.contains("data-theme=\"system\""));
    let (html, _) = render_markdown_with_options(
        "$x$",
        Some("Override"),
        MarkdownDialect::Generic,
        true,
        "dark",
        true,
        Some("file:///tmp/"),
        true,
    );
    assert!(html.contains("<title>Override</title>"));
    assert!(html.contains("<base href=\"file:///tmp/\">"));
    assert!(html.len() > 200_000 && html.len() < 1_000_000);
    let doc = MarkdownParser::with_options("light", false)
        .render("```text\n<script>literal</script>\n```\n\n## !\n\n> [!NOTE] plain");
    assert!(doc.body.contains("&lt;script&gt;literal"));
}

#[test]
fn math_source_is_not_reprocessed_as_superscript() {
    let doc = body("$a^b+c^d$ and $H~2~O$");
    assert!(doc.body.contains("a^b+c^d"));
    assert!(doc.body.contains("H~2~O"));
    assert!(!doc.body.contains("<sup>"));
    assert!(!doc.body.contains("<sub>"));
}
