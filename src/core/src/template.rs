use crate::assets::{get_katex_js, get_mermaid_js, get_plantuml_js, APP_JS, MARKDOWN_CSS};
use crate::parser::escape_html;

#[allow(clippy::too_many_arguments)] // Preserve the public rendering API.
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
    let mut random = [0u8; 16];
    getrandom::getrandom(&mut random).expect("OS randomness is required for document isolation");
    let nonce: String = random.iter().map(|b| format!("{b:02x}")).collect();
    let base_tag = match base_url {
        Some(url) => format!("<base href=\"{}\">", escape_html(url)),
        None => String::new(),
    };

    let full_width_class = if full_width { "full-width" } else { "" };
    let theme_val = if theme.is_empty() { "system" } else { theme };

    let mut extra_scripts = String::new();
    if embed_katex {
        if let Ok(katex) = get_katex_js() {
            extra_scripts.push_str(&format!("<script nonce=\"{nonce}\">"));
            extra_scripts.push_str(katex);
            extra_scripts.push_str("</script>\n");
        }
    }
    if embed_mermaid {
        if let Ok(mermaid) = get_mermaid_js() {
            extra_scripts.push_str(&format!("<script nonce=\"{nonce}\">"));
            extra_scripts.push_str(mermaid);
            extra_scripts.push_str("</script>\n");
        }
    }
    if embed_plantuml {
        if let Ok(plantuml) = get_plantuml_js() {
            extra_scripts.push_str(&format!("<script nonce=\"{nonce}\">"));
            extra_scripts.push_str(plantuml);
            extra_scripts.push_str("</script>\n");
        }
    }

    format!(
        r#"<!doctype html>
<html class="{full_width_class}" data-theme="{escaped_theme}">
<head>
    <meta charset="utf-8">
    <meta name="mdvu-script-nonce" content="{nonce}">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-{nonce}' 'unsafe-eval' 'wasm-unsafe-eval'; style-src 'unsafe-inline' data: file:; img-src file: data: blob: https: http:; font-src file: data:; worker-src blob:; connect-src 'none'; frame-src about:; object-src 'none'; form-action 'none'">
    {base_tag}
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>{escaped_title}</title>
    <style>{MARKDOWN_CSS}</style>
    <style>
        @media(max-width:900px){{article{{padding-left:30px;padding-right:30px}}}}
        @media(max-width:700px){{article{{padding-left:22px;padding-right:22px}}}}
    </style>
    <script nonce="{nonce}">{APP_JS}</script>
</head>
<body>
    <article>{body}</article>
    {extra_scripts}
</body>
</html>"#,
        escaped_title = escape_html(title),
        escaped_theme = escape_html(theme_val),
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
