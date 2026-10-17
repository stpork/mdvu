use mdvu_core::{escape_html, TocEntry, VaultItem, ZoomPolicy, VERSION};

#[allow(clippy::too_many_arguments)] // Host state is passed without retaining duplicate document data.
pub fn build_gui_html(
    document_html: &str,
    toc: &[TocEntry],
    vault_name: &str,
    vault_items: &[VaultItem],
    current_file_path: Option<&str>,
    is_toc_visible: bool,
    is_nav_visible: bool,
    is_full_width: bool,
    zoom_level: f64,
    can_go_back: bool,
    can_go_forward: bool,
) -> String {
    let nonce = document_html
        .split("name=\"mdvu-script-nonce\" content=\"")
        .nth(1)
        .and_then(|s| s.split('"').next())
        .unwrap_or("");
    let script_json = |json: String| {
        json.replace('<', "\\u003c")
            .replace('>', "\\u003e")
            .replace('&', "\\u0026")
    };
    let toc_json = script_json(serde_json::to_string(toc).unwrap_or_else(|_| "[]".to_string()));
    let vault_json =
        script_json(serde_json::to_string(vault_items).unwrap_or_else(|_| "[]".to_string()));
    let current_path_json = script_json(
        serde_json::to_string(&current_file_path.unwrap_or(""))
            .unwrap_or_else(|_| "\"\"".to_string()),
    );
    let zoom_label = ZoomPolicy::format_percentage(zoom_level);
    let safe_vault_name = escape_html(vault_name);
    let safe_version = escape_html(VERSION);

    let toc_tree_js = include_str!("../../../assets/toc-tree.js");
    let toc_policy = include_str!("../../../assets/sidebar-policy.json").trim();
    let toc_sizing: serde_json::Value =
        serde_json::from_str(toc_policy).expect("Embedded sidebar policy");
    let shell_css = r#"
:root {
  --toc-width: __TOC_DEFAULT__px;
  --toc-min-width: __TOC_MIN__px;
  --toc-max-width: max(__TOC_MIN__px, __TOC_MAX__vw);
  --nav-width: __NAV_DEFAULT__px;
}
#mdvu-app {
  display: flex;
  flex-direction: column;
  height: 100vh;
  width: 100vw;
  overflow: hidden;
  background: var(--bg);
  color: var(--fg);
}
#mdvu-toolbar {
  height: 38px;
  min-height: 38px;
  max-height: 38px;
  display: flex;
  align-items: center;
  padding: 0 10px;
  gap: 6px;
  border-bottom: 1px solid var(--line);
  background: color-mix(in srgb, var(--bg) 92%, var(--soft));
  user-select: none;
  z-index: 1000;
  box-sizing: border-box;
}
.toolbar-group {
  display: flex;
  align-items: center;
  gap: 4px;
}
.toolbar-flex {
  flex: 1;
}
.toolbar-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  height: 26px;
  min-width: 28px;
  padding: 0 7px;
  border: 1px solid var(--line);
  border-radius: 5px;
  background: var(--bg);
  color: var(--fg);
  cursor: pointer;
  font-size: 13px;
  line-height: 1;
  transition: all 0.12s ease;
  box-sizing: border-box;
}
.toolbar-btn:hover:not(:disabled) {
  background: var(--soft);
  border-color: var(--accent);
}
.toolbar-btn:disabled {
  opacity: 0.35;
  cursor: default;
}
.toolbar-btn.active {
  background: color-mix(in srgb, var(--accent) 18%, var(--bg));
  border-color: var(--accent);
  color: var(--accent);
}
.search-box {
  display: inline-flex;
  align-items: center;
  height: 26px;
  width: 280px;
  max-width: 34vw;
  border: 1px solid var(--line);
  border-radius: 5px;
  background: var(--bg);
  padding: 0 6px;
  gap: 5px;
  transition: border-color 0.12s ease;
  box-sizing: border-box;
}
.search-box:focus-within {
  border-color: var(--accent);
  box-shadow: 0 0 0 1px var(--accent);
}
.search-icon {
  display: flex;
  align-items: center;
  color: var(--muted);
  opacity: 0.8;
}
#mdvu-find-input {
  border: 0;
  background: transparent;
  color: var(--fg);
  outline: none;
  font-size: 12px;
  width: 100%;
}
.find-count {
  font-size: 11px;
  color: var(--muted);
  white-space: nowrap;
  font-family: system-ui, sans-serif;
  font-variant-numeric: tabular-nums;
}
.find-count.no-match {
  color: #e53935;
}
.find-nav-btn {
  background: none;
  border: 0;
  color: var(--muted);
  cursor: pointer;
  font-size: 11px;
  padding: 1px 3px;
  border-radius: 3px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.find-nav-btn:hover {
  background: var(--soft);
  color: var(--fg);
}
.zoom-group {
  display: inline-flex;
  align-items: center;
  border: 1px solid var(--line);
  border-radius: 5px;
  background: var(--bg);
  overflow: hidden;
  height: 26px;
  box-sizing: border-box;
}
.zoom-btn {
  border: 0;
  border-radius: 0;
  background: transparent;
  padding: 0 7px;
  font-size: 13px;
  font-weight: 500;
  color: var(--fg);
  cursor: pointer;
  height: 100%;
}
.zoom-btn:hover:not(:disabled) {
  background: var(--soft);
}
.zoom-btn:disabled {
  opacity: 0.35;
  cursor: default;
}
.zoom-val {
  border: 0;
  background: transparent;
  width: 48px;
  text-align: center;
  font-size: 11px;
  font-family: system-ui, sans-serif;
  font-variant-numeric: tabular-nums;
  color: var(--fg);
  outline: none;
  cursor: text;
}
.zoom-val:focus {
  background: var(--soft);
}
#mdvu-split-container {
  display: flex;
  flex: 1;
  overflow: hidden;
  position: relative;
}
.mdvu-sidebar {
  background: color-mix(in srgb, var(--bg) 96%, var(--soft));
  display: flex;
  flex-direction: column;
  overflow: hidden;
  user-select: none;
  z-index: 500;
  box-sizing: border-box;
  position: relative;
}
.mdvu-sidebar-left {
  width: clamp(var(--toc-min-width), var(--toc-width), var(--toc-max-width));
  min-width: var(--toc-min-width);
  max-width: var(--toc-max-width);
  border-right: 1px solid var(--line);
}
.mdvu-sidebar-left.hidden {
  display: none;
}
.mdvu-sidebar-right {
  width: var(--nav-width);
  min-width: var(--nav-width);
  max-width: var(--nav-width);
  border-left: 1px solid var(--line);
}
.mdvu-sidebar-right.hidden {
  display: none;
}
.sidebar-resizer {
  position: absolute;
  top: 0;
  bottom: 0;
  width: 5px;
  cursor: col-resize;
  z-index: 600;
}
.sidebar-resizer:hover, .sidebar-resizer.dragging {
  background: color-mix(in srgb, var(--accent) 45%, transparent);
}
.sidebar-resizer-left {
  right: 0;
}
.sidebar-resizer-right {
  left: 0;
}
.sidebar-header {
  height: 36px;
  min-height: 36px;
  padding: 0 10px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
  border-bottom: 1px solid var(--line);
  font-size: 12px;
  font-weight: 600;
  color: var(--muted);
  background: color-mix(in srgb, var(--bg) 90%, var(--soft));
  box-sizing: border-box;
}
.sidebar-title {
  display: flex;
  align-items: center;
  gap: 6px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex: 1;
}
.sidebar-title svg {
  flex-shrink: 0;
  opacity: 0.85;
}
.nav-mode-bar {
  padding: 6px 8px 4px;
  border-bottom: 1px solid color-mix(in srgb, var(--line) 60%, transparent);
}
.nav-mode-group {
  display: flex;
  width: 100%;
  border: 1px solid var(--line);
  border-radius: 5px;
  overflow: hidden;
  background: var(--bg);
}
.nav-mode-btn {
  flex: 1;
  border: 0;
  background: transparent;
  color: var(--muted);
  font-size: 11px;
  font-weight: 600;
  padding: 3px 8px;
  cursor: pointer;
  transition: all 0.1s ease;
}
.nav-mode-btn:hover:not(.active) {
  background: var(--soft);
  color: var(--fg);
}
.nav-mode-btn.active {
  background: color-mix(in srgb, var(--accent) 18%, var(--bg));
  color: var(--accent);
}
.sidebar-close {
  background: none;
  border: 0;
  color: var(--muted);
  font-size: 15px;
  line-height: 1;
  cursor: pointer;
  padding: 2px 4px;
  border-radius: 4px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}
