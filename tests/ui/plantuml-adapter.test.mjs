import test from 'node:test';
import assert from 'node:assert/strict';
import {createPlantUMLRenderer} from '../../assets/plantuml-adapter.mjs';
const render=(renderer,lines,options)=>new Promise((resolve,reject)=>renderer.renderToString(lines,resolve,reject,options));
test('ordinary PlantUML retains callbacks and options',async()=>{
 const options={dark:true};let actual;
 const renderer=createPlantUMLRenderer({renderToString(...args){actual=args;args[1]('<svg/>');}},{});
 assert.equal(await render(renderer,['@startuml','A->B','@enduml'],options),'<svg/>');assert.equal(actual[3],options);
});
test('DOT shares one Viz instance and forwards its body and theme',async()=>{
 let initializations=0;const requests=[];
 const renderer=createPlantUMLRenderer({}, {async instance(){initializations++;return {renderString(body,options){requests.push({body,options});return '<svg/>';}};}});
 await Promise.all([render(renderer,['@startdot','digraph { A -> B }','@enddot']),render(renderer,['@startdot','graph { A -- B }','@enddot'],{dark:true})]);
 assert.equal(initializations,1);assert.equal(requests[0].body,'digraph { A -> B }');assert.equal(requests[1].options.nodeAttributes.fontcolor,'#e0e0e0');
 await globalThis.PLANTUML_VIZ.instance();assert.equal(initializations,1,'PlantUML and DOT must share the same WASM instance');
});
test('malformed DOT and Viz errors reject instead of returning a picture',async()=>{
 const renderer=createPlantUMLRenderer({}, {async instance(){return {renderString(){throw new Error('syntax error');}};}});
 await assert.rejects(render(renderer,['@startdot','bad']),/Missing @enddot/);
 await assert.rejects(render(renderer,['@startdot','bad','@enddot']),/syntax error/);
});
