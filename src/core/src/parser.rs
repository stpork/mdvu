use crate::navigator::{compute_diagram_cache_key, DiagramCache};
use crate::pipeline::FastScan;
use pulldown_cmark::{
    html, CodeBlockKind, CowStr, Event, HeadingLevel, Options, Parser, Tag, TagEnd,
};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::sync::LazyLock;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TocEntry {
    pub level: u8,
    pub title: String,
    pub id: String,
}

#[derive(Debug, Clone)]
pub struct RenderedDocument {
    pub body: String,
    pub title: Option<String>,
    pub toc: Vec<TocEntry>,
    pub has_mermaid: bool,
    pub has_plantuml: bool,
    pub has_math: bool,
}

pub fn escape_html(input: &str) -> String {
    if !input
        .bytes()
        .any(|b| matches!(b, b'&' | b'<' | b'>' | b'"' | b'\''))
    {
        return input.to_string();
    }
    let mut out = String::with_capacity(input.len() + 16);
    for c in input.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&#39;"),
            _ => out.push(c),
        }
    }
    out
}

fn unescape_html(input: &str) -> String {
    if !FastScan::contains_ascii(input, b'&') {
        return input.to_string();
    }
    input
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&apos;", "'")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&nbsp;", " ")
        .replace("&amp;", "&")
}

fn strip_html_tags(input: &str) -> String {
    if !FastScan::contains_ascii(input, b'<') {
        return input.to_string();
    }
    let mut out = String::with_capacity(input.len());
    let mut in_tag = false;
    for c in input.chars() {
        if c == '<' {
            in_tag = true;
        } else if c == '>' && in_tag {
            in_tag = false;
        } else if !in_tag {
            out.push(c);
        }
    }
    out
}

fn base_slug(title: &str) -> String {
    let clean: String = title
        .chars()
        .filter(|c| c.is_alphanumeric() || c.is_whitespace() || *c == '-' || *c == '_')
        .flat_map(char::to_lowercase)
        .collect();
    let slug = clean.split_whitespace().collect::<Vec<_>>().join("-");
    if slug.is_empty() {
        "section".to_string()
    } else {
        slug
    }
}

// GFM Security Tagfilter: disarm script, iframe, textarea, title, xmp, noembed, noframes, plaintext
// Note: <style> is explicitly preserved per MDVu spec.
static DISALLOWED_TAG_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?s)<(/?)((?i-u:script|iframe|textarea|title|xmp|noembed|noframes|plaintext))([/ \t\r\n][^>]*|)>"#).unwrap()
});

static RAW_H1_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?s)<(?i-u:h1)(?:[ \t\r\n][^>]*)?>(.*?)</(?i-u:h1)>"#).unwrap());

fn apply_tagfilter<'a>(raw_html: CowStr<'a>) -> CowStr<'a> {
    if !FastScan::contains_ascii(&raw_html, b'<') {
        return raw_html;
    }
    match DISALLOWED_TAG_RE.replace_all(&raw_html, |caps: &regex::Captures| {
        let slash = &caps[1];
        let tag_name = &caps[2];
        let rest = &caps[3];
        format!("&lt;{slash}{tag_name}{rest}>")
    }) {
        std::borrow::Cow::Borrowed(_) => raw_html,
        std::borrow::Cow::Owned(s) => CowStr::Boxed(s.into_boxed_str()),
    }
}

pub struct MarkdownParser {
    pub diagram_theme: String,
    pub enable_diagrams: bool,
}

impl MarkdownParser {
    pub fn new(diagram_theme: &str) -> Self {
        Self {
            diagram_theme: diagram_theme.to_string(),
            enable_diagrams: true,
        }
    }

    pub fn with_options(diagram_theme: &str, enable_diagrams: bool) -> Self {
        Self {
            diagram_theme: diagram_theme.to_string(),
            enable_diagrams,
        }
    }

