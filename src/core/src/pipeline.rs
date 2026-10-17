use regex::{Captures, Regex};
use std::borrow::Cow;
use std::sync::LazyLock;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum MarkdownDialect {
    #[default]
    Generic,
    Commonmark,
    Gfm,
    Obsidian,
    Docusaurus,
    Mkdocs,
    Hugo,
}

impl MarkdownDialect {
    pub fn from_str_name(s: &str) -> Option<Self> {
        let clean = s.trim().to_ascii_lowercase().replace(['-', '_'], "");
        match clean.as_str() {
            "generic" | "default" | "auto" | "automatic" => Some(Self::Generic),
            "commonmark" | "cm" => Some(Self::Commonmark),
            "gfm" | "github" => Some(Self::Gfm),
            "obsidian" => Some(Self::Obsidian),
            "docusaurus" => Some(Self::Docusaurus),
            "mkdocs" => Some(Self::Mkdocs),
            "hugo" => Some(Self::Hugo),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Generic => "generic",
            Self::Commonmark => "commonmark",
            Self::Gfm => "gfm",
            Self::Obsidian => "obsidian",
            Self::Docusaurus => "docusaurus",
            Self::Mkdocs => "mkdocs",
            Self::Hugo => "hugo",
        }
    }
}

pub struct FastScan;

impl FastScan {
    #[inline(always)]
    pub fn contains_ascii(s: &str, ascii: u8) -> bool {
        memchr::memchr(ascii, s.as_bytes()).is_some()
    }

    #[inline(always)]
    pub fn count_ascii(s: &str, ascii: u8, at_least: usize) -> bool {
        let mut count = 0;
        for _ in memchr::memchr_iter(ascii, s.as_bytes()) {
            count += 1;
            if count >= at_least {
                return true;
            }
        }
        false
    }

    #[inline(always)]
    pub fn contains_token(haystack: &str, token: &str) -> bool {
        if token.is_empty() {
            return true;
        }
        if token.len() == 1 {
            return Self::contains_ascii(haystack, token.as_bytes()[0]);
        }
        memchr::memmem::find(haystack.as_bytes(), token.as_bytes()).is_some()
    }
}

pub struct MarkdownDocumentDirective;

static COMMENT_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(?s)<!--(.*?)-->").unwrap());
static DIRECTIVE_IN_COMMENT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?:(?i-u:dialect|markdown[-_]dialect)[ \t]*[:=][ \t]*|--(?i-u:dialect)[ \t]+)["'`]?([a-zA-Z_-]+)["'`]?|(?:^|[^a-zA-Z0-9_])(?i-u:in)[ \t]+["'`]?([a-zA-Z_-]+)["'`]?[ \t]+(?i-u:dialect)(?:$|[^a-zA-Z0-9_])"#).unwrap()
});

impl MarkdownDocumentDirective {
    pub fn extract_dialect(source: &str) -> Option<MarkdownDialect> {
        if let Some(dialect) = Self::extract_from_front_matter(source) {
            return Some(dialect);
        }

        let prefix = if source.len() > 4096 {
            let mut end = 4096;
            while end > 0 && !source.is_char_boundary(end) {
                end -= 1;
            }
            &source[..end]
        } else {
            source
        };

        let trimmed = prefix.trim_start();
        if trimmed.starts_with("<!--") {
            if let Some(caps) = COMMENT_RE.captures(trimmed) {
                let comment_content = caps.get(1)?.as_str();
                if let Some(dir_caps) = DIRECTIVE_IN_COMMENT_RE.captures(comment_content) {
                    let val = dir_caps
                        .get(1)
                        .or_else(|| dir_caps.get(2))
                        .map(|m| m.as_str())?;
                    return MarkdownDialect::from_str_name(val);
                }
            }
        }

        None
    }

    fn extract_from_front_matter(source: &str) -> Option<MarkdownDialect> {
        let is_lf = source.starts_with("---\n");
        let is_crlf = source.starts_with("---\r\n");
        if !is_lf && !is_crlf {
            return None;
        }

        let header_len = if is_crlf { 5 } else { 4 };
        let separator = if is_crlf { "\r\n---\r\n" } else { "\n---\n" };
        let end_idx = source[header_len..].find(separator)?;
        let yaml = &source[header_len..header_len + end_idx];

        for line in yaml.lines() {
            if let Some((k, v)) = line.split_once(':') {
                let key = k.trim().to_ascii_lowercase();
                if key == "dialect"
                    || key == "markdown-dialect"
                    || key == "markdown_dialect"
                    || key == "mode"
                {
                    if let Some(d) = MarkdownDialect::from_str_name(v.trim()) {
                        return Some(d);
                    }
                }
            }
        }
        None
    }
}

