(()=>{'use strict';
const esc=s=>s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const highlightOne=el=>{
const source=el.textContent;
if(!source||source.length>300000)return;
const lang=(el.className.match(/\blanguage-([\w-]+)\b/)||[,''])[1].toLowerCase();
const isHashComment=/^(py|python|sh|bash|zsh|rb|ruby|yaml|yml|r|pl|perl|dockerfile|makefile)$/.test(lang);
const isCStyle=/^(c|cpp|cxx|h|hpp|objc|m|mm|cs|swift|go|rust|rs|java|kt|kotlin|js|javascript|ts|typescript|json)$/.test(lang);
const token=/("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`|\/\*[\s\S]*?\*\/|\/\/[^\n]*|#[^\n]*|\b(?:class|struct|enum|protocol|func|let|var|if|else|for|while|return|import|from|def|async|await|throw|throws|try|catch|switch|case|const|function|new|true|false|null|nil|public|private|static|final)\b|\b\d+(?:\.\d+)?\b)/g;
let out='',last=0,match;
while((match=token.exec(source))!==null){
const start=match.index;
if(start>last)out+=esc(source.slice(last,start));
const part=match[0];
last=start+part.length;
let type='keyword';
const c0=part.charCodeAt(0);
if(c0===34||c0===39||c0===96){type='string';}
else if(part.startsWith('/*')||part.startsWith('//')){type='comment';}
else if(c0===35){
if(isCStyle&&/^#\s*(?:include|define|undef|pragma|import|ifdef|ifndef|endif|if|elif|else)\b/.test(part)){type='preproc';}
else if(isHashComment||!isCStyle){type='comment';}
else{type='preproc';}
}else if(c0>=48&&c0<=57){type='number';}
out+=`<span class="tok-${type}">${esc(part)}</span>`;
}
if(last<source.length)out+=esc(source.slice(last));
el.innerHTML=out;
};
let lastTOCKey='';
const decorateHeadings=()=>{
const counts=new Map,usedIDs=new Set,entries=[];
document.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(heading=>{
heading.querySelector('.heading-anchor')?.remove();
const title=heading.textContent.trim();
let base=title.toLocaleLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu,'').trim().replace(/\s+/g,'-')||'section',count=counts.get(base)||0;
let id=count?`${base}-${count}`:base;
while(usedIDs.has(id)){count++;id=`${base}-${count}`}
counts.set(base,count+1);usedIDs.add(id);
heading.id=id;
entries.push({level:Number(heading.tagName.slice(1)),title,id:heading.id});
const anchor=document.createElement('a');
anchor.className='heading-anchor';
anchor.href=`#${heading.id}`;
anchor.textContent='#';
heading.prepend(anchor);
});
const newKey=JSON.stringify(entries);
if(newKey!==lastTOCKey){
lastTOCKey=newKey;
window.webkit?.messageHandlers?.tableOfContents?.postMessage(entries);
}
};
const wrapTables=()=>document.querySelectorAll('article table').forEach(table=>{if(table.parentElement?.classList.contains('table-wrap'))return;const wrapper=document.createElement('div');wrapper.className='table-wrap';table.replaceWith(wrapper);wrapper.append(table)});
const scheduleHighlight=()=>{const blocks=document.querySelectorAll('pre>code');if(!('IntersectionObserver'in window)){blocks.forEach(highlightOne);return}const observer=new IntersectionObserver(entries=>entries.forEach(entry=>{if(entry.isIntersecting){observer.unobserve(entry.target);highlightOne(entry.target)}}),{rootMargin:'800px 0px'});blocks.forEach(block=>observer.observe(block))};
let diagramSeq=0,mermaidInitialized=false,currentMermaidTheme=null,diagramObserver=null;
const diagramQueue=[];let isProcessingQueue=false;
const cleanDiagramSource=s=>{
let res=s.replace(/^[ \t]*>[ \t]?/gm,'').trim();
if(/^\s*requirementDiagram/m.test(res)){
res=res
.replace(/^(\s*id:\s*)([^"\s\n\r][^\n\r]*)$/gm,(m,p1,p2)=>`${p1}"${p2.trim()}"`)
.replace(/^(\s*text:\s*)([^"\s\n\r][^\n\r]*)$/gm,(m,p1,p2)=>`${p1}"${p2.trim()}"`)
.replace(/^(\s*docref:\s*)([^"\s\n\r][^\n\r]*)$/gm,(m,p1,p2)=>`${p1}"${p2.trim()}"`);
}
return res;
};
const ensureMermaidInit=async()=>{
if(typeof mermaid==='undefined')return;
const selected=document.documentElement.dataset.theme;
const isDark=selected==='dark'||(selected==='system'&&matchMedia('(prefers-color-scheme:dark)').matches);
const targetTheme=isDark?'dark':'default';
if(mermaidInitialized&&currentMermaidTheme===targetTheme)return;
if(window['mermaid-zenuml']&&!window.__zenumlRegistered){
try{await mermaid.registerExternalDiagrams([window['mermaid-zenuml']]);window.__zenumlRegistered=true}
catch(err){console.error('ZenUML registration error:',err)}
}
mermaid.initialize({startOnLoad:false,securityLevel:'loose',maxTextSize:1000000,maxEdges:10000,theme:targetTheme,themeVariables:{background:'transparent'},suppressErrorRendering:true});
mermaidInitialized=true;
currentMermaidTheme=targetTheme;
};
const postDiagramCache=(key,svg)=>{if(!key||!svg)return;if(window.webkit?.messageHandlers?.diagramCache)window.webkit.messageHandlers.diagramCache.postMessage({key,svg});if(window.ipc?.postMessage)window.ipc.postMessage('cache_diagram:'+JSON.stringify({key,svg}))};
const renderSingleDiagram=async(node)=>{
if(!node.classList.contains('diagram-pending')||node.__mdvuRendering)return;
node.__mdvuRendering=true;
const pre=node.querySelector('pre');
if(!pre){node.classList.remove('diagram-pending');delete node.__mdvuRendering;return}
const renderer=node.dataset.renderer,rawSource=pre.textContent,source=cleanDiagramSource(rawSource),key=node.dataset.cacheKey;
try{
if(renderer==='mermaid'){
if(typeof mermaid==='undefined'){delete node.__mdvuRendering;node.__mdvuQueued=false;return}
await ensureMermaidInit();
const diagId=`mdvu-diagram-${++diagramSeq}`;
const result=await mermaid.render(diagId,source);
node.innerHTML=result.svg;
node.classList.remove('diagram-pending');
node.classList.add('diagram-rendered');
postDiagramCache(key,result.svg);
}else if(renderer==='plantuml'){
if(typeof PlantUML==='undefined'||!PlantUML.renderToString){delete node.__mdvuRendering;node.__mdvuQueued=false;return}
const selected=document.documentElement.dataset.theme;
const isDark=selected==='dark'||(selected==='system'&&matchMedia('(prefers-color-scheme:dark)').matches);
let lines=source.trim().split(/\r?\n/);
if(!lines.some(l=>/^\s*@start/i.test(l))){lines.unshift('@startuml');lines.push('@enduml')}
if(isDark&&!lines.some(l=>/^\s*skinparam\s+backgroundColor/i.test(l))){lines.splice(1,0,'skinparam backgroundColor transparent')}
await new Promise((resolve,reject)=>{
PlantUML.renderToString(lines,svg=>{
if(!svg){reject(new Error('PlantUML returned empty output'));return}
node.innerHTML=svg;
node.classList.remove('diagram-pending');
node.classList.add('diagram-rendered');
postDiagramCache(key,svg);
resolve();
},err=>reject(new Error(err)));
});
}
}catch(e){
node.classList.add('diagram-error');
node.innerHTML=`<strong>Diagram could not be rendered</strong><pre></pre><small></small>`;
node.querySelector('pre').textContent=rawSource;
node.querySelector('small').textContent=String(e.message||e);
}finally{
delete node.__mdvuRendering;
}
};
const isElementInViewport=(el,margin=1200)=>{
const rect=el.getBoundingClientRect(),vh=window.innerHeight||document.documentElement.clientHeight||800;
return rect.top<=vh+margin&&rect.bottom>=-margin;
};
const processQueue=async()=>{
if(isProcessingQueue)return;
isProcessingQueue=true;
while(diagramQueue.length>0){
const visibleIdx=diagramQueue.findIndex(n=>isElementInViewport(n,200));
const node=visibleIdx!==-1?diagramQueue.splice(visibleIdx,1)[0]:diagramQueue.shift();
if(node&&node.classList.contains('diagram-pending')){
await renderSingleDiagram(node);
await new Promise(r=>requestAnimationFrame(r));
}
}
isProcessingQueue=false;
};
const enqueueDiagram=(node)=>{
if(!node.classList.contains('diagram-pending')||node.__mdvuQueued)return;
node.__mdvuQueued=true;
diagramQueue.push(node);
processQueue();
};
const initDiagramObserver=()=>{
if(!('IntersectionObserver'in window))return null;
if(diagramObserver)return diagramObserver;
diagramObserver=new IntersectionObserver((entries)=>{
entries.forEach(entry=>{
if(entry.isIntersecting){
diagramObserver.unobserve(entry.target);
enqueueDiagram(entry.target);
}
});
},{rootMargin:'1200px 0px'});
return diagramObserver;
};
const isRendererReady=r=>(r==='mermaid'&&typeof mermaid!=='undefined')||(r==='plantuml'&&typeof PlantUML!=='undefined'&&!!PlantUML.renderToString);
const renderDiagrams=async(options)=>{
const forceAll=options===true||options?.all===true;
const pendingNodes=[...document.querySelectorAll('.diagram-pending')].filter(n=>isRendererReady(n.dataset.renderer));
if(!pendingNodes.length)return;
const observer=initDiagramObserver();
if(forceAll||!observer){
for(const node of pendingNodes){
if(observer)observer.unobserve(node);
await renderSingleDiagram(node);
await new Promise(r=>requestAnimationFrame(r));
}
return;
}
const initialBatch=[];
pendingNodes.forEach(node=>{
if(isElementInViewport(node,1200)){
initialBatch.push(node);
}else{
observer.observe(node);
}
});
for(const node of initialBatch){
await renderSingleDiagram(node);
await new Promise(r=>requestAnimationFrame(r));
}
};
window.__mdvuRestoreScroll=()=>{if(window.__mdvuRestore)requestAnimationFrame(()=>scrollTo(0,document.documentElement.scrollHeight*window.__mdvuRestore.ratio))};
window.__mdvuRenderDiagrams=renderDiagrams;
const renderMath=()=>{
if(typeof katex==='undefined'||!katex.render)return;
const mathNodes=document.querySelectorAll('.math-inline:not(.math-rendered), .math-display:not(.math-rendered)');
mathNodes.forEach(node=>{
const isDisplay=node.classList.contains('math-display');
const tex=node.textContent;
try{
katex.render(tex,node,{output:'mathml',displayMode:isDisplay,throwOnError:false});
node.classList.add('math-rendered');
}catch(e){
node.classList.add('katex-error');
node.textContent=tex;
}
});
};
window.__mdvuRenderMath=renderMath;
window.__mdvuScrollToFragment=(id,push=true)=>{const compact=value=>value.replace(/-/g,''),target=document.getElementById(id)||document.getElementsByName(id)[0]||[...document.querySelectorAll('h1,h2,h3,h4,h5,h6')].find(heading=>compact(heading.id)===compact(id));if(!target)return false;try{(push?history.pushState:history.replaceState).call(history,null,'','#'+encodeURIComponent(id))}catch(e){}target.scrollIntoView({block:'start'});if(push&&window.webkit?.messageHandlers?.navigationHistory){window.webkit.messageHandlers.navigationHistory.postMessage({fragment:id})}return true};
document.addEventListener('click',event=>{const anchor=event.target.closest?.('a[href]'),href=anchor?.getAttribute('href');if(!href?.startsWith('#'))return;let id;try{id=decodeURIComponent(href.slice(1))}catch{id=href.slice(1)}if(window.__mdvuScrollToFragment(id)){event.preventDefault()}});
let allMatches=[];let currentIndex=-1;
const clearFind=()=>{
if(!allMatches.length)return;
document.querySelectorAll('mark.find-match').forEach(m=>m.replaceWith(...m.childNodes));
document.querySelector('article')?.normalize();
allMatches=[];currentIndex=-1;
};
const searchFind=q=>{
clearFind();
if(!q||!q.trim())return{count:0,current:0};
const article=document.querySelector('article')||document.body;
const walker=document.createTreeWalker(article,NodeFilter.SHOW_TEXT,{
acceptNode:node=>{
const p=node.parentElement;
if(!p)return NodeFilter.FILTER_REJECT;
const tag=p.tagName;
if(tag==='SCRIPT'||tag==='STYLE'||tag==='MARK'||p.classList.contains('heading-anchor')||p.closest('.diagram-pending,.diagram-error'))return NodeFilter.FILTER_REJECT;
return NodeFilter.FILTER_ACCEPT;
}
});
const nodes=[];let n;
while(n=walker.nextNode())nodes.push(n);
const pattern=new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),'giu'),created=[];
for(const node of nodes){
const text=node.textContent;
pattern.lastIndex=0;
let match=pattern.exec(text);
if(!match)continue;
const frag=document.createDocumentFragment();
let last=0;
while(match){
const idx=match.index,len=match[0].length;
if(idx>last)frag.appendChild(document.createTextNode(text.slice(last,idx)));
const mark=document.createElement('mark');
mark.className='find-match';
mark.textContent=text.slice(idx,idx+len);
frag.appendChild(mark);
created.push(mark);
last=idx+len;
match=pattern.exec(text);
}
if(last<text.length)frag.appendChild(document.createTextNode(text.slice(last)));
node.replaceWith(frag);
}
allMatches=created;
if(allMatches.length){
currentIndex=0;
allMatches[0].classList.add('find-current');
allMatches[0].scrollIntoView({block:'center',behavior:'smooth'});
}
return{count:allMatches.length,current:allMatches.length?1:0};
};
const stepFind=delta=>{
if(!allMatches.length)return{count:0,current:0};
allMatches[currentIndex].classList.remove('find-current');
currentIndex=(currentIndex+delta+allMatches.length)%allMatches.length;
allMatches[currentIndex].classList.add('find-current');
allMatches[currentIndex].scrollIntoView({block:'center',behavior:'smooth'});
return{count:allMatches.length,current:currentIndex+1};
};
window.__mdvuFind={search:searchFind,next:()=>stepFind(1),previous:()=>stepFind(-1),clear:clearFind};
window.__mdvuToggleTOC=()=>{
let panel=document.getElementById('mdvu-toc-panel');
if(panel){panel.classList.toggle('visible');return}
const headings=document.querySelectorAll('h1,h2,h3,h4,h5,h6');
if(!headings.length)return;
panel=document.createElement('nav');
panel.id='mdvu-toc-panel';
panel.className='visible';
let html='<div class="toc-header"><strong>Table of Contents</strong><button id="mdvu-toc-close" type="button" title="Close (Esc)">&times;</button></div><ul class="toc-list">';
headings.forEach(h=>{
const lvl=h.tagName.slice(1);
const title=h.textContent.replace(/^#\s*/,'').trim();
html+=`<li class="toc-item toc-lvl-${lvl}"><a href="#${encodeURIComponent(h.id)}">${esc(title)}</a></li>`;
});
html+='</ul>';
panel.innerHTML=html;
document.body.appendChild(panel);
panel.querySelector('#mdvu-toc-close')?.addEventListener('click',()=>panel.classList.remove('visible'));
panel.querySelectorAll('a').forEach(a=>{a.addEventListener('click',()=>panel.classList.remove('visible'))});
};
window.__mdvuInitArticle=()=>{decorateHeadings();wrapTables();scheduleHighlight();renderMath();renderDiagrams()};
window.addEventListener('keydown',e=>{if(e.key==='Escape'){document.getElementById('mdvu-toc-panel')?.classList.remove('visible')}});
document.addEventListener('DOMContentLoaded',()=>{window.__mdvuRestoreScroll();requestAnimationFrame(()=>{window.__mdvuInitArticle()})});
})();