    pub fn render(&self, source: &str) -> RenderedDocument {
        let mut options = Options::empty();
        options.insert(Options::ENABLE_TABLES);
        options.insert(Options::ENABLE_FOOTNOTES);
        options.insert(Options::ENABLE_STRIKETHROUGH);
        options.insert(Options::ENABLE_TASKLISTS);
        options.insert(Options::ENABLE_HEADING_ATTRIBUTES);

        let parser = Parser::new_ext(source, options);

        let mut inside_code_block: Option<String> = None;
        let mut code_buffer = String::new();

        let mut current_heading_level: Option<HeadingLevel> = None;
        let mut current_heading_text = String::new();
        let mut current_heading_id: Option<String> = None;
        let mut toc = Vec::new();
        let mut doc_title: Option<String> = None;
        let mut slug_counts: HashMap<String, usize> = HashMap::new();
        let mut used_slug_ids: HashSet<String> = HashSet::new();

        let mut has_mermaid = false;
        let mut has_plantuml = false;
        let mut has_math = FastScan::contains_token(source, "math-inline")
            || FastScan::contains_token(source, "math-display");

        let diagram_theme = &self.diagram_theme;
        let enable_diagrams = self.enable_diagrams;

        let mut link_depth = 0usize;
        let stream = parser.filter_map(|event| match event {
            Event::Html(raw) => Some(Event::Html(apply_tagfilter(raw))),
            Event::InlineHtml(raw) => Some(Event::InlineHtml(apply_tagfilter(raw))),
            Event::Start(Tag::CodeBlock(CodeBlockKind::Fenced(lang))) => {
                inside_code_block = Some(lang.to_string());
                code_buffer.clear();
                None
            }
            Event::Start(Tag::CodeBlock(CodeBlockKind::Indented)) => {
                inside_code_block = Some(String::new());
                code_buffer.clear();
                None
            }
            Event::End(TagEnd::CodeBlock) => {
                let lang = inside_code_block.take()?;
                let clean_lang = lang.trim().to_ascii_lowercase();
                let trimmed_code = code_buffer.trim_matches(|c| c == '\n' || c == '\r');

                if enable_diagrams && clean_lang == "mermaid" {
                    has_mermaid = true;
                    let key = compute_diagram_cache_key("mermaid", diagram_theme, trimmed_code);
                    let html = if let Some(svg) = DiagramCache::global().read(&key) {
                        format!(
                            "<figure class=\"diagram diagram-rendered\" data-renderer=\"mermaid\" data-cache-key=\"{key}\">{svg}</figure>"
                        )
                    } else {
                        format!(
                            "<figure class=\"diagram diagram-pending\" data-renderer=\"mermaid\" data-cache-key=\"{key}\"><pre>{}</pre><div class=\"diagram-status\">Rendering diagram…</div></figure>",
                            escape_html(trimmed_code)
                        )
                    };
                    Some(Event::Html(html.into()))
                } else if enable_diagrams && (clean_lang == "plantuml" || clean_lang == "puml") {
                    has_plantuml = true;
                    let key = compute_diagram_cache_key("plantuml", diagram_theme, trimmed_code);
                    let html = if let Some(svg) = DiagramCache::global().read(&key) {
                        format!(
                            "<figure class=\"diagram diagram-rendered\" data-renderer=\"plantuml\" data-cache-key=\"{key}\">{svg}</figure>"
                        )
                    } else {
                        format!(
                            "<figure class=\"diagram diagram-pending\" data-renderer=\"plantuml\" data-cache-key=\"{key}\"><pre>{}</pre><div class=\"diagram-status\">Rendering diagram…</div></figure>",
                            escape_html(trimmed_code)
                        )
                    };
                    Some(Event::Html(html.into()))
                } else if clean_lang == "math" || clean_lang == "latex" || clean_lang == "katex" {
                    has_math = true;
                    let html = format!(
                        "<div class=\"math-display\">{}</div>",
                        escape_html(trimmed_code)
                    );
                    Some(Event::Html(html.into()))
                } else {
                    let class_attr = if clean_lang.is_empty() {
                        String::new()
                    } else {
                        format!(" class=\"language-{}\"", escape_html(&clean_lang))
                    };
                    let html = format!(
                        "<pre><code{class_attr}>{}</code></pre>",
                        escape_html(trimmed_code)
                    );
                    Some(Event::Html(html.into()))
                }
            }
            Event::Text(ref text) if inside_code_block.is_some() => {
                code_buffer.push_str(text);
                None
            }
            Event::Start(Tag::Heading { level, ref id, .. }) => {
                current_heading_id = id.as_ref().map(ToString::to_string);
                current_heading_level = Some(level);
                current_heading_text.clear();
                Some(event)
            }
            Event::End(TagEnd::Heading(_)) => {
                if let Some(level) = current_heading_level.take() {
                    let title = current_heading_text.trim().to_string();
                    let base = current_heading_id.take().unwrap_or_else(|| base_slug(&title));
                    let mut count = *slug_counts.get(&base).unwrap_or(&0);
                    let mut id = if count == 0 {
                        base.clone()
                    } else {
                        format!("{base}-{count}")
                    };
                    while used_slug_ids.contains(&id) {
                        count += 1;
                        id = format!("{base}-{count}");
                    }
                    slug_counts.insert(base, count + 1);
                    used_slug_ids.insert(id.clone());

                    let lvl_num = match level {
                        HeadingLevel::H1 => 1,
                        HeadingLevel::H2 => 2,
                        HeadingLevel::H3 => 3,
                        HeadingLevel::H4 => 4,
                        HeadingLevel::H5 => 5,
                        HeadingLevel::H6 => 6,
                    };

                    if lvl_num == 1 && doc_title.is_none() && !title.is_empty() {
                        doc_title = Some(title.clone());
                    }

                    toc.push(TocEntry {
                        level: lvl_num,
                        title,
                        id,
                    });
                }
                Some(event)
            }
            Event::Text(ref text) if current_heading_level.is_some() => {
                current_heading_text.push_str(text);
                Some(event)
            }
            Event::Code(ref text) if current_heading_level.is_some() => {
                current_heading_text.push_str(text);
                Some(event)
            }
            Event::Start(Tag::Link { .. } | Tag::Image { .. }) => { link_depth += 1; Some(event) }
            Event::End(TagEnd::Link | TagEnd::Image) => { link_depth = link_depth.saturating_sub(1); Some(event) }
            Event::Text(text) if link_depth == 0 => {
                let mut finder = linkify::LinkFinder::new();
                finder.url_must_have_scheme(false);
                finder.kinds(&[linkify::LinkKind::Url, linkify::LinkKind::Email]);
                let links: Vec<_> = finder.links(&text).filter(|link| *link.kind() == linkify::LinkKind::Email || link.as_str().starts_with("www.") || link.as_str().contains("://")).collect();
                if links.is_empty() { Some(Event::Text(text)) } else {
                    let mut out = String::new(); let mut last = 0;
                    for link in links {
                        out.push_str(&escape_html(&text[last..link.start()]));
                        let raw = link.as_str();
                        let href = if *link.kind() == linkify::LinkKind::Email { format!("mailto:{raw}") }
                            else if raw.starts_with("www.") { format!("https://{raw}") } else { raw.to_string() };
                        out.push_str(&format!("<a href=\"{}\">{}</a>", escape_html(&href), escape_html(raw)));
                        last = link.end();
                    }
                    out.push_str(&escape_html(&text[last..]));
                    Some(Event::Html(out.into()))
                }
            }
            _ => Some(event),
        });

        let mut html_out = String::with_capacity(source.len() + source.len() / 2);
        html::push_html(&mut html_out, stream);

        let final_body = Self::replace_callout_blocks(html_out);

        if doc_title.is_none()
            && (FastScan::contains_token(&final_body, "<h1")
                || FastScan::contains_token(&final_body, "<H1"))
        {
            if let Some(caps) = RAW_H1_RE.captures(&final_body) {
                if let Some(m) = caps.get(1) {
                    let cleaned = unescape_html(&strip_html_tags(m.as_str()))
                        .trim()
                        .to_string();
                    if !cleaned.is_empty() {
                        doc_title = Some(cleaned);
                    }
                }
            }
        }

        RenderedDocument {
            body: final_body,
            title: doc_title,
            toc,
            has_mermaid,
            has_plantuml,
            has_math,
        }
    }

