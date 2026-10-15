use pulldown_cmark::{html, CodeBlockKind, Event, HeadingLevel, Options, Parser, Tag, TagEnd};
use regex::Regex;
use serde::{Deserialize, Serialize};
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

use std::collections::{HashMap, HashSet};
use std::hash::{DefaultHasher, Hash, Hasher};

fn escape_html(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
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

fn base_slug(title: &str) -> String {
    let mut slug = String::with_capacity(title.len());
    let mut in_whitespace = false;
    for c in title.trim().chars() {
        if c.is_alphanumeric() || c == '-' || c == '_' {
            for lc in c.to_lowercase() {
                slug.push(lc);
            }
            in_whitespace = false;
        } else if c.is_whitespace() {
            if !in_whitespace && !slug.is_empty() {
                slug.push('-');
                in_whitespace = true;
            }
        }
    }
    while slug.ends_with('-') {
        slug.pop();
    }
    if slug.is_empty() {
        "section".to_string()
    } else {
        slug
    }
}

fn compute_diagram_cache_key(renderer: &str, theme: &str, source: &str) -> String {
    let mut hasher = DefaultHasher::new();
    renderer.hash(&mut hasher);
    theme.hash(&mut hasher);
    source.hash(&mut hasher);
    format!("{renderer}-{:016x}", hasher.finish())
}

// GFM Security Tagfilter: disarm script, iframe, textarea, title, xmp, noembed, noframes, plaintext
// Note: <style> is explicitly preserved per MDVu spec.
static DISALLOWED_TAG_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?is)<(/?)((?:script|iframe|textarea|title|xmp|noembed|noframes|plaintext))([/\s][^>]*|)>"#).unwrap()
});

fn apply_tagfilter(raw_html: &str) -> String {
    if !raw_html.contains('<') {
        return raw_html.to_string();
    }
    DISALLOWED_TAG_RE
        .replace_all(raw_html, |caps: &regex::Captures| {
            let slash = &caps[1];
            let tag_name = &caps[2];
            let rest = &caps[3];
            format!("&lt;{slash}{tag_name}{rest}>")
        })
        .into_owned()
}

pub struct MarkdownParser {
    pub diagram_theme: String,
}