pub struct CodeFenceScanner;

impl CodeFenceScanner {
    pub fn process<F>(source: &str, mut transform: F) -> String
    where
        F: FnMut(&str) -> String,
    {
        Self::process_cow(source, |chunk| Cow::Owned(transform(chunk))).into_owned()
    }

    pub fn process_cow<'a, F>(source: &'a str, mut transform: F) -> Cow<'a, str>
    where
        F: FnMut(&'a str) -> Cow<'a, str>,
    {
        use pulldown_cmark::{Event, Options, Parser, Tag, TagEnd};
        let mut ranges: Vec<std::ops::Range<usize>> = Vec::new();
        let mut block_start = None;
        let mut protected_depth = 0usize;
        for (event, range) in Parser::new_ext(source, Options::ENABLE_TABLES).into_offset_iter() {
            match event {
                Event::Start(Tag::CodeBlock(_) | Tag::Link { .. } | Tag::Image { .. }) => {
                    if protected_depth == 0 {
                        block_start = Some(range.start);
                    }
                    protected_depth += 1;
                }
                Event::End(TagEnd::CodeBlock | TagEnd::Link | TagEnd::Image) => {
                    protected_depth = protected_depth.saturating_sub(1);
                    if protected_depth == 0 {
                        if let Some(start) = block_start.take() {
                            ranges.push(start..range.end);
                        }
                    }
                }
                Event::Html(ref raw) | Event::InlineHtml(ref raw) if block_start.is_none() => {
                    let closing = if raw.starts_with("<span class=\"math-inline\">") {
                        Some("</span>")
                    } else if raw.starts_with("<div class=\"math-display\">") {
                        Some("</div>")
                    } else {
                        None
                    };
                    let end = closing
                        .and_then(|tag| {
                            source[range.end..]
                                .find(tag)
                                .map(|n| range.end + n + tag.len())
                        })
                        .unwrap_or(range.end);
                    ranges.push(range.start..end);
                }
                Event::Code(_) if block_start.is_none() => ranges.push(range),
                _ => {}
            }
        }
        ranges.sort_by_key(|r| r.start);
        let mut output: Option<String> = None;
        let mut cursor = 0;
        for range in ranges
            .into_iter()
            .chain(std::iter::once(source.len()..source.len()))
        {
            if range.start < cursor {
                continue;
            }
            let chunk = &source[cursor..range.start];
            let changed = transform(chunk);
            if !matches!(changed, Cow::Borrowed(_)) && output.is_none() {
                let mut out = String::with_capacity(source.len());
                out.push_str(&source[..cursor]);
                output = Some(out);
            }
            if let Some(out) = &mut output {
                out.push_str(&changed);
                out.push_str(&source[range.clone()]);
            }
            cursor = range.end;
        }
        output.map(Cow::Owned).unwrap_or(Cow::Borrowed(source))
    }
}

pub struct MarkdownPipeline {
    dialect: MarkdownDialect,
    is_dialect_explicit: bool,
}

static OBSIDIAN_CALLOUT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?m)^([ \t]*>[ \t]*)\[!([A-Za-z]+)\][+-]?[ \t]*(.*)$"#).unwrap()
});
static OBSIDIAN_EMBED_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"!\[\[([^\]]+)\]\]"#).unwrap());
static OBSIDIAN_WIKILINK_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"\[\[([^\]|#]+)(#[^\]|]+)?(?:\|([^\]]+))?\]\]"#).unwrap());
static GITLAB_TOC_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?m)^[ \t]*(?:\[\[_TOC_\]\]|\[TOC\])[ \t]*$"#).unwrap());
static MKDOCS_START_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"^([ \t]*)(\!{3}|\?{3}\+|\?{3})[ \t]+([a-zA-Z]+)(?:[ \t]+"([^"\n\r]*)")?[ \t]*$"#)
        .unwrap()
});
static COLON_START_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"^([ \t]*):{3,4}([a-zA-Z]+)(?:\[([^\]\n\r]*)\])?[ \t]*$"#).unwrap()
});
static COLON_END_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"^[ \t]*:{3,4}[ \t]*$"#).unwrap());