    fn replace_callout_blocks(input: String) -> String {
        let marker = "MDVU-CALLOUT-";
        if !FastScan::contains_token(&input, marker) {
            return input;
        }

        let mut result = String::with_capacity(input.len());
        let mut cursor = 0;

        while let Some(marker_rel) = input[cursor..].find(marker) {
            let marker_pos = cursor + marker_rel;

            let search_back_start = if marker_pos > cursor + 200 {
                let mut s = marker_pos - 200;
                while s < marker_pos && !input.is_char_boundary(s) {
                    s += 1;
                }
                s
            } else {
                cursor
            };

            let Some(bq_rel) = input[search_back_start..marker_pos].rfind("<blockquote>") else {
                result.push_str(&input[cursor..marker_pos + marker.len()]);
                cursor = marker_pos + marker.len();
                continue;
            };
            let bq_start = search_back_start + bq_rel;

            let mut scan = marker_pos + marker.len();
            let mut depth = 0;
            let mut bq_end = None;

            while scan < input.len() {
                if let Some(next_lt) = input[scan..].find('<') {
                    let tag_pos = scan + next_lt;
                    let rem = &input[tag_pos..];
                    if rem.starts_with("<blockquote>") {
                        depth += 1;
                        scan = tag_pos + 12;
                    } else if rem.starts_with("</blockquote>") {
                        if depth == 0 {
                            bq_end = Some(tag_pos);
                            break;
                        }
                        depth -= 1;
                        scan = tag_pos + 13;
                    } else {
                        scan = tag_pos + 1;
                    }
                } else {
                    break;
                }
            }

            let Some(bq_end_pos) = bq_end else {
                result.push_str(&input[cursor..marker_pos + marker.len()]);
                cursor = marker_pos + marker.len();
                continue;
            };

            let marker_end = marker_pos + marker.len();
            let Some(strong_end_rel) = input[marker_end..bq_end_pos].find("</strong>") else {
                result.push_str(&input[cursor..marker_end]);
                cursor = marker_end;
                continue;
            };
            let strong_end_pos = marker_end + strong_end_rel;
            let callout_type = input[marker_end..strong_end_pos]
                .trim()
                .to_ascii_lowercase();

            let Some(p_end_rel) = input[strong_end_pos..bq_end_pos].find("</p>") else {
                result.push_str(&input[cursor..marker_end]);
                cursor = marker_end;
                continue;
            };
            let p_end_pos = strong_end_pos + p_end_rel;
            let raw_title = input[strong_end_pos + 9..p_end_pos].trim();
            let title = if raw_title.is_empty() {
                let mut c = callout_type.chars();
                match c.next() {
                    None => String::new(),
                    Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
                }
            } else {
                raw_title.to_string()
            };

            let body = input[p_end_pos + 4..bq_end_pos].trim_start_matches(['\n', '\r']);
            let processed_body = if FastScan::contains_token(body, "MDVU-CALLOUT-") {
                Self::replace_callout_blocks(body.to_string())
            } else {
                body.to_string()
            };

            result.push_str(&input[cursor..bq_start]);
            result.push_str(&format!(
                "<aside class=\"callout callout-{callout_type}\"><div class=\"callout-title\">{title}</div><div>{processed_body}</div></aside>"
            ));

            cursor = bq_end_pos + 13;
        }

        result.push_str(&input[cursor..]);
        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tagfilter_disarms_script_while_preserving_style() {
        let md = "<style>body { color: red; }</style>\n\n<script>alert(1)</script>\n\n<iframe src=\"evil.com\"></iframe>";
        let parser = MarkdownParser::new("light");
        let doc = parser.render(md);
        assert!(doc.body.contains("<style>body { color: red; }</style>"));
        assert!(!doc.body.contains("<script>"));
        assert!(doc.body.contains("&lt;script>alert(1)&lt;/script>"));
        assert!(!doc.body.contains("<iframe"));
        assert!(doc
            .body
            .contains("&lt;iframe src=\"evil.com\">&lt;/iframe>"));
    }

    #[test]
    fn test_tagfilter_disarms_inline_and_multiline_script() {
        let md =
            "Inline <script>alert(1)</script> here and <script\nsrc=\"malicious.js\">\n</script>";
        let parser = MarkdownParser::new("light");
        let doc = parser.render(md);
        assert!(!doc.body.contains("<script"));
        assert!(doc.body.contains("&lt;script>"));
        assert!(doc.body.contains("&lt;script\nsrc=\"malicious.js\">"));
        assert!(doc.body.contains("&lt;/script>"));
    }

    #[test]
    fn test_tagfilter_does_not_break_safe_or_custom_tags() {
        let md = "<scripting>custom tag</scripting> and <div>allowed block</div>";
        let parser = MarkdownParser::new("light");
        let doc = parser.render(md);
        assert!(doc.body.contains("<scripting>"));
        assert!(doc.body.contains("<div>allowed block</div>"));
    }

    #[test]
    fn test_duplicate_heading_slug_generation_and_inline_code() {
        let md = "# Introduction\n\n## Section\n\n## Section\n\n## Section\n\n## Section 1\n\n## Using `mdvu`\n";
        let parser = MarkdownParser::new("light");
        let doc = parser.render(md);
        let ids: Vec<&str> = doc.toc.iter().map(|t| t.id.as_str()).collect();
        assert_eq!(
            ids,
            vec![
                "introduction",
                "section",
                "section-1",
                "section-2",
                "section-1-1",
                "using-mdvu"
            ]
        );
        assert_eq!(doc.toc[5].title, "Using mdvu");
    }

    #[test]
    fn test_diagram_cache_key_collision_resistance() {
        let key1 = compute_diagram_cache_key("mermaid", "light", "graph TD\n  A --> B");
        let key2 = compute_diagram_cache_key("mermaid", "light", "graph TD\n  C --> D");
        assert_eq!(key1.len(), 64);
        assert_ne!(key1, key2);
    }

    #[test]
    fn test_raw_html_h1_title_extraction() {
        let parser = MarkdownParser::new("light");
        let doc =
            parser.render("<h1><img src=\"icon.png\" alt=\"icon\"/> Document &lt;Special&gt;</h1>");
        assert_eq!(doc.title.as_deref(), Some("Document <Special>"));
    }
}
