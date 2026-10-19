const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const classify = require('../../assets/diagram-output.js');
for (const [file, reason] of [['plantuml-unsupported','unsupported-diagram'],['plantuml-missing-library','missing-library'],['plantuml-syntax-error','syntax-error'],['plantuml-preprocessor-error','preprocessor-error']]) {
  test('real MDVu SVG: '+file, () => {
    const svg = fs.readFileSync(path.join(__dirname,'fixtures',file+'.svg'),'utf8');
    assert.match(svg, /<svg\b/); // Each engine callback previously reported successful SVG output.
    assert.equal(classify('plantuml',svg.replace(/<[^>]*>/g,' ')),reason);
    assert.throws(()=>classify.validate('plantuml',svg),new RegExp(reason));
  });
}
test('ordinary diagram labels are not diagnostic panels', () => {
  for (const text of ['Error handling','Cannot include optional module','Syntax Error?','Diagram not supported by this release of PlantUML']) assert.equal(classify('plantuml',text),null);
});
