const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

// Execute the actual shell click handler without starting a browser.
const shell = fs.readFileSync('src/windows/src/gui_shell.rs', 'utf8');
const start = shell.indexOf('  // Intercept article link clicks');
const end = shell.indexOf('  // Wire Toolbar buttons', start);
assert.ok(start >= 0 && end > start);
const source = shell.slice(start, end).replace(/\{\{/g, '{').replace(/\}\}/g, '}');

test('relative Markdown links preserve URL component boundaries across IPC', () => {
  let click;
  const messages = [];
  vm.runInNewContext(source, {
    document: {getElementById: () => ({addEventListener: (_, handler) => { click = handler; }})},
    window: {ipc: {postMessage: message => messages.push(message)}},
  });
  for (const [href, path, fragment] of [
    ['notes%23draft.md', 'notes#draft.md', null],
    ['notes%23draft.md#section%231', 'notes#draft.md', 'section#1'],
    ['notes.md#section#1', 'notes.md', 'section#1'],
    ['folder/схема%20%23100%25.md?view=1#раздел', 'folder/схема #100%.md', 'раздел'],
    ['notes%2523draft.md', 'notes%23draft.md', null],
    ['notes%20draft.md', 'notes draft.md', null],
  ]) {
    let prevented = false;
    click({target: {closest: () => ({getAttribute: () => href})}, preventDefault() { prevented = true; }});
    assert.ok(prevented, href);
    const message = messages.pop();
    assert.ok(message.startsWith('open_rel_path:'), href);
    assert.deepEqual(JSON.parse(message.slice('open_rel_path:'.length)), {path, fragment});
  }
});