static CRITIC_SUB_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?s)\{\~\~(.*?)\~>(.*?)\~\~\}"#).unwrap());
static CRITIC_ADD_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?s)\{\+\+(.*?)\+\+\}"#).unwrap());
static CRITIC_DEL_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?s)\{--(.*?)--\}"#).unwrap());
static CRITIC_MARK_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?s)\{==(.*?)==\}"#).unwrap());
static CRITIC_COMMENT_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?s)\{>>(.*?)<<\}"#).unwrap());

use crate::parser::escape_html;

fn apply<'a>(value: Cow<'a, str>, stage: impl FnOnce(&str) -> Cow<'_, str>) -> Cow<'a, str> {
    match value {
        Cow::Borrowed(s) => stage(s),
        Cow::Owned(s) => match stage(&s) {
            Cow::Borrowed(_) => Cow::Owned(s),
            Cow::Owned(next) => Cow::Owned(next),
        },
    }
}

impl MarkdownPipeline {
    pub fn new(dialect: MarkdownDialect, is_dialect_explicit: bool) -> Self {
        Self {
            dialect,
            is_dialect_explicit,
        }
    }

    pub fn effective_dialect(&self, source: &str) -> MarkdownDialect {
        if self.is_dialect_explicit {
            self.dialect
        } else {
            MarkdownDocumentDirective::extract_dialect(source).unwrap_or(self.dialect)
        }
    }

    pub fn preprocess(&self, source: &str) -> (String, MarkdownDialect) {
        let (cow, dialect) = self.preprocess_cow(source);
        (cow.into_owned(), dialect)
    }

