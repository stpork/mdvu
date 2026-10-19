const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const shell = fs.readFileSync('src/windows/src/gui_shell.rs', 'utf8');
const start = shell.indexOf("  const findInput = document.getElementById('mdvu-find-input');\n  const findCount");
const end = shell.indexOf('  // Keyboard shortcut listener in webview', start);
assert.ok(start >= 0 && end > start);
const source = shell.slice(start, end).replace(/\{\{/g, '{').replace(/\}\}/g, '}');

function setup() {
  const handlers = {}, timers = new Map(), calls = [];
  let sequence = 0;
  const element = id => ({value: '', classList: {add() {}, remove() {}}, focus() {}, select() {}, blur() {},
    addEventListener: (type, handler) => { handlers[id + ':' + type] = handler; }});
  const elements = Object.fromEntries(['mdvu-find-input', 'mdvu-find-count', 'btn-find-next', 'btn-find-prev', 'btn-find-close'].map(id => [id, element(id)]));
  vm.runInNewContext(source, {
    document: {getElementById: id => elements[id]},
    window: {__mdvuFind: {
      search: value => (calls.push(['search', value]), {count: 3, current: 1}),
      next: () => (calls.push(['next']), {count: 3, current: 2}),
      previous: () => (calls.push(['previous']), {count: 3, current: 3}),
      clear: () => calls.push(['clear']),
    }},
    setTimeout: callback => { timers.set(++sequence, callback); return sequence; },
    clearTimeout: id => timers.delete(id),
  });
  return {calls, input(value) { elements['mdvu-find-input'].value = value; handlers['mdvu-find-input:input'](); },
    settle() { for (const [id, callback] of timers) { timers.delete(id); callback(); } },
    key(key, shiftKey = false) { handlers['mdvu-find-input:keydown']({key, shiftKey, preventDefault() {}}); },
    close() { handlers['btn-find-close:click'](); }};
}

test('Enter and Shift+Enter navigate immediately after the debounced search', () => {
  const find = setup();
  find.input('needle'); find.settle(); find.key('Enter'); find.key('Enter', true);
  assert.deepEqual(find.calls, [['search', 'needle'], ['next'], ['previous']]);
});

test('Enter flushes a pending query once; later Enter navigates', () => {
  const find = setup();
  find.input('needle'); find.key('Enter'); find.settle(); find.key('Enter');
  assert.deepEqual(find.calls, [['search', 'needle'], ['next']]);
});

test('clearing a pending query leaves no stale timer or query', () => {
  for (const clear of [find => find.input(''), find => find.key('Escape'), find => find.close()]) {
    const find = setup();
    find.input('obsolete'); clear(find); find.settle(); find.key('Enter');
    assert.deepEqual(find.calls, [['clear'], ['next']]);
  }
});
