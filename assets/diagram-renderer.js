// Runs in the native renderer WebView, never in the reading document.
(()=>{'use strict';
window.requestAnimationFrame=callback=>setTimeout(()=>callback(performance.now()),0);
const send=value=>{value.session=window.__mdvuRendererSession||'';if(window.webkit?.messageHandlers?.diagramResult)window.webkit.messageHandlers.diagramResult.postMessage(value);else window.chrome.webview.postMessage(JSON.stringify(value))};
let theme=null,registered=false;
window.__mdvuRunDiagramJob=async job=>{
const start=performance.now();let result;
try{
let svg;
if(job.renderer==='mermaid'){
if(!registered&&window['mermaid-zenuml']){await mermaid.registerExternalDiagrams([window['mermaid-zenuml']]);registered=true}
const next=job.dark?'dark':'default';
if(theme!==next){mermaid.initialize({startOnLoad:false,securityLevel:'strict',maxTextSize:1000000,maxEdges:10000,theme:next,themeVariables:{background:'transparent'},suppressErrorRendering:true});theme=next}
svg=(await mermaid.render('mdvu-worker-diagram',job.source)).svg;
}else if(job.renderer==='plantuml'){
const lines=job.source.trim().split(/\r?\n/);
if(!lines.some(l=>/^\s*@start/i.test(l))){lines.unshift('@startuml');lines.push('@enduml')}
if(job.dark&&!/^\s*@startdot\b/i.test(lines[0])&&!lines.some(l=>/^\s*skinparam\s+backgroundColor/i.test(l)))lines.splice(1,0,'skinparam backgroundColor transparent');
svg=await new Promise((resolve,reject)=>PlantUML.renderToString(lines,value=>value?resolve(value):reject(new Error('PlantUML returned empty output')),error=>reject(new Error(error)),{dark:job.dark}));
window.__mdvuValidateDiagramSVG('plantuml',svg);
}else throw new Error('Unknown diagram renderer');
if(typeof svg!=='string'||svg.length>10000000)throw new Error('Diagram output exceeds 10 MB');
result={id:job.id,svg,ms:performance.now()-start,type:job.source.split('\n')[0]};
}catch(error){result={id:job.id,error:String(error.message||error),ms:performance.now()-start,type:job.source.split('\n')[0]}}
finally{document.body.replaceChildren()}
send(result);
};
send({ready:true});
})();
