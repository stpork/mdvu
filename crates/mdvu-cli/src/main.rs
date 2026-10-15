use clap::Parser as ClapParser;
use mdvu_core::{render_markdown, MarkdownDialect};
use std::fs;
use std::io::{self, Read, Write};
use std::path::PathBuf;

#[derive(ClapParser, Debug)]
#[command(name = "mdvu-cli")]
#[command(about = "Ultra-fast headless Markdown renderer powered by mdvu-core", long_about = None)]
struct Args {
    /// Input Markdown file path (reads from stdin if omitted or "-")
    #[arg(value_name = "FILE")]
    input: Option<PathBuf>,

    /// Write output to file instead of stdout
    #[arg(short, long, value_name = "OUTPUT")]
    output: Option<PathBuf>,

    /// Document title override
    #[arg(short, long)]
    title: Option<String>,

    /// Markdown dialect: generic, obsidian, mkdocs, docusaurus, gfm, commonmark
    #[arg(short, long, default_value = "generic")]
    dialect: String,

    /// Color theme: light, dark, system
    #[arg(short, long, default_value = "system")]
    theme: String,

    /// Enable full-width view (removes article max-width)
    #[arg(long)]
    full_width: bool,

    /// Embed all offline diagram & math engines (KaTeX, Mermaid, PlantUML) into the HTML
    #[arg(short, long)]
    standalone: bool,

    /// Print Table of Contents (JSON) instead of HTML
    #[arg(long)]
    toc: bool,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    let (content, base_url) = match args.input {
        Some(ref path) if path.to_string_lossy() != "-" => {
            let s = fs::read_to_string(path)?;
            let abs_path = fs::canonicalize(path)?;
            let url = format!("file://{}", abs_path.display());
            (s, Some(url))
        }
        _ => {
            let mut buf = String::new();
            io::stdin().read_to_string(&mut buf)?;
            (buf, None)
        }
    };

    let dialect = MarkdownDialect::from_str_name(&args.dialect).unwrap_or(MarkdownDialect::Generic);

    let (html, rendered) = render_markdown(
        &content,
        args.title.as_deref(),
        dialect,
        &args.theme,
        args.full_width,
        base_url.as_deref(),
        args.standalone,
    );

    if args.toc {
        let toc_json = serde_json::to_string_pretty(&rendered.toc)?;
        println!("{toc_json}");
        return Ok(());
    }

    match args.output {
        Some(out_path) => {
            fs::write(out_path, html)?;
        }
        None => {
            io::stdout().write_all(html.as_bytes())?;
        }
    }

    Ok(())
}
