use crate::assets::{get_katex_js, get_mermaid_js, get_plantuml_js, APP_JS, MARKDOWN_CSS};

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

pub fn make_html_selective(
    body: &str,
    title: &str,
    theme: &str,
    full_width: bool,
    base_url: Option<&str>,
    embed_katex: bool,
    embed_mermaid: bool,
    embed_plantuml: bool,
) -> String {
    let base_tag = match base_url {
        Some(url) => format!("<base href=\"{}\">", escape_html(url)),
        None => String::new(),
    };

    let full_width_class = if full_width { "full-width" } else { "" };
    let theme_val = if theme.is_empty() { "system" } else { theme };

    let mut extra_scripts = String::new();
    if embed_katex {
        if let Ok(katex) = get_katex_js() {
            extra_scripts.push_str("<script>");
            extra_scripts.push_str(katex);
            extra_scripts.push_str("</script>\n");
        }
    }
    if embed_mermaid {
        if let Ok(mermaid) = get_mermaid_js() {
            extra_scripts.push_str("<script>");
            extra_scripts.push_str(mermaid);
            extra_scripts.push_str("</script>\n");
        }
    }
    if embed_plantuml {
        if let Ok(plantuml) = get_plantuml_js() {
            extra_scripts.push_str("<script>");
            extra_scripts.push_str(plantuml);
            extra_scripts.push_str("</script>\n");
        }
    }

    format!(
        r#"<!doctype html>
<html class="{full_width_class}" data-theme="{theme_val}">
<head>
    <meta charset="utf-8">
    {base_tag}
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>{escaped_title}</title>
    <style>{MARKDOWN_CSS}</style>
    <style>
        @media(max-width:900px){{article{{padding-left:30px;padding-right:30px}}}}
        @media(max-width:700px){{article{{padding-left:22px;padding-right:22px}}}}
    </style>
</head>
<body>
    <article>{body}</article>
    {extra_scripts}
    <script>{APP_JS}</script>
</body>
</html>"#,
        escaped_title = escape_html(title),
    )
}

pub fn make_html(
    body: &str,
    title: &str,
    theme: &str,
    full_width: bool,
    base_url: Option<&str>,
    embed_diagram_engines: bool,
) -> String {
    make_html_selective(
        body,
        title,
        theme,
        full_width,
        base_url,
        embed_diagram_engines,
        embed_diagram_engines,
        embed_diagram_engines,
    )
}