.sidebar-close:hover {
  background: var(--line);
  color: var(--fg);
}
.sidebar-content {
  flex: 1;
  overflow-y: auto;
  padding: 6px 4px;
}
#mdvu-main-content {
  flex: 1;
  overflow-y: auto;
  height: 100%;
  position: relative;
}
/* Native-style TOC outline, sharing AppKit's metrics and expansion rules. */
#mdvu-toolbar,.mdvu-sidebar { font-family: system-ui, sans-serif; }
.toc-row { display:flex;align-items:center;height:__TOC_ROW__px;border-radius:4px;cursor:default; }
.toc-title { min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:__TOC_FONT__px; }
.toc-expander { flex:0 0 16px;width:16px;height:22px;padding:0;border:0;background:none;color:var(--muted);font-size:20px;line-height:1; }
.toc-node[aria-expanded="true"]>.toc-row>.toc-expander { transform:rotate(90deg); }
.toc-row:hover { background:var(--soft); }
.toc-node[aria-selected="true"]>.toc-row { background:color-mix(in srgb,var(--accent) 15%,transparent);color:var(--accent); }
.toc-node:focus { outline:none; }
.toc-node:focus-visible>.toc-row { outline:2px solid var(--accent);outline-offset:-2px; }
[role="group"][hidden] { display:none; }