impl MarkdownParser {
    pub fn new(diagram_theme: &str) -> Self {
        Self {
            diagram_theme: diagram_theme.to_string(),
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

        let mut custom_events = Vec::new();
        let mut inside_code_block: Option<String> = None;
        let mut code_buffer = String::new();

        let mut current_heading_level: Option<HeadingLevel> = None;
        let mut current_heading_text = String::new();
        let mut toc = Vec::new();
        let mut doc_title: Option<String> = None;
        let mut slug_counts: HashMap<String, usize> = HashMap::new();
        let mut used_slug_ids: HashSet<String> = HashSet::new();

        let mut has_mermaid = false;
        let mut has_plantuml = false;
        let mut has_math = source.contains("math-inline") || source.contains("math-display");

        for event in parser {
            match event {
                Event::Html(raw) => {
                    let filtered = apply_tagfilter(&raw);
                    custom_events.push(Event::Html(filtered.into()));
                }
                Event::InlineHtml(raw) => {
                    let filtered = apply_tagfilter(&raw);
                    custom_events.push(Event::InlineHtml(filtered.into()));
                }
                Event::Start(Tag::CodeBlock(CodeBlockKind::Fenced(lang))) => {
                    inside_code_block = Some(lang.to_string());
                    code_buffer.clear();
                }
                Event::Start(Tag::CodeBlock(CodeBlockKind::Indented)) => {
                    inside_code_block = Some(String::new());
                    code_buffer.clear();
                }
                Event::End(TagEnd::CodeBlock) => {
                    if let Some(lang) = inside_code_block.take() {
                        let clean_lang = lang.trim().to_lowercase();
                        let trimmed_code = code_buffer.trim_matches(|c| c == '\n' || c == '\r');

                        if clean_lang == "mermaid" {
                            has_mermaid = true;
                            let key = compute_diagram_cache_key("mermaid", &self.diagram_theme, trimmed_code);
                            let html = format!(
                                "<figure class=\"diagram diagram-pending\" data-renderer=\"mermaid\" data-cache-key=\"{key}\"><pre>{}</pre><div class=\"diagram-status\">Rendering diagram…</div></figure>",
                                escape_html(trimmed_code)
                            );
                            custom_events.push(Event::Html(html.into()));
                        } else if clean_lang == "plantuml" || clean_lang == "puml" {
                            has_plantuml = true;
                            let key = compute_diagram_cache_key("plantuml", &self.diagram_theme, trimmed_code);
                            let html = format!(
                                "<figure class=\"diagram diagram-pending\" data-renderer=\"plantuml\" data-cache-key=\"{key}\"><pre>{}</pre><div class=\"diagram-status\">Rendering diagram…</div></figure>",
                                escape_html(trimmed_code)
                            );
                            custom_events.push(Event::Html(html.into()));
                        } else if clean_lang == "math" || clean_lang == "latex" || clean_lang == "katex" {
                            has_math = true;
                            let html = format!(
                                "<div class=\"math-display\">{}</div>",
                                escape_html(trimmed_code)
                            );
                            custom_events.push(Event::Html(html.into()));
                        } else {
                            let class_attr = if clean_lang.is_empty() {
                                String::new()
                            } else {
                                format!(" class=\"language-{clean_lang}\"")
                            };
                            let html = format!(
                                "<pre><code{class_attr}>{}</code></pre>",
                                escape_html(trimmed_code)
                            );
                            custom_events.push(Event::Html(html.into()));
                        }
                    }
                }
                Event::Text(ref text) if inside_code_block.is_some() => {
                    code_buffer.push_str(text);
                }
                Event::Start(Tag::Heading { level, .. }) => {
                    current_heading_level = Some(level);
                    current_heading_text.clear();
                    custom_events.push(event);
                }
                Event::End(TagEnd::Heading(_)) => {
                    if let Some(level) = current_heading_level.take() {
                        let title = current_heading_text.trim().to_string();
                        let base = base_slug(&title);
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
                    custom_events.push(event);
                }
                Event::Text(ref text) if current_heading_level.is_some() => {
                    current_heading_text.push_str(text);
                    custom_events.push(event);
                }
                _ => {
                    custom_events.push(event);
                }
            }
        }

        let mut html_out = String::with_capacity(source.len() * 2);
        html::push_html(&mut html_out, custom_events.into_iter());

        let postprocessed = Self::replace_callout_blocks(&html_out);
        let final_body = apply_tagfilter(&postprocessed);

        RenderedDocument {
            body: final_body,
            title: doc_title,
            toc,
            has_mermaid,
            has_plantuml,
            has_math,
        }
    }

    fn replace_callout_blocks(input: &str) -> String {
        let marker = "MDVU-CALLOUT-" ;
        if !input.contains(marker) {
            return input.to_string();
        }

        let mut result = String::with_capacity(input.len());
        let mut cursor = 0;

        while let Some(marker_rel) = input[cursor..].find(marker) {
            let marker_pos = cursor + marker_rel;

            // Search back for <blockquote>
            let search_back_start = if marker_pos > cursor + 200 {
                marker_pos - 200
            } else {
                cursor
            };

            let Some(bq_rel) = input[search_back_start..marker_pos].rfind("<blockquote>") else {
                result.push_str(&input[cursor..marker_pos + marker.len()]);
                cursor = marker_pos + marker.len();
                continue;
            };
            let bq_start = search_back_start + bq_rel;

            // Find matching </blockquote> taking into account nested blockquotes
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

            // Extract callout type from marker up to </strong>
            let marker_end = marker_pos + marker.len();
            let Some(strong_end_rel) = input[marker_end..bq_end_pos].find("</strong>") else {
                result.push_str(&input[cursor..marker_end]);
                cursor = marker_end;
                continue;
            };
            let strong_end_pos = marker_end + strong_end_rel;
            let callout_type = input[marker_end..strong_end_pos].trim().to_lowercase();

            // Find closing </p>
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
            let processed_body = if body.contains("MDVU-CALLOUT-") {
                Self::replace_callout_blocks(body)
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
        assert!(doc.body.contains("&lt;iframe src=\"evil.com\">&lt;/iframe>"));
    }

    #[test]
    fn test_tagfilter_disarms_inline_and_multiline_script() {
        let md = "Inline <script>alert(1)</script> here and <script\nsrc=\"malicious.js\">\n</script>";
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
    fn test_duplicate_heading_slug_generation() {
        let md = "# Introduction\n\n## Section\n\n## Section\n\n## Section\n\n## Section 1\n";
        let parser = MarkdownParser::new("light");
        let doc = parser.render(md);
        let ids: Vec<&str> = doc.toc.iter().map(|t| t.id.as_str()).collect();
        assert_eq!(ids, vec!["introduction", "section", "section-1", "section-2", "section-1-1"]);
    }

    #[test]
    fn test_diagram_cache_key_collision_resistance() {
        let key1 = compute_diagram_cache_key("mermaid", "light", "graph TD\n  A --> B");
        let key2 = compute_diagram_cache_key("mermaid", "light", "graph TD\n  C --> D");
        assert_eq!(key1.len(), "mermaid-".len() + 16);
        assert_ne!(key1, key2);
    }
}
