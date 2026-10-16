use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::hash::{DefaultHasher, Hash, Hasher};
use std::path::{Path, PathBuf};
use std::sync::{LazyLock, RwLock};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct VaultItem {
    pub name: String,
    pub path: String,
    pub is_dir: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rel_path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub children: Option<Vec<VaultItem>>,
}

pub const SUPPORTED_MARKDOWN_EXTENSIONS: &[&str] = &["md", "markdown", "mdown", "mkd", "txt"];

pub fn is_markdown_file(path: &Path) -> bool {
    if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
        let lower = ext.to_ascii_lowercase();
        SUPPORTED_MARKDOWN_EXTENSIONS.contains(&lower.as_str())
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
    ".git",
    ".obsidian",
    ".trash",
    "node_modules",
    ".build",
    "Pods",
    "target",
    "dist",
    ".cache",
    "build",
    "vendor",
];

/// Computes the `file://` base URL for a document's parent directory so relative assets resolve properly.
pub fn get_base_url_for_file(file_path: &Path) -> Option<String> {
    let abs_path = dunce::canonicalize(file_path).unwrap_or_else(|_| {
        if file_path.is_absolute() {
            file_path.to_path_buf()
        } else {
            std::env::current_dir()
                .map(|cwd| cwd.join(file_path))
                .unwrap_or_else(|_| file_path.to_path_buf())
        }
    });

    let dir = abs_path.parent().unwrap_or(&abs_path);
    #[cfg(windows)]
    {
        url::Url::from_directory_path(dir)
            .ok()
            .map(|url| url.to_string())
    }
    #[cfg(not(windows))]
    {
        use std::fmt::Write;
        let mut out = String::from("file://");
        for byte in dir.to_string_lossy().bytes() {
            if byte.is_ascii_alphanumeric() || matches!(byte, b'/' | b'-' | b'_' | b'.' | b'~') {
                out.push(byte as char);
            } else {
                let _ = write!(out, "%{byte:02X}");
            }
        }
        if !out.ends_with('/') {
            out.push('/');
        }
        Some(out)
    }
}

/// Splits a link target (e.g. `docs/arch.md#overview`) into `(path_part, optional_fragment)`.
pub fn split_path_and_fragment(raw_target: &str) -> (&str, Option<&str>) {
    match raw_target.split_once('#') {
        Some((path, frag)) => {
            let clean_path = path.split('?').next().unwrap_or(path);
            let clean_frag = if frag.is_empty() { None } else { Some(frag) };
            (clean_path, clean_frag)
        }
        None => {
            let clean_path = raw_target.split('?').next().unwrap_or(raw_target);
            (clean_path, None)
        }
    }
}

pub fn scan_directory_tree(dir: &Path, max_depth: usize) -> Vec<VaultItem> {
    let root_norm = dir.to_string_lossy().replace('\\', "/");
    scan_directory_tree_inner(dir, &root_norm, max_depth)
}

fn scan_directory_tree_inner(dir: &Path, root_norm: &str, max_depth: usize) -> Vec<VaultItem> {
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
        if name.starts_with('.') || name.ends_with(".app") {
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
        let children = scan_directory_tree_inner(&path, root_norm, max_depth - 1);
        if !children.is_empty() {
            let path_str = path.to_string_lossy().replace('\\', "/");
            items.push(VaultItem {
                name,
                path: path_str,
                is_dir: true,
                rel_path: None,
                children: Some(children),
            });
        }
    }

    let root_prefix = if root_norm.ends_with('/') {
        root_norm.to_string()
    } else {
        format!("{root_norm}/")
    };

    for (name, path) in files {
        let path_str = path.to_string_lossy().replace('\\', "/");
        let rel = path_str
            .strip_prefix(&root_prefix)
            .map(|s| s.to_string())
            .filter(|s| s != &name);
        items.push(VaultItem {
            name,
            path: path_str,
            is_dir: false,
            rel_path: rel,
            children: None,
        });
    }

    items
}

/// Flattens a hierarchical `VaultItem` tree into a sorted flat list of Markdown files.
pub fn flatten_vault_tree(tree: &[VaultItem]) -> Vec<VaultItem> {
    let mut flat = Vec::new();
    fn collect(items: &[VaultItem], out: &mut Vec<VaultItem>) {
        for item in items {
            if item.is_dir {
                if let Some(ref children) = item.children {
                    collect(children, out);
                }
            } else {
                out.push(item.clone());
            }
        }
    }
    collect(tree, &mut flat);
    flat.sort_by(|a, b| {
        a.name
            .to_lowercase()
            .cmp(&b.name.to_lowercase())
            .then_with(|| a.path.to_lowercase().cmp(&b.path.to_lowercase()))
    });
    flat
}