    pub fn preprocess_cow<'a>(&self, source: &'a str) -> (Cow<'a, str>, MarkdownDialect) {
        let dialect = self.effective_dialect(source);

        let mut value = Self::preprocess_frontmatter(source);
        value = apply(value, Self::preprocess_gitlab_toc);
        value = apply(value, Self::preprocess_admonitions);
        value = apply(value, |s| Self::preprocess_obsidian(s, dialect));
        value = apply(value, Self::preprocess_math);
        value = apply(value, Self::preprocess_inline_markup);
        (value, dialect)
    }

    fn preprocess_frontmatter(source: &str) -> Cow<'_, str> {
        let is_lf = source.starts_with("---\n");
        let is_crlf = source.starts_with("---\r\n");
        if !is_lf && !is_crlf {
            return Cow::Borrowed(source);
        }

        let header_len = if is_crlf { 5 } else { 4 };
        let separator = if is_crlf { "\r\n---\r\n" } else { "\n---\n" };
        let Some(end_idx) = source[header_len..].find(separator) else {
            return Cow::Borrowed(source);
        };

        let yaml = &source[header_len..header_len + end_idx];
        let mut rows = Vec::new();
        for line in yaml.lines() {
            if let Some((k, v)) = line.split_once(':') {
                rows.push(format!("| {} | {} |", k.trim(), v.trim()));
            }
        }

        let rest = &source[header_len + end_idx + separator.len()..];
        if rows.is_empty() {
            Cow::Borrowed(rest)
        } else {
            Cow::Owned(format!(
                "**Document metadata**\n\n| Field | Value |\n|---|---|\n{}\n\n{}",
                rows.join("\n"),
                rest
            ))
        }
    }

    fn preprocess_gitlab_toc(source: &str) -> Cow<'_, str> {
        if !FastScan::contains_token(source, "[[_TOC_]]")
            && !FastScan::contains_token(source, "[TOC]")
        {
            return Cow::Borrowed(source);
        }
        CodeFenceScanner::process_cow(source, |chunk| {
            GITLAB_TOC_RE.replace_all(
                chunk,
                "<p class=\"toc-placeholder\"><a href=\"#table-of-contents\">Table of Contents</a></p>",
            )
        })
    }

    fn preprocess_admonitions(source: &str) -> Cow<'_, str> {
        if !FastScan::contains_token(source, "!!!")
            && !FastScan::contains_token(source, "???")
            && !FastScan::contains_token(source, ":::")
        {
            return Cow::Borrowed(source);
        }

        let mut output = Vec::new();
        let mut in_mkdocs = false;
        let mut mkdocs_pending_blank_lines = 0;
        let mut in_colon_admonition = false;
        let mut active_fence: Option<String> = None;

        macro_rules! end_mkdocs {
            () => {
                if in_mkdocs {
                    #[allow(unused_assignments)]
                    {
                        in_mkdocs = false;
                    }
                    mkdocs_pending_blank_lines = 0;
                    output.push(String::new());
                    output.push("<!-- -->".to_string());
                    output.push(String::new());
                }
            };
        }

        for line in source.lines() {
            let trimmed = line.trim();

            if let Some(ref fence) = active_fence {
                if trimmed.starts_with(fence) {
                    active_fence = None;
                }
                if in_colon_admonition {
                    output.push(format!("> {line}"));
                } else {
                    output.push(line.to_string());
                }
            } else if in_mkdocs && (line.starts_with("    ") || line.starts_with('\t')) {
                while mkdocs_pending_blank_lines > 0 {
                    output.push(">".to_string());
                    mkdocs_pending_blank_lines -= 1;
                }
                let stripped = if let Some(stripped) = line.strip_prefix("    ") {
                    stripped
                } else {
                    &line[1..]
                };
                output.push(format!("> {stripped}"));
            } else if in_mkdocs && trimmed.is_empty() {
                mkdocs_pending_blank_lines += 1;
            } else if trimmed.starts_with("```") || trimmed.starts_with("~~~") {
                let fence_char = trimmed.chars().next().unwrap();
                let count = trimmed.chars().take_while(|&c| c == fence_char).count();
                active_fence = Some(fence_char.to_string().repeat(count));
                if in_colon_admonition {
                    output.push(format!("> {line}"));
                } else {
                    end_mkdocs!();
                    output.push(line.to_string());
                }
            } else if in_colon_admonition {
                if COLON_END_RE.is_match(line) {
                    in_colon_admonition = false;
                    output.push(String::new());
                    output.push("<!-- -->".to_string());
                    output.push(String::new());
                } else {
                    output.push(format!("> {line}"));
                }
            } else {
                if in_mkdocs {
                    end_mkdocs!();
                }
                if trimmed.starts_with('!') || trimmed.starts_with('?') || trimmed.starts_with(':')
                {
                    if let Some(caps) = MKDOCS_START_RE.captures(line) {
                        end_mkdocs!();
                        in_mkdocs = true;
                        let marker = caps.get(2).map(|m| m.as_str()).unwrap_or("");
                        let ad_type = caps
                            .get(3)
                            .map(|m| m.as_str())
                            .unwrap_or("")
                            .to_ascii_uppercase();
                        let title = caps.get(4).map(|m| m.as_str()).unwrap_or("");
                        let fold = if marker.starts_with("???+") {
                            "+"
                        } else if marker.starts_with("???") {
                            "-"
                        } else {
                            ""
                        };
                        let title_part = if title.is_empty() {
                            String::new()
                        } else {
                            format!(" {title}")
                        };
                        output.push(format!("> [!{ad_type}]{fold}{title_part}"));
                    } else if let Some(caps) = COLON_START_RE.captures(line) {
                        end_mkdocs!();
                        in_colon_admonition = true;
                        let ad_type = caps
                            .get(2)
                            .map(|m| m.as_str())
                            .unwrap_or("")
                            .to_ascii_uppercase();
                        let title = caps.get(3).map(|m| m.as_str()).unwrap_or("");
                        let title_part = if title.is_empty() {
                            String::new()
                        } else {
                            format!(" {title}")
                        };
                        output.push(format!("> [!{ad_type}]{title_part}"));
                    } else {
                        output.push(line.to_string());
                    }
                } else {
                    output.push(line.to_string());
                }
            }
        }

        Cow::Owned(output.join("\n"))
    }

    fn preprocess_obsidian(source: &str, dialect: MarkdownDialect) -> Cow<'_, str> {
        let has_callout = FastScan::contains_token(source, "[!");
        let has_wiki =
            dialect == MarkdownDialect::Obsidian && FastScan::contains_token(source, "[[");
        if !has_callout && !has_wiki {
            return Cow::Borrowed(source);
        }

        CodeFenceScanner::process_cow(source, |chunk| {
            let mut text: Cow<'_, str> = Cow::Borrowed(chunk);
            if has_callout && FastScan::contains_token(&text, "[!") {
                if let Cow::Owned(replaced) =
                    OBSIDIAN_CALLOUT_RE.replace_all(&text, |caps: &Captures| {
                        let indent = &caps[1];
                        let callout_type = caps[2].to_ascii_uppercase();
                        let title = &caps[3];
                        format!("{indent}**MDVU-CALLOUT-{callout_type}** {title}\n{indent}")
                    })
                {
                    text = Cow::Owned(replaced);
                }
            }
            if has_wiki && FastScan::contains_token(&text, "![[") {
                if let Cow::Owned(replaced) =
                    OBSIDIAN_EMBED_RE.replace_all(&text, |caps: &Captures| {
                        let target = &caps[1];
                        format!(
                            "![{}](<{}>)",
                            target.replace('[', "\\[").replace(']', "\\]"),
                            encode_destination(target)
                        )
                    })
                {
                    text = Cow::Owned(replaced);
                }
            }
            if has_wiki && FastScan::contains_token(&text, "[[") {
                if let Cow::Owned(replaced) =
                    OBSIDIAN_WIKILINK_RE.replace_all(&text, |caps: &Captures| {
                        let target_base = &caps[1];
                        let anchor = caps.get(2).map(|m| m.as_str()).unwrap_or("");
                        let label = caps
                            .get(3)
                            .map(|m| m.as_str())
                            .filter(|s| !s.is_empty())
                            .unwrap_or(target_base);
                        let target = if target_base.to_ascii_lowercase().ends_with(".md") {
                            target_base.to_string()
                        } else {
                            format!("{target_base}.md")
                        };
                        format!(
                            "[{}](<{}>)",
                            label.replace('[', "\\[").replace(']', "\\]"),
                            encode_destination(&format!("{target}{anchor}"))
                        )
                    })
                {
                    text = Cow::Owned(replaced);
                }
            }
            text
        })
    }

    fn has_critic_markup(source: &str) -> bool {
        FastScan::contains_token(source, "{+")
            || FastScan::contains_token(source, "{-")
            || FastScan::contains_token(source, "{~")
            || FastScan::contains_token(source, "{=")
            || FastScan::contains_token(source, "{>")
    }

    fn preprocess_critic_markup(source: &str) -> Cow<'_, str> {
        if !Self::has_critic_markup(source) {
            return Cow::Borrowed(source);
        }

        let mut text: Cow<'_, str> = Cow::Borrowed(source);
        if FastScan::contains_token(&text, "{~") {
            if let Cow::Owned(replaced) = CRITIC_SUB_RE.replace_all(
                &text,
                "<del class=\"critic-del\">$1</del><ins class=\"critic-add\">$2</ins>",
            ) {
                text = Cow::Owned(replaced);
            }
        }
        if FastScan::contains_token(&text, "{+") {
            if let Cow::Owned(replaced) =
                CRITIC_ADD_RE.replace_all(&text, "<ins class=\"critic-add\">$1</ins>")
            {
                text = Cow::Owned(replaced);
            }
        }
        if FastScan::contains_token(&text, "{-") {
            if let Cow::Owned(replaced) =
                CRITIC_DEL_RE.replace_all(&text, "<del class=\"critic-del\">$1</del>")
            {
                text = Cow::Owned(replaced);
            }
        }
        if FastScan::contains_token(&text, "{=") {
            if let Cow::Owned(replaced) =
                CRITIC_MARK_RE.replace_all(&text, "<mark class=\"critic-mark\">$1</mark>")
            {
                text = Cow::Owned(replaced);
            }
        }
        if FastScan::contains_token(&text, "{>") {
            if let Cow::Owned(replaced) = CRITIC_COMMENT_RE.replace_all(&text, |caps: &Captures| {
                let comment = &caps[1];
                let safe_title = escape_html(comment);
                format!("<span class=\"critic-comment\" title=\"{safe_title}\">💬 {comment}</span>")
            }) {
                text = Cow::Owned(replaced);
            }
        }
        text
    }

    fn preprocess_inline_markup(source: &str) -> Cow<'_, str> {
        if !Self::has_critic_markup(source)
            && !FastScan::count_ascii(source, b'~', 2)
            && !FastScan::count_ascii(source, b'^', 2)
        {
            return Cow::Borrowed(source);
        }
        // Both transformations protect the same Markdown ranges. Parse them
        // once, retaining the order and avoiding another full-document copy.
        CodeFenceScanner::process_cow(source, |chunk| {
            let value = Self::preprocess_critic_markup(chunk);
            apply(value, |text| {
                if FastScan::count_ascii(text, b'~', 2) || FastScan::count_ascii(text, b'^', 2) {
                    Self::scan_sub_sup_underline(text)
                } else {
                    Cow::Borrowed(text)
                }
            })
        })
    }

    /// Single-pass scanner for `^^underline^^`, `^sup^`, and `~sub~` that safely skips:
    /// - Inline backticks `` `...` ``
    /// - Rendered math blocks `<span class="math-inline">...</span>` and `<div class="math-display">...</div>`
    /// - HTML tags `<...>` (e.g. URLs with `~user`)
    fn scan_sub_sup_underline(input: &str) -> Cow<'_, str> {
        let bytes = input.as_bytes();
        let len = bytes.len();
        let mut result: Option<String> = None;
        let mut i = 0;
        let mut last_copied = 0;

        while i < len {
            let b = bytes[i];

            // 1. Skip inline code spans: `...`
            if b == b'`' {
                let mut scan = i;
                while scan < len && bytes[scan] == b'`' {
                    scan += 1;
                }
                let tick_count = scan - i;
                let mut search = scan;
                let mut found_close = None;
                while search + tick_count <= len {
                    if bytes[search..search + tick_count]
                        .iter()
                        .all(|&c| c == b'`')
                        && (search + tick_count == len || bytes[search + tick_count] != b'`')
                    {
                        found_close = Some(search + tick_count);
                        break;
                    }
                    search += 1;
                }
                i = found_close.unwrap_or(scan);
                continue;
            }

            // 2. Skip math spans/divs and HTML tags
            if b == b'<' {
                let rem = &input[i..];
                if rem.starts_with("<span class=\"math-inline\">") {
                    if let Some(end_rel) = rem.find("</span>") {
                        i += end_rel + 7;
                        continue;
                    }
                } else if rem.starts_with("<div class=\"math-display\">") {
                    if let Some(end_rel) = rem.find("</div>") {
                        i += end_rel + 6;
                        continue;
                    }
                }
                // Skip up to closing '>' of HTML tag on the same line
                let mut tag_end = i + 1;
                while tag_end < len && bytes[tag_end] != b'>' && bytes[tag_end] != b'\n' {
                    tag_end += 1;
                }
                if tag_end < len && bytes[tag_end] == b'>' {
                    i = tag_end + 1;
                    continue;
                }
            }

            // 3. Skip escaped character
            if b == b'\\' {
                i += 2;
                continue;
            }

            // 4. Check for ^^underline^^
            if b == b'^' && i + 1 < len && bytes[i + 1] == b'^' {
                let content_start = i + 2;
                let mut j = content_start;
                let mut found_close = None;
                while j + 1 < len {
                    let bj = bytes[j];
                    if bj == b'\n' || bj == b'\r' {
                        break;
                    }
                    if bj == b'^' && bytes[j + 1] == b'^' && j > content_start {
                        found_close = Some(j);
                        break;
                    }
                    j += 1;
                }
                if let Some(close_idx) = found_close {
                    let out = result.get_or_insert_with(|| String::with_capacity(len + 32));
                    out.push_str(&input[last_copied..i]);
                    out.push_str("<u>");
                    out.push_str(&input[content_start..close_idx]);
                    out.push_str("</u>");
                    i = close_idx + 2;
                    last_copied = i;
                    continue;
                } else {
                    i += 2;
                    continue;
                }
            }

            // 5. Check for single ^sup^ or ~sub~ (no internal whitespace)
            if b == b'^' || b == b'~' {
                let prev_is_delim = i > 0 && bytes[i - 1] == b;
                let next_is_delim = i + 1 < len && bytes[i + 1] == b;
                if !prev_is_delim && !next_is_delim {
                    let mut j = i + 1;
                    let mut found_close = None;
                    while j < len {
                        let bj = bytes[j];
                        if bj.is_ascii_whitespace() || bj == b'<' || bj == b'`' {
                            break;
                        }
                        if bj == b {
                            let next_next = j + 1 < len && bytes[j + 1] == b;
                            if !next_next && j > i + 1 {
                                found_close = Some(j);
                            }
                            break;
                        }
                        j += 1;
                    }
                    if let Some(close_idx) = found_close {
                        let tag = if b == b'^' { "sup" } else { "sub" };
                        let out = result.get_or_insert_with(|| String::with_capacity(len + 32));
                        out.push_str(&input[last_copied..i]);
                        out.push('<');
                        out.push_str(tag);
                        out.push('>');
                        out.push_str(&input[i + 1..close_idx]);
                        out.push_str("</");
                        out.push_str(tag);
                        out.push('>');
                        i = close_idx + 1;
                        last_copied = i;
                        continue;
                    }
                }
            }

            i += 1;
        }

        match result {
            Some(mut out) => {
                if last_copied < len {
                    out.push_str(&input[last_copied..]);
                }
                Cow::Owned(out)
            }
            None => Cow::Borrowed(input),
        }
    }

    fn preprocess_math(source: &str) -> Cow<'_, str> {
        if !FastScan::count_ascii(source, b'$', 2) {
            return Cow::Borrowed(source);
        }

        CodeFenceScanner::process_cow(source, |chunk| {
            if !FastScan::count_ascii(chunk, b'$', 2) {
                return Cow::Borrowed(chunk);
            }
            Self::scan_math_in_chunk(chunk)
        })
    }

    fn scan_math_in_chunk(chunk: &str) -> Cow<'_, str> {
        let bytes = chunk.as_bytes();
        let mut inline_closes = Vec::new();
        let mut display_closes = Vec::new();
        let mut i = 0;
        while i < bytes.len() {
            if bytes[i] == b'\\' {
                i += 2;
                continue;
            }
            if bytes[i] == b'$' {
                if i + 1 < bytes.len() && bytes[i + 1] == b'$' {
                    display_closes.push(i);
                    i += 2;
                    continue;
                }
                if i > 0 && !bytes[i - 1].is_ascii_whitespace() {
                    inline_closes.push(i);
                }
            }
            i += 1;
        }
        let (mut inline_idx, mut display_idx, mut cursor, mut copied) = (0, 0, 0, 0);
        let mut line_end = 0;
        let mut output: Option<String> = None;
        while cursor < bytes.len() {
            if bytes[cursor] == b'\\' {
                cursor += 2;
                continue;
            }
            if cursor >= line_end {
                line_end = memchr::memchr2(b'\n', b'\r', &bytes[cursor..])
                    .map(|n| cursor + n)
                    .unwrap_or(bytes.len());
            }
            if bytes[cursor] == b'$' {
                let display = bytes.get(cursor + 1) == Some(&b'$');
                let start = cursor + if display { 2 } else { 1 };
                let close = if display {
                    while display_idx < display_closes.len() && display_closes[display_idx] < start
                    {
                        display_idx += 1;
                    }
                    display_closes.get(display_idx).copied()
                } else if start < bytes.len() && !bytes[start].is_ascii_whitespace() {
                    while inline_idx < inline_closes.len() && inline_closes[inline_idx] <= start {
                        inline_idx += 1;
                    }
                    inline_closes
                        .get(inline_idx)
                        .copied()
                        .filter(|n| *n < line_end)
                } else {
                    None
                };
                if let Some(end) = close {
                    let out = output.get_or_insert_with(|| String::with_capacity(chunk.len() + 64));
                    out.push_str(&chunk[copied..cursor]);
                    let tex = &chunk[start..end];
                    if display {
                        out.push_str("<div class=\"math-display\">");
                    } else {
                        out.push_str("<span class=\"math-inline\">");
                    }
                    out.push_str(&escape_html(if display { tex.trim() } else { tex }));
                    out.push_str(if display { "</div>" } else { "</span>" });
                    cursor = end + if display { 2 } else { 1 };
                    copied = cursor;
                    continue;
                }
                if display {
                    cursor += 2;
                    continue;
                }
            }
            cursor += 1;
        }
        match output {
            Some(mut out) => {
                out.push_str(&chunk[copied..]);
                Cow::Owned(out)
            }
            None => Cow::Borrowed(chunk),
        }
    }
}

fn encode_destination(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for ch in value.chars() {
        match ch {
            ' ' => out.push_str("%20"),
            '<' => out.push_str("%3C"),
            '>' => out.push_str("%3E"),
            '"' => out.push_str("%22"),
            '\n' => out.push_str("%0A"),
            '\r' => out.push_str("%0D"),
            '\t' => out.push_str("%09"),
            _ => out.push(ch),
        }
    }
    out
}
