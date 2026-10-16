use crate::navigator::VaultItem;
use mdvu_core::TocEntry;

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
    let toc_json = serde_json::to_string(toc).unwrap_or_else(|_| "[]".to_string());
    let vault_json = serde_json::to_string(vault_items).unwrap_or_else(|_| "[]".to_string());
    let current_path_json = serde_json::to_string(&current_file_path.unwrap_or("")).unwrap_or_else(|_| "\"\"".to_string());
    let zoom_pct = (zoom_level * 100.0).round() as i32;

    let shell_css = r#"
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
  height: 40px;
  min-height: 40px;
  max-height: 40px;
  display: flex;
  align-items: center;
  padding: 0 10px;
  gap: 6px;
  border-bottom: 1px solid var(--line);
  background: color-mix(in srgb, var(--bg) 90%, var(--soft));
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
  width: 270px;
  max-width: 32vw;
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
  font-family: ui-monospace, monospace;
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
.zoom-btn:hover {
  background: var(--soft);
}
.zoom-val {
  border: 0;
  background: transparent;
  width: 44px;
  text-align: center;
  font-size: 11px;
  font-family: ui-monospace, monospace;
  color: var(--fg);
  outline: none;
  cursor: pointer;
}
#mdvu-split-container {
  display: flex;
  flex: 1;
  overflow: hidden;
  position: relative;
}
.mdvu-sidebar {
  width: 270px;
  min-width: 270px;
  max-width: 270px;
  background: color-mix(in srgb, var(--bg) 95%, var(--soft));
  display: flex;
  flex-direction: column;
  overflow: hidden;
  transition: margin 0.16s ease;
  user-select: none;
  z-index: 500;
  box-sizing: border-box;
}
.mdvu-sidebar-left {
  border-right: 1px solid var(--line);
}
.mdvu-sidebar-left.hidden {
  margin-left: -271px;
}
.mdvu-sidebar-right {
  border-left: 1px solid var(--line);
}
.mdvu-sidebar-right.hidden {
  margin-right: -271px;
}
.sidebar-header {
  height: 34px;
  min-height: 34px;
  padding: 0 10px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid var(--line);
  font-size: 12px;
  font-weight: 600;
  color: var(--muted);
  background: var(--soft);
  box-sizing: border-box;
}
.sidebar-title {
  display: flex;
  align-items: center;
  gap: 6px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.sidebar-close {
  background: none;
  border: 0;
  color: var(--muted);
  font-size: 16px;
  line-height: 1;
  cursor: pointer;
  padding: 2px 4px;
  border-radius: 4px;
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
  scroll-behavior: smooth;
}
/* TOC Items */
.toc-entry {
  display: block;
  padding: 4px 8px;
  margin: 1px 0;
  border-radius: 4px;
  color: var(--fg);
  text-decoration: none;
  font-size: 12.5px;
  line-height: 1.35;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  cursor: pointer;
}
.toc-entry:hover {
  background: var(--soft);
  color: var(--accent);
}
.toc-entry.active {
  background: color-mix(in srgb, var(--accent) 15%, transparent);
  color: var(--accent);
  font-weight: 600;
}
.toc-lvl-1 { font-weight: 600; }
.toc-lvl-2 { padding-left: 16px; }
.toc-lvl-3 { padding-left: 28px; font-size: 11.5px; opacity: 0.9; }
.toc-lvl-4, .toc-lvl-5, .toc-lvl-6 { padding-left: 38px; font-size: 11px; opacity: 0.8; }

/* Navigator Tree Items */
.nav-item {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 6px;
  margin: 1px 0;
  border-radius: 4px;
  font-size: 12.5px;
  color: var(--fg);
  cursor: pointer;
  text-decoration: none;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.nav-item:hover {
  background: var(--soft);
}
.nav-item.active {
  background: color-mix(in srgb, var(--accent) 18%, transparent);
  color: var(--accent);
  font-weight: 600;
}
.nav-folder-content {
  padding-left: 12px;
}
.nav-arrow {
  display: inline-block;
  font-size: 9px;
  width: 12px;
  color: var(--muted);
  transition: transform 0.12s ease;
}
.nav-arrow.expanded {
  transform: rotate(90deg);
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
      <button id="btn-toc" class="toolbar-btn {toc_active}" title="Toggle Table of Contents (Ctrl+Shift+S / Ctrl+B)">
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><line x1="9" y1="3" x2="9" y2="21"></line><line x1="14" y1="8" x2="18" y2="8"></line><line x1="14" y1="12" x2="18" y2="12"></line><line x1="14" y1="16" x2="18" y2="16"></line></svg>
      </button>
    </div>

    <div class="toolbar-flex"></div>

    <div class="toolbar-group">
      <div class="search-box">
        <span class="search-icon">
          <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
        </span>
        <input id="mdvu-find-input" type="search" placeholder="Find in document... (Ctrl+F)" autocomplete="off" spellcheck="false" />
        <span id="mdvu-find-count" class="find-count"></span>
        <button id="btn-find-prev" class="find-nav-btn" title="Previous match (Shift+Enter / Shift+F3)">▲</button>
        <button id="btn-find-next" class="find-nav-btn" title="Next match (Enter / F3)">▼</button>
        <button id="btn-find-close" class="find-nav-btn" title="Clear search (Esc)">×</button>
      </div>
    </div>

    <div class="toolbar-group">
      <div class="zoom-group">
        <button id="btn-zoom-out" class="zoom-btn" title="Zoom Out (Ctrl+-)">−</button>
        <input id="mdvu-zoom-val" class="zoom-val" value="{zoom_pct}%" title="Zoom level (Ctrl+0 to reset)" readonly />
        <button id="btn-zoom-in" class="zoom-btn" title="Zoom In (Ctrl++)">+</button>
      </div>
    </div>

    <div class="toolbar-group">
      <button id="btn-full-width" class="toolbar-btn {fw_active}" title="Toggle Full Width (Ctrl+Shift+W)">
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 3 21 3 21 9"></polyline><polyline points="9 21 3 21 3 15"></polyline><line x1="21" y1="3" x2="14" y2="10"></line><line x1="3" y1="21" x2="10" y2="14"></line></svg>
      </button>
      <button id="btn-navigator" class="toolbar-btn {nav_active}" title="Toggle File Navigator (Ctrl+Shift+D)">
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path></svg>
      </button>
    </div>
  </header>

  <!-- Split View Body Container -->
  <div id="mdvu-split-container">
    <!-- Left Sidebar: Table of Contents -->
    <aside id="mdvu-toc-sidebar" class="mdvu-sidebar mdvu-sidebar-left {toc_hidden}">
      <div class="sidebar-header">
        <span class="sidebar-title">📑 Table of Contents</span>
        <button id="btn-toc-close" class="sidebar-close" title="Hide Table of Contents (Ctrl+Shift+S)">×</button>
      </div>
      <nav id="mdvu-toc-tree" class="sidebar-content"></nav>
    </aside>

    <!-- Center Main Content -->
    <main id="mdvu-main-content">
      <div id="mdvu-article-wrap">
        __MDVU_ARTICLE_CONTENT__
      </div>
    </main>

    <!-- Right Sidebar: File Navigator -->
    <aside id="mdvu-navigator-sidebar" class="mdvu-sidebar mdvu-sidebar-right {nav_hidden}">
      <div class="sidebar-header">
        <span class="sidebar-title">📁 <span id="nav-vault-name">{vault_name}</span></span>
        <button id="btn-nav-close" class="sidebar-close" title="Hide File Navigator (Ctrl+Shift+D)">×</button>
      </div>
      <div id="mdvu-nav-tree" class="sidebar-content"></div>
    </aside>
  </div>
</div>

<script>
(()=>{{
  window.__mdvuInitialTOC = {toc_json};
  window.__mdvuInitialVault = {vault_json};
  window.__mdvuCurrentPath = {current_path_json};

  // Setup TOC sidebar
  function renderTOC(entries) {{
    const container = document.getElementById('mdvu-toc-tree');
    if (!container) return;
    if (!entries || !entries.length) {{
      container.innerHTML = '<div style="color:var(--muted);padding:16px 10px;text-align:center;font-size:12px;">No headings found</div>';
      return;
    }}
    let html = '';
    entries.forEach(e => {{
      const lvl = Math.min(Math.max(e.level, 1), 6);
      html += `<a class="toc-entry toc-lvl-${{lvl}}" href="#${{encodeURIComponent(e.id)}}" data-id="${{e.id}}">${{e.title}}</a>`;
    }});
    container.innerHTML = html;

    container.querySelectorAll('a').forEach(a => {{
      a.addEventListener('click', (evt) => {{
        evt.preventDefault();
        const id = a.getAttribute('data-id');
        if (window.__mdvuScrollToFragment) {{
          window.__mdvuScrollToFragment(id);
        }} else {{
          const el = document.getElementById(id);
          if (el) el.scrollIntoView({{ behavior: 'smooth', block: 'start' }});
        }}
        container.querySelectorAll('a').forEach(x => x.classList.remove('active'));
        a.classList.add('active');
      }});
    }});
  }}

  // Setup Vault / File Navigator sidebar
  function renderVault(items, currentPath) {{
    const container = document.getElementById('mdvu-nav-tree');
    if (!container) return;
    if (!items || !items.length) {{
      container.innerHTML = '<div style="color:var(--muted);padding:16px 10px;text-align:center;font-size:12px;">No markdown files</div>';
      return;
    }}
    function buildTree(list) {{
      let h = '';
      list.forEach(item => {{
        if (item.is_dir) {{
          h += `<div class="nav-folder">
            <div class="nav-item nav-folder-header">
              <span class="nav-arrow expanded">▶</span> 📁 <span>${{item.name}}</span>
            </div>
            <div class="nav-folder-content">
              ${{item.children ? buildTree(item.children) : ''}}
            </div>
          </div>`;
        }} else {{
          const isAct = currentPath && (item.path === currentPath || currentPath.endsWith(item.path) || item.path.endsWith(currentPath));
          h += `<div class="nav-item nav-file ${{isAct ? 'active' : ''}}" data-path="${{item.path}}">
            📄 <span>${{item.name}}</span>
          </div>`;
        }}
      }});
      return h;
    }}
    container.innerHTML = buildTree(items);

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

    container.querySelectorAll('.nav-file').forEach(fileEl => {{
      fileEl.addEventListener('click', () => {{
        const p = fileEl.getAttribute('data-path');
        if (p && window.ipc) {{
          window.ipc.postMessage('open_path:' + p);
        }}
      }});
    }});
  }}

  renderTOC(window.__mdvuInitialTOC);
  renderVault(window.__mdvuInitialVault, window.__mdvuCurrentPath);

  window.__mdvuToggleTOCSidebar = (force) => {{
    const aside = document.getElementById('mdvu-toc-sidebar');
    const btn = document.getElementById('btn-toc');
    if (!aside) return;
    const isHidden = typeof force === 'boolean' ? !force : !aside.classList.contains('hidden');
    aside.classList.toggle('hidden', isHidden);
    if (btn) btn.classList.toggle('active', !isHidden);
  }};

  window.__mdvuToggleNavSidebar = (force) => {{
    const aside = document.getElementById('mdvu-navigator-sidebar');
    const btn = document.getElementById('btn-navigator');
    if (!aside) return;
    const isHidden = typeof force === 'boolean' ? !force : !aside.classList.contains('hidden');
    aside.classList.toggle('hidden', isHidden);
    if (btn) btn.classList.toggle('active', !isHidden);
  }};

  window.__mdvuToggleFullWidth = (force) => {{
    const html = document.documentElement;
    const btn = document.getElementById('btn-full-width');
    const isFw = typeof force === 'boolean' ? force : !html.classList.contains('full-width');
    html.classList.toggle('full-width', isFw);
    if (btn) btn.classList.toggle('active', isFw);
  }};

  window.__mdvuSetZoom = (pct) => {{
    const val = document.getElementById('mdvu-zoom-val');
    if (val) val.value = pct + '%';
    const wrap = document.getElementById('mdvu-article-wrap') || document.querySelector('article');
    if (wrap) wrap.style.zoom = (pct / 100.0);
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

  // Wire Toolbar buttons
  document.getElementById('btn-back')?.addEventListener('click', () => window.ipc?.postMessage('go_back'));
  document.getElementById('btn-forward')?.addEventListener('click', () => window.ipc?.postMessage('go_forward'));
  document.getElementById('btn-toc')?.addEventListener('click', () => {{
    window.__mdvuToggleTOCSidebar();
    window.ipc?.postMessage('toggle_toc');
  }});
  document.getElementById('btn-toc-close')?.addEventListener('click', () => {{
    window.__mdvuToggleTOCSidebar(false);
    window.ipc?.postMessage('toggle_toc');
  }});
  document.getElementById('btn-navigator')?.addEventListener('click', () => {{
    window.__mdvuToggleNavSidebar();
    window.ipc?.postMessage('toggle_nav');
  }});
  document.getElementById('btn-nav-close')?.addEventListener('click', () => {{
    window.__mdvuToggleNavSidebar(false);
    window.ipc?.postMessage('toggle_nav');
  }});
  document.getElementById('btn-full-width')?.addEventListener('click', () => {{
    window.__mdvuToggleFullWidth();
    window.ipc?.postMessage('toggle_full_width');
  }});
  document.getElementById('btn-zoom-in')?.addEventListener('click', () => window.ipc?.postMessage('zoom_in'));
  document.getElementById('btn-zoom-out')?.addEventListener('click', () => window.ipc?.postMessage('zoom_out'));
  document.getElementById('mdvu-zoom-val')?.addEventListener('dblclick', () => window.ipc?.postMessage('zoom_reset'));

  // Wire Find / Search Box
  const findInput = document.getElementById('mdvu-find-input');
  const findCount = document.getElementById('mdvu-find-count');

  function updateFindCount(res) {{
    if (!findCount) return;
    if (!res || res.count === 0) {{
      findCount.textContent = findInput && findInput.value.trim() ? 'No matches' : '';
    }} else {{
      findCount.textContent = `${{res.current}} of ${{res.count}}`;
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
    if (window.__mdvuFind) {{
      const res = window.__mdvuFind.search(findInput.value);
      updateFindCount(res);
    }}
  }});

  findInput?.addEventListener('keydown', (e) => {{
    if (e.key === 'Enter') {{
      e.preventDefault();
      if (window.__mdvuFind) {{
        const res = e.shiftKey ? window.__mdvuFind.previous() : window.__mdvuFind.next();
        updateFindCount(res);
      }}
    }} else if (e.key === 'Escape') {{
      e.preventDefault();
      if (window.__mdvuFind) window.__mdvuFind.clear();
      if (findInput) {{ findInput.value = ''; findInput.blur(); }}
      if (findCount) findCount.textContent = '';
    }}
  }});

  document.getElementById('btn-find-next')?.addEventListener('click', () => {{
    window.__mdvuFindNext();
  }});
  document.getElementById('btn-find-prev')?.addEventListener('click', () => {{
    window.__mdvuFindPrev();
  }});
  document.getElementById('btn-find-close')?.addEventListener('click', () => {{
    if (window.__mdvuFind) window.__mdvuFind.clear();
    if (findInput) findInput.value = '';
    if (findCount) findCount.textContent = '';
  }});

  // Keyboard shortcut listener in webview
  window.addEventListener('keydown', (e) => {{
    const ctrl = e.ctrlKey || e.metaKey;
    if (ctrl && e.key === 'f') {{
      e.preventDefault();
      findInput?.focus();
      findInput?.select();
    }} else if (e.key === 'F3') {{
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
    }} else if (ctrl && e.shiftKey && (e.key === 's' || e.key === 'S')) {{
      e.preventDefault();
      window.ipc?.postMessage('toggle_toc');
    }} else if (ctrl && (e.key === 'b' || e.key === 'B')) {{
      e.preventDefault();
      window.ipc?.postMessage('toggle_toc');
    }} else if (ctrl && e.shiftKey && (e.key === 'd' || e.key === 'D')) {{
      e.preventDefault();
      window.ipc?.postMessage('toggle_nav');
    }} else if (ctrl && e.shiftKey && (e.key === 'w' || e.key === 'W')) {{
      e.preventDefault();
      window.ipc?.postMessage('toggle_full_width');
    }} else if (ctrl && (e.key === '=' || e.key === '+')) {{
      e.preventDefault();
      window.ipc?.postMessage('zoom_in');
    }} else if (ctrl && (e.key === '-' || e.key === '_')) {{
      e.preventDefault();
      window.ipc?.postMessage('zoom_out');
    }} else if (ctrl && (e.key === '0')) {{
      e.preventDefault();
      window.ipc?.postMessage('zoom_reset');
    }} else if (e.altKey && e.key === 'ArrowLeft') {{
      e.preventDefault();
      window.ipc?.postMessage('go_back');
    }} else if (e.altKey && e.key === 'ArrowRight') {{
      e.preventDefault();
      window.ipc?.postMessage('go_forward');
    }} else if (e.key === 'F11') {{
      e.preventDefault();
      window.ipc?.postMessage('toggle_fullscreen');
    }} else if (e.key === 'Escape') {{
      if (document.activeElement === findInput) {{
        if (window.__mdvuFind) window.__mdvuFind.clear();
        findInput.value = '';
        if (findCount) findCount.textContent = '';
        findInput.blur();
      }}
    }}
  }});
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

    // Inject shell_css into <head> and replace <article>...</article> with shell_html
    let with_css = if let Some(pos) = document_html.find("</head>") {
        let (head, rest) = document_html.split_at(pos);
        format!("{head}<style>{shell_css}</style>{rest}")
    } else {
        format!("<style>{shell_css}</style>{document_html}")
    };

    if let (Some(art_start), Some(art_end)) = (with_css.find("<article>"), with_css.find("</article>")) {
        let before_article = &with_css[..art_start];
        let article_content = &with_css[art_start..art_end + "</article>".len()];
        let after_article = &with_css[art_end + "</article>".len()..];

        let injected_shell = shell_html.replace("__MDVU_ARTICLE_CONTENT__", article_content);
        format!("{before_article}{injected_shell}{after_article}")
    } else {
        with_css
    }
}