pub fn find_first_markdown(root: &Path) -> Option<PathBuf> {
    if root.is_file() && is_markdown_file(root) {
        return Some(root.to_path_buf());
    }
    for candidate in ["README.md", "readme.md", "Index.md", "index.md"] {
        let p = root.join(candidate);
        if p.exists() && p.is_file() {
            return Some(p);
        }
    }
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

/// Unified cross-platform zoom policy matching macOS and Windows (10% to 500%, 10% discrete steps).
pub struct ZoomPolicy;

impl ZoomPolicy {
    pub const MIN_ZOOM: f64 = 0.10;
    pub const MAX_ZOOM: f64 = 5.00;
    pub const DEFAULT_ZOOM: f64 = 1.00;
    pub const STEP: f64 = 0.10;
    pub const SNAP_TOLERANCE: f64 = 0.025;

    #[inline]
    pub fn clamp(zoom: f64) -> f64 {
        zoom.clamp(Self::MIN_ZOOM, Self::MAX_ZOOM)
    }

    pub fn next_step(from: f64) -> f64 {
        let current = Self::clamp(from);
        let scaled = current / Self::STEP;
        let rounded = scaled.round();
        let next = if (scaled - rounded).abs() < 1e-4 {
            (rounded + 1.0) * Self::STEP
        } else {
            scaled.ceil() * Self::STEP
        };
        Self::clamp((next * 100.0).round() / 100.0)
    }

    pub fn previous_step(from: f64) -> f64 {
        let current = Self::clamp(from);
        let scaled = current / Self::STEP;
        let rounded = scaled.round();
        let prev = if (scaled - rounded).abs() < 1e-4 {
            (rounded - 1.0) * Self::STEP
        } else {
            scaled.floor() * Self::STEP
        };
        Self::clamp((prev * 100.0).round() / 100.0)
    }

    pub fn parse_manual_input(input: &str, fallback: f64) -> f64 {
        let cleaned = input.trim().trim_end_matches('%').trim();
        if let Ok(val) = cleaned.parse::<f64>() {
            if val.is_finite() && val > 0.0 {
                return Self::clamp(val / 100.0);
            }
        }
        Self::clamp(fallback)
    }

    pub fn format_percentage(zoom: f64) -> String {
        let clamped = Self::clamp(zoom);
        let nearest_tenth = (clamped / Self::STEP).round() * Self::STEP;
        let snapped = if (clamped - nearest_tenth).abs() <= Self::SNAP_TOLERANCE {
            nearest_tenth
        } else {
            clamped
        };
        format!("{}%", (snapped * 100.0).round() as i32)
    }
}

/// Generic back/forward navigation history stack.
#[derive(Debug, Clone)]
pub struct NavigationHistory<T: Clone + PartialEq> {
    entries: Vec<T>,
    index: Option<usize>,
}

impl<T: Clone + PartialEq> Default for NavigationHistory<T> {
    fn default() -> Self {
        Self::new()
    }
}

impl<T: Clone + PartialEq> NavigationHistory<T> {
    pub fn new() -> Self {
        Self {
            entries: Vec::new(),
            index: None,
        }
    }

    pub fn record(&mut self, item: T) {
        if let Some(idx) = self.index {
            if self.entries.get(idx) == Some(&item) {
                return;
            }
            self.entries.truncate(idx + 1);
        } else {
            self.entries.clear();
        }
        self.entries.push(item);
        self.index = Some(self.entries.len() - 1);
    }

    pub fn can_go_back(&self) -> bool {
        self.index.map(|i| i > 0).unwrap_or(false)
    }

    pub fn can_go_forward(&self) -> bool {
        self.index
            .map(|i| i + 1 < self.entries.len())
            .unwrap_or(false)
    }

    pub fn go_back(&mut self) -> Option<&T> {
        if let Some(idx) = self.index {
            if idx > 0 {
                self.index = Some(idx - 1);
                return self.entries.get(idx - 1);
            }
        }
        None
    }

    pub fn go_forward(&mut self) -> Option<&T> {
        if let Some(idx) = self.index {
            if idx + 1 < self.entries.len() {
                self.index = Some(idx + 1);
                return self.entries.get(idx + 1);
            }
        }
        None
    }

    pub fn current(&self) -> Option<&T> {
        self.index.and_then(|i| self.entries.get(i))
    }
}

/// Computes a 64-character lowercase hex cache key (256-bit) compatible with both macOS and Windows DiagramCache.
pub fn compute_diagram_cache_key(renderer: &str, theme: &str, source: &str) -> String {
    let mut out = String::with_capacity(64);
    for round in 0u64..4u64 {
        let mut hasher = DefaultHasher::new();
        crate::VERSION.hash(&mut hasher);
        "runtime-strict-v2".hash(&mut hasher);
        round.hash(&mut hasher);
        renderer.hash(&mut hasher);
        theme.hash(&mut hasher);
        source.hash(&mut hasher);
        use std::fmt::Write;
        let _ = write!(&mut out, "{:016x}", hasher.finish());
    }
    out
}

pub struct DiagramCache {
    dir: PathBuf,
    memory: RwLock<HashMap<String, String>>,
}

static GLOBAL_DIAGRAM_CACHE: LazyLock<DiagramCache> = LazyLock::new(DiagramCache::new);

impl DiagramCache {
    pub fn global() -> &'static Self {
        &GLOBAL_DIAGRAM_CACHE
    }

    pub fn new() -> Self {
        let base = Self::default_cache_dir();
        let _ = fs::create_dir_all(&base);
        Self {
            dir: base,
            memory: RwLock::new(HashMap::new()),
        }
    }

    fn default_cache_dir() -> PathBuf {
        if let Some(path) = std::env::var_os("MDVU_CACHE_DIR").filter(|p| !p.is_empty()) {
            return PathBuf::from(path);
        }
        #[cfg(target_os = "macos")]
        {
            if let Ok(home) = std::env::var("HOME") {
                return PathBuf::from(home).join("Library/Caches/mdvu/diagrams");
            }
        }
        #[cfg(target_os = "windows")]
        {
            if let Ok(local_app_data) = std::env::var("LOCALAPPDATA") {
                return PathBuf::from(local_app_data).join("mdvu/Caches/diagrams");
            }
        }
        #[cfg(not(any(target_os = "macos", target_os = "windows")))]
        {
            if let Ok(xdg) = std::env::var("XDG_CACHE_HOME") {
                return PathBuf::from(xdg).join("mdvu/diagrams");
            }
            if let Ok(home) = std::env::var("HOME") {
                return PathBuf::from(home).join(".cache/mdvu/diagrams");
            }
        }
        std::env::temp_dir().join("mdvu-diagrams")
    }

    pub fn is_valid_key(key: &str) -> bool {
        key.len() == 64 && key.bytes().all(|b| b.is_ascii_hexdigit())
    }

    pub fn is_safe_svg(svg: &str) -> bool {
        if !svg.contains("<svg") || !svg.contains("</svg>") {
            return false;
        }
        let lower = svg.to_ascii_lowercase();
        static ACTIVE: std::sync::LazyLock<regex::Regex> = std::sync::LazyLock::new(|| {
            regex::Regex::new(r"(?i-u)<(?:script|iframe|object|embed)\b|[\s/]on[a-z]+\s*=").unwrap()
        });
        svg.len() <= 10_000_000
            && !ACTIVE.is_match(svg)
            && !lower.contains("<script")
            && !lower.contains("javascript:")
            && !lower.contains("onload=")
            && !lower.contains("onerror=")
    }

    pub fn read(&self, key: &str) -> Option<String> {
        if !Self::is_valid_key(key) {
            return None;
        }
        if let Ok(guard) = self.memory.read() {
            if let Some(svg) = guard.get(key) {
                return Some(svg.clone());
            }
        }
        let path = self.dir.join(format!("{key}.svg"));
        if fs::metadata(&path).ok()?.len() > 10_000_000 { return None; }
        let svg = fs::read_to_string(path).ok()?;
        if !Self::is_safe_svg(&svg) {
            return None;
        }
        if let Ok(mut guard) = self.memory.write() {
            if guard.len() >= 128
                || guard.values().map(String::len).sum::<usize>() + svg.len() > 16 * 1024 * 1024
            {
                guard.clear();
            }
            guard.insert(key.to_string(), svg.clone());
        }
        Some(svg)
    }

    pub fn write(&self, key: &str, svg: &str) {
        if !Self::is_valid_key(key) || !Self::is_safe_svg(svg) {
            return;
        }
        if let Ok(mut guard) = self.memory.write() {
            if guard.len() >= 128
                || guard.values().map(String::len).sum::<usize>() + svg.len() > 16 * 1024 * 1024
            {
                guard.clear();
            }
            guard.insert(key.to_string(), svg.to_string());
        }
        let path = self.dir.join(format!("{key}.svg"));
        static SERIAL: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let serial = SERIAL.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        let temp = self
            .dir
            .join(format!("{key}-{}-{serial}.tmp", std::process::id()));
        if fs::write(&temp, svg.as_bytes()).is_ok() {
            // Rename publishes a complete file; concurrent readers never see partial SVG.
            if fs::rename(&temp, &path).is_err() {
                let _ = fs::remove_file(&temp);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zoom_policy() {
        assert_eq!(ZoomPolicy::clamp(0.05), 0.10);
        assert_eq!(ZoomPolicy::clamp(6.00), 5.00);
        assert!((ZoomPolicy::next_step(1.00) - 1.10).abs() < 1e-4);
        assert!((ZoomPolicy::previous_step(1.00) - 0.90).abs() < 1e-4);
        assert!((ZoomPolicy::next_step(1.14) - 1.20).abs() < 1e-4);
        assert!((ZoomPolicy::previous_step(1.14) - 1.10).abs() < 1e-4);
        assert_eq!(ZoomPolicy::format_percentage(1.01), "100%");
        assert_eq!(ZoomPolicy::format_percentage(1.34), "134%");
        assert!((ZoomPolicy::parse_manual_input("150%", 1.0) - 1.50).abs() < 1e-4);
    }

    #[test]
    fn test_navigation_history() {
        let mut hist = NavigationHistory::new();
        assert!(!hist.can_go_back());
        hist.record("a");
        hist.record("b");
        assert!(hist.can_go_back());
        assert!(!hist.can_go_forward());
        assert_eq!(hist.go_back(), Some(&"a"));
        assert!(hist.can_go_forward());
        assert_eq!(hist.go_forward(), Some(&"b"));
    }

    #[test]
    fn test_diagram_cache_key_is_64_hex() {
        let key = compute_diagram_cache_key("mermaid", "light", "graph TD\nA-->B");
        assert_eq!(key.len(), 64);
        assert!(DiagramCache::is_valid_key(&key));
    }

    #[test]
    fn test_diagram_cache_svg_safety_validation() {
        assert!(DiagramCache::is_safe_svg(
            "<svg viewBox=\"0 0 10 10\"><rect width=\"5\" height=\"5\"/></svg>"
        ));
        assert!(!DiagramCache::is_safe_svg("<div>Not an svg</div>"));
        assert!(!DiagramCache::is_safe_svg(
            "<svg><script>alert(1)</script></svg>"
        ));
        assert!(!DiagramCache::is_safe_svg(
            "<svg onload=\"alert(1)\"></svg>"
        ));
        assert!(!DiagramCache::is_safe_svg(
            "<svg><a href=\"javascript:alert(1)\">x</a></svg>"
        ));
    }

    #[test]
    fn test_split_path_and_fragment() {
        assert_eq!(
            split_path_and_fragment("docs/arch.md#overview"),
            ("docs/arch.md", Some("overview"))
        );
        assert_eq!(
            split_path_and_fragment("docs/arch.md?v=1#sec-2"),
            ("docs/arch.md", Some("sec-2"))
        );
        assert_eq!(split_path_and_fragment("README.md#"), ("README.md", None));
        assert_eq!(split_path_and_fragment("README.md"), ("README.md", None));
    }

    #[test]
    fn test_vault_scanner_filters_ignored_dirs_and_flattens() {
        let temp = std::env::temp_dir().join(format!("mdvu-test-vault-{}", std::process::id()));
        let _ = fs::remove_dir_all(&temp);
        fs::create_dir_all(temp.join("Notes")).unwrap();
        fs::create_dir_all(temp.join("node_modules")).unwrap();
        fs::create_dir_all(temp.join(".hidden")).unwrap();
        fs::create_dir_all(temp.join("Example.app")).unwrap();

        fs::write(temp.join("root.md"), "# Root").unwrap();
        fs::write(temp.join("Notes").join("nested.markdown"), "# Nested").unwrap();
        fs::write(temp.join("node_modules").join("pkg.md"), "# Ignored").unwrap();
        fs::write(temp.join(".hidden").join("sec.md"), "# Ignored").unwrap();
        fs::write(temp.join("Example.app").join("bundle.md"), "# Ignored").unwrap();

        let tree = scan_directory_tree(&temp, 4);
        let flat = flatten_vault_tree(&tree);
        let names: Vec<&str> = flat.iter().map(|i| i.name.as_str()).collect();
        assert_eq!(names, vec!["nested.markdown", "root.md"]);

        let first = find_first_markdown(&temp);
        assert_eq!(first, Some(temp.join("root.md")));

        let base_url = get_base_url_for_file(&temp.join("root.md")).unwrap();
        assert!(base_url.starts_with("file://"));
        assert!(base_url.ends_with('/'));

        let _ = fs::remove_dir_all(&temp);
    }
}

/// Only these schemes may leave the preview and reach the operating system shell.
pub fn is_external_url(value: &str) -> bool {
    if value.chars().any(char::is_control) {
        return false;
    }
    value.split_once(':').is_some_and(|(scheme, rest)| {
        !rest.is_empty()
            && ["http", "https", "mailto"]
                .iter()
                .any(|allowed| scheme.eq_ignore_ascii_case(allowed))
    })
}
