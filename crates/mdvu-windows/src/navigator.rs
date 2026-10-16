use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VaultItem {
    pub name: String,
    pub path: String,
    pub is_dir: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub children: Option<Vec<VaultItem>>,
}

pub fn is_markdown_file(path: &Path) -> bool {
    if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
        matches!(
            ext.to_ascii_lowercase().as_str(),
            "md" | "markdown" | "mdown" | "mkd" | "txt"
        )
    } else {
        false
    }
}

pub fn find_vault_root(start_path: &Path) -> PathBuf {
    let initial_dir = if start_path.is_dir() {
        start_path.to_path_buf()
    } else {
        start_path.parent().unwrap_or(start_path).to_path_buf()
    };

    let canonical = dunce::canonicalize(&initial_dir).unwrap_or(initial_dir);
    let mut current = canonical.clone();
    for _ in 0..15 {
        if current.join(".obsidian").exists() || current.join(".git").exists() {
            return current;
        }
        if let Some(parent) = current.parent() {
            if parent == current {
                break;
            }
            current = parent.to_path_buf();
        } else {
            break;
        }
    }
    canonical
}

const IGNORED_DIRS: &[&str] = &[
    ".git", ".obsidian", ".trash", "node_modules", ".build",
    "target", "dist", ".cache", "build", "vendor",
];

pub fn scan_directory_tree(dir: &Path, max_depth: usize) -> Vec<VaultItem> {
    if max_depth == 0 {
        return Vec::new();
    }
    let mut items = Vec::new();
    let entries = match fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return items,
    };

    let mut dirs = Vec::new();
    let mut files = Vec::new();

    for entry in entries.flatten() {
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().to_string();
        if name.starts_with('.') && name != ".obsidian" {
            continue;
        }
        if let Ok(ft) = entry.file_type() {
            if ft.is_dir() {
                if !IGNORED_DIRS.contains(&name.as_str()) {
                    dirs.push((name, path));
                }
            } else if ft.is_file() && is_markdown_file(&path) {
                files.push((name, path));
            }
        }
    }

    dirs.sort_by(|a, b| a.0.to_lowercase().cmp(&b.0.to_lowercase()));
    files.sort_by(|a, b| a.0.to_lowercase().cmp(&b.0.to_lowercase()));

    for (name, path) in dirs {
        let children = scan_directory_tree(&path, max_depth - 1);
        if !children.is_empty() {
            let path_str = path.to_string_lossy().replace('\\', "/");
            items.push(VaultItem {
                name,
                path: path_str,
                is_dir: true,
                children: Some(children),
            });
        }
    }

    for (name, path) in files {
        let path_str = path.to_string_lossy().replace('\\', "/");
        items.push(VaultItem {
            name,
            path: path_str,
            is_dir: false,
            children: None,
        });
    }

    items
}

pub fn find_first_markdown(root: &Path) -> Option<PathBuf> {
    if root.is_file() && is_markdown_file(root) {
        return Some(root.to_path_buf());
    }
    // Check for README.md first
    for candidate in ["README.md", "readme.md", "Index.md", "index.md"] {
        let p = root.join(candidate);
        if p.exists() {
            return Some(p);
        }
    }
    // Otherwise return first markdown file
    if let Ok(entries) = fs::read_dir(root) {
        let mut files: Vec<PathBuf> = entries
            .flatten()
            .map(|e| e.path())
            .filter(|p| p.is_file() && is_markdown_file(p))
            .collect();
        files.sort();
        if let Some(first) = files.into_iter().next() {
            return Some(first);
        }
    }
    None
}