/* Navigator Tree & List Items */
.nav-item {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 6px;
  margin: 1px 0;
  border-radius: 4px;
  font-size: 12px;
  color: var(--fg);
  cursor: pointer;
  text-decoration: none;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.nav-item svg {
  flex-shrink: 0;
  color: var(--muted);
}
.nav-item:hover {
  background: var(--soft);
}
.nav-item.active {
  background: color-mix(in srgb, var(--accent) 18%, transparent);
  color: var(--accent);
  font-weight: 600;
}
.nav-item.active svg {
  color: var(--accent);
}
.nav-item-label {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.nav-folder-content {
  padding-left: 14px;
}
.nav-arrow {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 12px;
  height: 12px;
  color: var(--muted);
  transition: transform 0.12s ease;
  flex-shrink: 0;
}
.nav-arrow.expanded {
  transform: rotate(90deg);
}

/* About Modal (matching macOS AboutPanel.swift) */
#mdvu-about-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.38);
  backdrop-filter: blur(2px);
  display: none;
  align-items: center;
  justify-content: center;
  z-index: 5000;
  user-select: none;
}
#mdvu-about-backdrop.visible {
  display: flex;
}
.about-card {
  width: 340px;
  background: var(--bg);
  color: var(--fg);
  border: 1px solid var(--line);
  border-radius: 12px;
  box-shadow: 0 18px 48px rgba(0, 0, 0, 0.32);
  padding: 26px 24px 22px;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  position: relative;
}
.about-close {
  position: absolute;
  top: 10px;
  right: 10px;
  background: none;
  border: 0;
  color: var(--muted);
  font-size: 16px;
  cursor: pointer;
  padding: 2px 6px;
  border-radius: 4px;
}
.about-close:hover {
  background: var(--soft);
  color: var(--fg);
}
.about-title {
  font-size: 25px;
  font-weight: 700;
  color: var(--fg);
  text-decoration: none;
  margin-top: 14px;
  margin-bottom: 4px;
}
.about-title:hover {
  color: var(--accent);
}
.about-subtitle {
  font-size: 13px;
  font-weight: 500;
  color: var(--muted);
  margin-bottom: 12px;
}
.about-version {
  font-size: 13px;
  color: var(--muted);
  margin-bottom: 12px;
}
.about-version a, .about-copy a {
  color: var(--accent);
  text-decoration: underline;
  font-weight: 500;
}
.about-copy {
  font-size: 12px;
  color: var(--muted);
}
    "#;

    let shell_html = format!(
        r##"
<div id="mdvu-app">
  <!-- Top Unified Toolbar -->
  <header id="mdvu-toolbar">
    <div class="toolbar-group">
      <button id="btn-back" class="toolbar-btn" title="Go back (Alt+Left / Ctrl+[)" {back_disabled}>
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
      </button>
      <button id="btn-forward" class="toolbar-btn" title="Go forward (Alt+Right / Ctrl+])" {fwd_disabled}>
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>
      </button>
      <button id="btn-toc" class="toolbar-btn {toc_active}" title="Toggle Table of Contents (Ctrl+B)">
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><line x1="9" y1="3" x2="9" y2="21"></line><line x1="13" y1="8" x2="18" y2="8"></line><line x1="13" y1="12" x2="18" y2="12"></line><line x1="13" y1="16" x2="18" y2="16"></line></svg>
      </button>
    </div>

    <div class="toolbar-flex"></div>

    <div class="toolbar-group">
      <div class="search-box">
        <span class="search-icon">
          <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
        </span>
        <input id="mdvu-find-input" type="search" placeholder="Find" title="Find (Ctrl+F)" autocomplete="off" spellcheck="false" />
        <span id="mdvu-find-count" class="find-count"></span>
        <button id="btn-find-prev" class="find-nav-btn" title="Previous match (Shift+Enter / Ctrl+Shift+G / Shift+F3)">▲</button>
        <button id="btn-find-next" class="find-nav-btn" title="Next match (Enter / Ctrl+G / F3)">▼</button>
        <button id="btn-find-close" class="find-nav-btn" title="Clear search (Esc)">×</button>
      </div>
    </div>

    <div class="toolbar-group">
      <div class="zoom-group">
        <button id="btn-zoom-out" class="zoom-btn" title="Zoom Out (Ctrl+-)">−</button>
        <input id="mdvu-zoom-val" class="zoom-val" value="{zoom_label}" title="Zoom level (10%–500%). Click to edit, double-click to reset (Ctrl+0)" />
        <button id="btn-zoom-in" class="zoom-btn" title="Zoom In (Ctrl++)">+</button>
      </div>
    </div>

    <div class="toolbar-group">
      <button id="btn-full-width" class="toolbar-btn {fw_active}" title="Toggle Full Width (Ctrl+Shift+W)">
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 3 21 3 21 9"></polyline><polyline points="9 21 3 21 3 15"></polyline><line x1="21" y1="3" x2="14" y2="10"></line><line x1="3" y1="21" x2="10" y2="14"></line></svg>
      </button>
      <button id="btn-navigator" class="toolbar-btn {nav_active}" title="Toggle File Navigator (Ctrl+Shift+D)">
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><line x1="15" y1="3" x2="15" y2="21"></line></svg>
      </button>
    </div>
  </header>

  <!-- Split View Body Container -->
  <div id="mdvu-split-container">
    <!-- Left Sidebar: Table of Contents -->
    <aside id="mdvu-toc-sidebar" class="mdvu-sidebar mdvu-sidebar-left {toc_hidden}">
      <div class="sidebar-header">
        <span class="sidebar-title">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"></line><line x1="8" y1="12" x2="21" y2="12"></line><line x1="8" y1="18" x2="21" y2="18"></line><line x1="3" y1="6" x2="3.01" y2="6"></line><line x1="3" y1="12" x2="3.01" y2="12"></line><line x1="3" y1="18" x2="3.01" y2="18"></line></svg>
          <span>Table of Contents</span>
        </span>
        <button id="btn-toc-close" class="sidebar-close" title="Hide Table of Contents (Ctrl+B)">×</button>
      </div>
      <nav id="mdvu-toc-tree" class="sidebar-content"></nav>
      <div id="mdvu-toc-resizer" class="sidebar-resizer sidebar-resizer-left"></div>
    </aside>

    <!-- Center Main Content -->
    <main id="mdvu-main-content">
      <div id="mdvu-article-wrap" style="zoom: {zoom_level}">
        __MDVU_ARTICLE_CONTENT__
      </div>
    </main>

    <!-- Right Sidebar: File Navigator -->
    <aside id="mdvu-navigator-sidebar" class="mdvu-sidebar mdvu-sidebar-right {nav_hidden}">
      <div id="mdvu-nav-resizer" class="sidebar-resizer sidebar-resizer-right"></div>
      <div class="sidebar-header">
        <span class="sidebar-title" title="{safe_vault_name}">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path></svg>
          <span id="nav-vault-name">{safe_vault_name}</span>
        </span>
        <button id="btn-nav-close" class="sidebar-close" title="Hide File Navigator (Ctrl+Shift+D)">×</button>
      </div>
      <div class="nav-mode-bar">
        <div class="nav-mode-group" title="Switch between folder tree and flat file list">
          <button id="btn-nav-mode-tree" class="nav-mode-btn active" type="button">Tree</button>
          <button id="btn-nav-mode-list" class="nav-mode-btn" type="button">List</button>
        </div>
      </div>
      <div id="mdvu-nav-tree" class="sidebar-content"></div>
    </aside>
  </div>

  <!-- Interactive About Modal (matching macOS AboutPanel.swift) -->
  <div id="mdvu-about-backdrop" role="dialog" aria-modal="true" aria-label="About mdvu">
    <div class="about-card">
      <button id="btn-about-close" class="about-close" title="Close (Esc)">×</button>
      <svg width="112" height="112" viewBox="0 0 256 256" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="16" y="16" width="224" height="224" rx="48" fill="#F6F8FB" stroke="#DCE3EE" stroke-width="4"/>
        <path d="M176 16L240 80H196C184.954 80 176 71.0457 176 60V16Z" fill="#007AFF"/>
        <text x="38" y="122" font-family="system-ui,-apple-system,Segoe UI,sans-serif" font-size="82" font-weight="800" fill="#102542">MD</text>
        <rect x="40" y="142" width="128" height="10" rx="5" fill="#B8C5D6"/>
        <rect x="40" y="162" width="112" height="10" rx="5" fill="#B8C5D6"/>
        <rect x="40" y="182" width="96" height="10" rx="5" fill="#B8C5D6"/>
        <rect x="40" y="202" width="68" height="10" rx="5" fill="#0088FF"/>
        <circle cx="196" cy="196" r="34" fill="#1B3B6F"/>
        <path d="M170 196C176 183 185 178 196 178C207 178 216 183 222 196C216 209 207 214 196 214C185 214 176 209 170 196Z" fill="#FFFFFF"/>
        <circle cx="196" cy="196" r="10" fill="#0088FF"/>
        <circle cx="196" cy="196" r="5" fill="#102542"/>
        <circle cx="199" cy="193" r="2" fill="#FFFFFF"/>
      </svg>
      <a class="about-title" href="https://github.com/stpork/mdvu" data-external="https://github.com/stpork/mdvu" title="https://github.com/stpork/mdvu">mdvu</a>
      <div class="about-subtitle">Markdown and Mermaid Viewer</div>
      <div class="about-version">
        Version: <a href="https://github.com/stpork/mdvu/releases/tag/v{safe_version}" data-external="https://github.com/stpork/mdvu/releases/tag/v{safe_version}" title="https://github.com/stpork/mdvu/releases/tag/v{safe_version}">{safe_version}</a>
      </div>
      <div class="about-copy">
        Copyright © 2026 <a href="mailto:finndebear@gmail.com" data-external="mailto:finndebear@gmail.com" title="mailto:finndebear@gmail.com">Finn de Bear</a>
      </div>
    </div>
  </div>
</div>

<script nonce="{nonce}">
{toc_tree_js}
(()=>{{
  const escHtml = s => String(s ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
  const ICON_FOLDER = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path></svg>`;
  const ICON_DOC = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line></svg>`;
  const ICON_ARROW = `<svg viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>`;

  window.__mdvuInitialTOC = {toc_json};
  window.__mdvuInitialVault = {vault_json};
  window.__mdvuCurrentPath = {current_path_json};
  window.__mdvuNavMode = 'tree';

  const preserveReadingAnchor = mutate => window.__mdvuPreserveReadingAnchor ? window.__mdvuPreserveReadingAnchor(mutate) : mutate();

  window.__mdvuOnTOC = entries => renderTOC(entries);

  // Setup TOC sidebar
  function renderTOC(entries) {{
    const container = document.getElementById('mdvu-toc-tree');
    if (container) window.__mdvuBuildTOCTree(container, entries || [], {toc_policy}, id => window.__mdvuScrollToFragment?.(id));
  }}

  function flattenVault(list, out = []) {{
    (list || []).forEach(item => {{
      if (item.is_dir) {{
        if (item.children) flattenVault(item.children, out);
      }} else {{
        out.push(item);
      }}
    }});
    return out;
  }}

  // Setup Vault / File Navigator sidebar
  function renderVault(items, currentPath) {{
    const container = document.getElementById('mdvu-nav-tree');
    if (!container) return;
    if (!items || !items.length) {{
      container.innerHTML = '<div style="color:var(--muted);padding:16px 10px;text-align:center;font-size:12px;">No markdown files</div>';
      return;
    }}
    const normCur = (currentPath || '').replace(/\\/g, '/');
    const isMatch = (itemPath) => {{
      if (!normCur || !itemPath) return false;
      const normItem = itemPath.replace(/\\/g, '/');
      return normItem === normCur || normCur.endsWith('/' + normItem) || normItem.endsWith('/' + normCur);
    }};
    const containsActive = (item) => {{
      if (!item.is_dir) return isMatch(item.path);
      return (item.children || []).some(containsActive);
    }};

    if (window.__mdvuNavMode === 'list') {{
      const flat = flattenVault(items).sort((a, b) => {{
        const la = a.rel_path || a.name;
        const lb = b.rel_path || b.name;
        return la.localeCompare(lb, undefined, {{ numeric: true, sensitivity: 'base' }});
      }});
      let h = '';
      flat.forEach(item => {{
        const isAct = isMatch(item.path);
        const displayLabel = item.rel_path || item.name;
        h += `<div class="nav-item nav-file ${{isAct ? 'active' : ''}}" data-path="${{escHtml(item.path)}}" title="${{escHtml(item.path)}}">
          ${{ICON_DOC}} <span class="nav-item-label">${{escHtml(displayLabel)}}</span>
        </div>`;
      }});
      container.innerHTML = h;
    }} else {{
      function buildTree(list, depth = 0) {{
        let h = '';
        list.forEach(item => {{
          if (item.is_dir) {{
            const expanded = depth === 0 || containsActive(item);
            h += `<div class="nav-folder">
              <div class="nav-item nav-folder-header" title="${{escHtml(item.path)}}">
                <span class="nav-arrow ${{expanded ? 'expanded' : ''}}">${{ICON_ARROW}}</span> ${{ICON_FOLDER}} <span class="nav-item-label">${{escHtml(item.name)}}</span>
              </div>
              <div class="nav-folder-content" style="display:${{expanded ? 'block' : 'none'}}">
                ${{item.children ? buildTree(item.children, depth + 1) : ''}}
              </div>
            </div>`;
          }} else {{
            const isAct = isMatch(item.path);
            h += `<div class="nav-item nav-file ${{isAct ? 'active' : ''}}" data-path="${{escHtml(item.path)}}" title="${{escHtml(item.path)}}">
              <span style="width:12px;flex-shrink:0;"></span> ${{ICON_DOC}} <span class="nav-item-label">${{escHtml(item.name)}}</span>
            </div>`;
          }}
        }});
        return h;
      }}
      container.innerHTML = buildTree(items, 0);

      container.querySelectorAll('.nav-folder-header').forEach(hdr => {{
        hdr.addEventListener('click', () => {{
          const content = hdr.nextElementSibling;
          const arrow = hdr.querySelector('.nav-arrow');
          if (content) {{
            const isHidden = content.style.display === 'none';
            content.style.display = isHidden ? 'block' : 'none';
            if (arrow) arrow.classList.toggle('expanded', isHidden);
          }}
        }});
      }});
    }}

    container.querySelectorAll('.nav-file').forEach(fileEl => {{
      fileEl.addEventListener('click', () => {{
        const p = fileEl.getAttribute('data-path');
        if (p && window.ipc) {{
          window.ipc.postMessage('open_path:' + p);
        }}
      }});
    }});

    const activeEl = container.querySelector('.nav-item.active');
    if (activeEl) {{
      activeEl.scrollIntoView({{ block: 'nearest' }});
    }}
  }}

  renderTOC(window.__mdvuInitialTOC);
  renderVault(window.__mdvuInitialVault, window.__mdvuCurrentPath);
  window.__mdvuUpdateNavigator = items => {{
    window.__mdvuInitialVault = items;
    renderVault(items, window.__mdvuCurrentPath);
  }};

  // Tree | List switcher
  const btnModeTree = document.getElementById('btn-nav-mode-tree');
  const btnModeList = document.getElementById('btn-nav-mode-list');
  btnModeTree?.addEventListener('click', () => {{
    if (window.__mdvuNavMode === 'tree') return;
    window.__mdvuNavMode = 'tree';
    btnModeTree.classList.add('active');
    btnModeList?.classList.remove('active');
    renderVault(window.__mdvuInitialVault, window.__mdvuCurrentPath);
  }});
  btnModeList?.addEventListener('click', () => {{
    if (window.__mdvuNavMode === 'list') return;
    window.__mdvuNavMode = 'list';
    btnModeList.classList.add('active');
    btnModeTree?.classList.remove('active');
    renderVault(window.__mdvuInitialVault, window.__mdvuCurrentPath);
  }});

  const tocSizing = {toc_policy};
  // TOC defaults and drag limits share the same policy with AppKit.
  function setupResizer(resizerId, cssVar, isLeft) {{
    const resizer = document.getElementById(resizerId);
    if (!resizer) return;
    resizer.addEventListener('mousedown', (e) => {{
      e.preventDefault();
      resizer.classList.add('dragging');
      const minW = isLeft ? tocSizing.minimumWidth : 180;
      const onMove = (ev) => {{
        const maxW = Math.floor(window.innerWidth * (isLeft ? tocSizing.maximumFraction : 0.45));
        const w = isLeft ? ev.clientX : (window.innerWidth - ev.clientX);
        const clamped = Math.max(minW, Math.min(maxW, w));
        document.documentElement.style.setProperty(cssVar, clamped + 'px');
      }};
      const onUp = () => {{
        resizer.classList.remove('dragging');
        window.removeEventListener('mousemove', onMove);
        window.removeEventListener('mouseup', onUp);
      }};
      window.addEventListener('mousemove', onMove);
      window.addEventListener('mouseup', onUp);
    }});
  }}
  setupResizer('mdvu-toc-resizer', '--toc-width', true);
  setupResizer('mdvu-nav-resizer', '--nav-width', false);

  window.__mdvuToggleTOCSidebar = (force) => {{
    const aside = document.getElementById('mdvu-toc-sidebar');
    const btn = document.getElementById('btn-toc');
    if (!aside) return;
    const isHidden = typeof force === 'boolean' ? !force : !aside.classList.contains('hidden');
    preserveReadingAnchor(() => aside.classList.toggle('hidden', isHidden));
    if (btn) btn.classList.toggle('active', !isHidden);
  }};

  window.__mdvuToggleNavSidebar = (force) => {{
    const aside = document.getElementById('mdvu-navigator-sidebar');
    const btn = document.getElementById('btn-navigator');
    if (!aside) return;
    const isHidden = typeof force === 'boolean' ? !force : !aside.classList.contains('hidden');
    preserveReadingAnchor(() => aside.classList.toggle('hidden', isHidden));
    if (btn) btn.classList.toggle('active', !isHidden);
  }};

  window.__mdvuToggleFullWidth = (force) => {{
    const html = document.documentElement;
    const btn = document.getElementById('btn-full-width');
    const isFw = typeof force === 'boolean' ? force : !html.classList.contains('full-width');
    preserveReadingAnchor(() => {{
      html.classList.toggle('full-width', isFw);
    }});
    if (btn) btn.classList.toggle('active', isFw);
  }};

  window.__mdvuSetTheme = (theme) => {{
    document.documentElement.dataset.theme = theme;
    window.__mdvuRenderDiagrams?.({{ all: true }});
  }};

  window.__mdvuSetZoom = (zoomFactor, formattedLabel) => {{
    const val = document.getElementById('mdvu-zoom-val');
    if (val) val.value = formattedLabel || (Math.round(zoomFactor * 100) + '%');
    const outBtn = document.getElementById('btn-zoom-out');
    const inBtn = document.getElementById('btn-zoom-in');
    if (outBtn) outBtn.disabled = zoomFactor <= 0.105;
    if (inBtn) inBtn.disabled = zoomFactor >= 4.995;
    preserveReadingAnchor(() => {{
      const wrap = document.getElementById('mdvu-article-wrap') || document.querySelector('article');
      if (wrap) wrap.style.zoom = zoomFactor;
    }});
  }};

  window.__mdvuUpdateHistory = (canBack, canFwd) => {{
    const backBtn = document.getElementById('btn-back');
    const fwdBtn = document.getElementById('btn-forward');
    if (backBtn) {{
      if (canBack) backBtn.removeAttribute('disabled');
      else backBtn.setAttribute('disabled', 'disabled');
    }}
    if (fwdBtn) {{
      if (canFwd) fwdBtn.removeAttribute('disabled');
      else fwdBtn.setAttribute('disabled', 'disabled');
    }}
  }};

  // About Modal controller
  const aboutBackdrop = document.getElementById('mdvu-about-backdrop');
  window.__mdvuShowAbout = () => {{
    aboutBackdrop?.classList.add('visible');
  }};
  window.__mdvuHideAbout = () => {{
    aboutBackdrop?.classList.remove('visible');
  }};
  document.getElementById('btn-about-close')?.addEventListener('click', () => window.__mdvuHideAbout());
  aboutBackdrop?.addEventListener('click', (e) => {{
    if (e.target === aboutBackdrop) window.__mdvuHideAbout();
  }});
  aboutBackdrop?.querySelectorAll('a[data-external]').forEach(a => {{
    a.addEventListener('click', (e) => {{
      e.preventDefault();
      const target = a.getAttribute('data-external');
      if (target) window.ipc?.postMessage('open_external:' + target);
    }});
  }});

  // Fast in-place document update (preserves shell, sidebars, and loaded JS runtimes)
  window.__mdvuUpdateDocument = (payload) => {{
    const mainEl = document.getElementById('mdvu-main-content');
    const maxScroll = mainEl ? Math.max(1, mainEl.scrollHeight - mainEl.clientHeight) : 1;
    const prevRatio = (payload.preserveScroll && mainEl)
      ? (mainEl.scrollTop / maxScroll)
      : 0;

    if (payload.baseUrl !== undefined) {{
      let baseEl = document.querySelector('head base');
      if (payload.baseUrl) {{
        if (!baseEl) {{
          baseEl = document.createElement('base');
          document.head.prepend(baseEl);
        }}
        baseEl.setAttribute('href', payload.baseUrl);
      }} else if (baseEl) {{
        baseEl.remove();
      }}
    }}

    const article = document.querySelector('#mdvu-article-wrap article') || document.querySelector('article');
    if (article && payload.bodyHtml !== undefined) {{
      window.__mdvuDisposeArticle?.();
      article.innerHTML = payload.bodyHtml;
    }}

    if (payload.toc) {{
      window.__mdvuInitialTOC = payload.toc;
      renderTOC(payload.toc);
    }}
    if (payload.vaultName) {{
      const vn = document.getElementById('nav-vault-name');
      if (vn) vn.textContent = payload.vaultName;
    }}
    if (payload.vaultItems) {{
      window.__mdvuInitialVault = payload.vaultItems;
    }}
    if (payload.currentPath !== undefined) {{
      window.__mdvuCurrentPath = payload.currentPath;
    }}
    renderVault(window.__mdvuInitialVault, window.__mdvuCurrentPath);

    if (payload.canBack !== undefined && payload.canFwd !== undefined) {{
      window.__mdvuUpdateHistory(payload.canBack, payload.canFwd);
    }}

    window.__mdvuInitArticle?.();
    requestAnimationFrame(() => requestAnimationFrame(() => {{
      window.ipc?.postMessage('article_ready:' + JSON.stringify({{generation:payload.generation,browserMs:performance.now()}}));
    }}));

    const findInput = document.getElementById('mdvu-find-input');
    if (findInput && findInput.value.trim() && window.__mdvuFind) {{
      updateFindCount(window.__mdvuFind.search(findInput.value));
    }}

    requestAnimationFrame(() => {{
      if (payload.fragment && window.__mdvuScrollToFragment) {{
        window.__mdvuScrollToFragment(payload.fragment, false);
      }} else if (mainEl) {{
        const newMax = Math.max(1, mainEl.scrollHeight - mainEl.clientHeight);
        mainEl.scrollTop = payload.preserveScroll ? (newMax * prevRatio) : 0;
      }}
    }});
  }};

  // Intercept article link clicks (external links -> system browser, relative .md -> open_rel_path)
  document.getElementById('mdvu-main-content')?.addEventListener('click', (evt) => {{
    const anchor = evt.target.closest?.('a[href]');
    if (!anchor) return;
    const rawHref = anchor.getAttribute('href')?.trim();
    if (!rawHref || rawHref.startsWith('#')) return;
    const lower = rawHref.toLowerCase();
    if (lower.startsWith('javascript:') || lower.startsWith('vbscript:') || lower.startsWith('data:')) {{
      evt.preventDefault();
      return;
    }}
    if (lower.startsWith('http://') || lower.startsWith('https://') || lower.startsWith('mailto:')) {{
      evt.preventDefault();
      window.ipc?.postMessage('open_external:' + rawHref);
      return;
    }}
    if (lower.startsWith('file:')) return;
    const [beforeHash, hashPart] = rawHref.split('#');
    const pathPart = beforeHash.split('?')[0];
    if (/\.(md|markdown|mdown|mkd|txt)$/i.test(pathPart)) {{
      evt.preventDefault();
      let decoded = pathPart;
      try {{ decoded = decodeURIComponent(pathPart); }} catch {{}}
      let decodedHash = hashPart || '';
      if (decodedHash) {{
        try {{ decodedHash = decodeURIComponent(decodedHash); }} catch {{}}
      }}
      window.ipc?.postMessage('open_rel_path:' + decoded + (decodedHash ? '#' + decodedHash : ''));
    }}
  }});

  // Wire Toolbar buttons
  document.getElementById('btn-back')?.addEventListener('click', () => window.ipc?.postMessage('go_back'));
  document.getElementById('btn-forward')?.addEventListener('click', () => window.ipc?.postMessage('go_forward'));
  document.getElementById('btn-toc')?.addEventListener('click', () => window.ipc?.postMessage('toggle_toc'));
  document.getElementById('btn-toc-close')?.addEventListener('click', () => window.ipc?.postMessage('toggle_toc'));
  document.getElementById('btn-navigator')?.addEventListener('click', () => window.ipc?.postMessage('toggle_nav'));
  document.getElementById('btn-nav-close')?.addEventListener('click', () => window.ipc?.postMessage('toggle_nav'));
  document.getElementById('btn-full-width')?.addEventListener('click', () => window.ipc?.postMessage('toggle_full_width'));
  document.getElementById('btn-zoom-in')?.addEventListener('click', () => window.ipc?.postMessage('zoom_in'));
  document.getElementById('btn-zoom-out')?.addEventListener('click', () => window.ipc?.postMessage('zoom_out'));

  const zoomInput = document.getElementById('mdvu-zoom-val');
  zoomInput?.addEventListener('focus', () => zoomInput.select());
  zoomInput?.addEventListener('dblclick', () => window.ipc?.postMessage('zoom_reset'));
  zoomInput?.addEventListener('keydown', (e) => {{
    if (e.key === 'Enter') {{
      e.preventDefault();
      window.ipc?.postMessage('set_zoom:' + zoomInput.value);
      zoomInput.blur();
    }} else if (e.key === 'Escape') {{
      e.preventDefault();
      zoomInput.blur();
    }}
  }});
  zoomInput?.addEventListener('change', () => {{
    window.ipc?.postMessage('set_zoom:' + zoomInput.value);
  }});

  // Ctrl + Mouse Wheel smooth zoom & Mouse Side Buttons (Back/Forward)
  let wheelZoomDelta = 0, wheelZoomFrame = 0;
  window.addEventListener('wheel', (e) => {{
    if (e.ctrlKey) {{
      wheelZoomDelta += e.deltaY;
      if (!wheelZoomFrame) wheelZoomFrame = requestAnimationFrame(() => {{
        if (wheelZoomDelta) window.ipc?.postMessage(wheelZoomDelta < 0 ? 'zoom_in' : 'zoom_out');
        wheelZoomDelta = 0; wheelZoomFrame = 0;
      }});
    }}
  }}, {{ passive: true }});

  window.addEventListener('mouseup', (e) => {{
    if (e.button === 3) {{
      e.preventDefault();
      window.ipc?.postMessage('go_back');
    }} else if (e.button === 4) {{
      e.preventDefault();
      window.ipc?.postMessage('go_forward');
    }}
  }});

  // Wire Find / Search Box with 80ms debounce (matches macOS NSSearchField responsiveness)
  const findInput = document.getElementById('mdvu-find-input');
  const findCount = document.getElementById('mdvu-find-count');
  let findDebounceTimer = null;

  function updateFindCount(res) {{
    if (!findCount) return;
    const hasQuery = !!(findInput && findInput.value.trim());
    if (!hasQuery) {{
      findCount.textContent = '';
      findCount.classList.remove('no-match');
    }} else if (!res || res.count === 0) {{
      findCount.textContent = '0/0';
      findCount.classList.add('no-match');
    }} else {{
      findCount.textContent = `${{res.current}}/${{res.count}}`;
      findCount.classList.remove('no-match');
    }}
  }}

  window.__mdvuFocusFind = () => {{
    findInput?.focus();
    findInput?.select();
  }};

  window.__mdvuFindNext = () => {{
    if (window.__mdvuFind) updateFindCount(window.__mdvuFind.next());
  }};

  window.__mdvuFindPrev = () => {{
    if (window.__mdvuFind) updateFindCount(window.__mdvuFind.previous());
  }};

  findInput?.addEventListener('input', () => {{
    if (findDebounceTimer) clearTimeout(findDebounceTimer);
    const val = findInput.value;
    if (!val || !val.trim()) {{
      if (window.__mdvuFind) window.__mdvuFind.clear();
      updateFindCount({{ count: 0, current: 0 }});
      return;
    }}
    findDebounceTimer = setTimeout(() => {{
      if (window.__mdvuFind) {{
        updateFindCount(window.__mdvuFind.search(val));
      }}
    }}, 80);
  }});

  findInput?.addEventListener('keydown', (e) => {{
    if (e.key === 'Enter') {{
      e.preventDefault();
      if (findDebounceTimer) {{
        clearTimeout(findDebounceTimer);
        findDebounceTimer = null;
        if (window.__mdvuFind) updateFindCount(window.__mdvuFind.search(findInput.value));
        return;
      }}
      if (window.__mdvuFind) {{
        const res = e.shiftKey ? window.__mdvuFind.previous() : window.__mdvuFind.next();
        updateFindCount(res);
      }}
    }} else if (e.key === 'Escape') {{
      e.preventDefault();
      if (findDebounceTimer) clearTimeout(findDebounceTimer);
      if (window.__mdvuFind) window.__mdvuFind.clear();
      if (findInput) {{ findInput.value = ''; findInput.blur(); }}
      updateFindCount(null);
    }}
  }});

  document.getElementById('btn-find-next')?.addEventListener('click', () => window.__mdvuFindNext());
  document.getElementById('btn-find-prev')?.addEventListener('click', () => window.__mdvuFindPrev());
  document.getElementById('btn-find-close')?.addEventListener('click', () => {{
    if (findDebounceTimer) clearTimeout(findDebounceTimer);
    if (window.__mdvuFind) window.__mdvuFind.clear();
    if (findInput) findInput.value = '';
    updateFindCount(null);
  }});

  // Keyboard shortcut listener in webview
  window.addEventListener('keydown', (e) => {{
    const ctrl = e.ctrlKey;
    if (e.key === 'Escape' && aboutBackdrop?.classList.contains('visible')) {{
      e.preventDefault();
      window.__mdvuHideAbout();
      return;
    }}
    if (ctrl && (e.key === 'f' || e.key === 'F')) {{
      e.preventDefault();
      findInput?.focus();
      findInput?.select();
    }} else if (e.key === 'F3' || (ctrl && (e.key === 'g' || e.key === 'G'))) {{
      e.preventDefault();
      if (window.__mdvuFind) updateFindCount(e.shiftKey ? window.__mdvuFind.previous() : window.__mdvuFind.next());
    }} else if (ctrl && (e.key === 'o' || e.key === 'O')) {{
      e.preventDefault();
      if (e.shiftKey) {{
        window.ipc?.postMessage('trigger_open_folder');
      }} else {{
        window.ipc?.postMessage('trigger_open_file');
      }}
    }} else if (ctrl && (e.key === 'r' || e.key === 'R')) {{
      e.preventDefault();
      window.ipc?.postMessage('reload');
    }} else if (ctrl && !e.shiftKey && (e.key === 'b' || e.key === 'B')) {{
      e.preventDefault();
      window.ipc?.postMessage('toggle_toc');
    }} else if (ctrl && e.shiftKey && (e.key === 'd' || e.key === 'D')) {{
      e.preventDefault();
      window.ipc?.postMessage('toggle_nav');
    }} else if (ctrl && e.shiftKey && (e.key === 'w' || e.key === 'W')) {{
      e.preventDefault();
      window.ipc?.postMessage('toggle_full_width');
    }} else if (ctrl && !e.shiftKey && (e.key === 'w' || e.key === 'W')) {{
      e.preventDefault();
      if (aboutBackdrop?.classList.contains('visible')) {{
        window.__mdvuHideAbout();
      }} else {{
        window.ipc?.postMessage('close_window');
      }}
    }} else if (ctrl && (e.key === '=' || e.key === '+')) {{
      e.preventDefault();
      window.ipc?.postMessage('zoom_in');
    }} else if (ctrl && (e.key === '-' || e.key === '_')) {{
      e.preventDefault();
      window.ipc?.postMessage('zoom_out');
    }} else if (ctrl && (e.key === '0')) {{
      e.preventDefault();
      window.ipc?.postMessage('zoom_reset');
    }} else if ((e.altKey && e.key === 'ArrowLeft') || (ctrl && e.key === '[')) {{
      e.preventDefault();
      window.ipc?.postMessage('go_back');
    }} else if ((e.altKey && e.key === 'ArrowRight') || (ctrl && e.key === ']')) {{
      e.preventDefault();
      window.ipc?.postMessage('go_forward');
    }} else if (e.key === 'F11') {{
      e.preventDefault();
      window.ipc?.postMessage('toggle_fullscreen');
    }} else if (e.key === 'Escape') {{
      if (document.activeElement === findInput) {{
        if (findDebounceTimer) clearTimeout(findDebounceTimer);
        if (window.__mdvuFind) window.__mdvuFind.clear();
        findInput.value = '';
        updateFindCount(null);
        findInput.blur();
      }}
    }}
  }});

  const media = matchMedia('(prefers-color-scheme:dark)');
  const reportSystemTheme = () => window.ipc?.postMessage('system_theme:' + (media.matches ? 'dark' : 'light'));
  media.addEventListener('change', reportSystemTheme);
  reportSystemTheme();
  document.getElementById('mdvu-open-btn')?.addEventListener('click', () => window.ipc?.postMessage('trigger_open_file'));
  document.getElementById('mdvu-open-folder-btn')?.addEventListener('click', () => window.ipc?.postMessage('trigger_open_folder'));

  // Notify host once the DOM and app.js have initialized so on-demand runtimes can be injected reliably
  if (document.readyState === 'loading') {{
    document.addEventListener('DOMContentLoaded', () => window.ipc?.postMessage('shell_ready'));
  }} else {{
    window.ipc?.postMessage('shell_ready');
  }}
}})();
</script>
"##,
        back_disabled = if can_go_back { "" } else { "disabled" },
        fwd_disabled = if can_go_forward { "" } else { "disabled" },
        toc_active = if is_toc_visible { "active" } else { "" },
        toc_hidden = if is_toc_visible { "" } else { "hidden" },
        nav_active = if is_nav_visible { "active" } else { "" },
        nav_hidden = if is_nav_visible { "" } else { "hidden" },
        fw_active = if is_full_width { "active" } else { "" },
    );

    // Install the bridge before the reader script. WebView2 initialization scripts
    // may be registered after the first file navigation has already started.
    #[cfg(windows)]
    let native_bridge = format!(
        r#"<script nonce="{nonce}">window.ipc={{postMessage:message=>window.chrome.webview.postMessage(message)}};window.__mdvuNativeDiagramTransport={{post:job=>window.ipc.postMessage('diagram_render:'+JSON.stringify(job)),cancel:()=>window.ipc.postMessage('diagram_cancel')}};</script>"#
    );
    #[cfg(not(windows))]
    let native_bridge = "";
    let shell_css = shell_css
        .replace("__TOC_DEFAULT__", &toc_sizing["defaultWidth"].to_string())
        .replace("__TOC_MIN__", &toc_sizing["minimumWidth"].to_string())
        .replace("__TOC_ROW__", &toc_sizing["rowHeight"].to_string())
        .replace("__TOC_FONT__", &toc_sizing["fontSize"].to_string())
        .replace("__NAV_DEFAULT__", &toc_sizing["navigatorWidth"].to_string())
        .replace(
            "__TOC_MAX__",
            &(toc_sizing["maximumFraction"].as_f64().unwrap() * 100.0).to_string(),
        );
    // Match the trusted reader's opening tag: its JavaScript contains HTML
    // strings, including </head>, which are not document insertion points.
    let reader_tag = format!("<script nonce=\"{nonce}\">");
    let pos = document_html.find(&reader_tag).unwrap_or(0);
    let (head, rest) = document_html.split_at(pos);
    let with_css = format!("{head}{native_bridge}<style>{shell_css}</style>{rest}");

    if let (Some(art_start), Some(art_end)) =
        (with_css.find("<article>"), with_css.rfind("</article>"))
    {
        let before_article = &with_css[..art_start];
        let article_content = &with_css[art_start..art_end + "</article>".len()];
        let after_article = &with_css[art_end + "</article>".len()..];

        let injected_shell = shell_html.replace("__MDVU_ARTICLE_CONTENT__", article_content);
        format!("{before_article}{injected_shell}{after_article}")
    } else {
        with_css
    }
}
