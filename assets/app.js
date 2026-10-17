(()=>{'use strict';
const esc=s=>s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const highlightOne=el=>{
const source=el.textContent;
if(!source||source.length>300000)return;
const lang=(el.className.match(/\blanguage-([\w-]+)\b/)||[,''])[1].toLowerCase();
if(/^(text|plain|plaintext|txt|none)$/.test(lang))return;
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
document.querySelectorAll('article h1,article h2,article h3,article h4,article h5,article h6').forEach(heading=>{
heading.querySelector('.heading-anchor')?.remove();
const copy=heading.cloneNode(true);copy.querySelectorAll('img[alt]').forEach(img=>img.replaceWith(document.createTextNode(img.alt)));
const title=copy.textContent.trim();
let base=title.toLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu,'').trim().replace(/\s+/g,'-')||'section',count=counts.get(base)||0;
const explicit=!!heading.id&&!heading.dataset.mdvuGeneratedId;
let id=heading.dataset.mdvuGeneratedId===heading.id?'':heading.id;
id=id||(count?`${base}-${count}`:base);
while(usedIDs.has(id)){count++;id=`${base}-${count}`}
counts.set(base,count+1);usedIDs.add(id);
heading.id=id;if(!explicit)heading.dataset.mdvuGeneratedId=id;
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
window.__mdvuOnTOC?.(entries);
}
};
const wrapTables=()=>document.querySelectorAll('article table').forEach(table=>{if(table.parentElement?.classList.contains('table-wrap'))return;const wrapper=document.createElement('div');wrapper.className='table-wrap';table.replaceWith(wrapper);wrapper.append(table)});
let highlightObserver=null,legacyCodeObserver=null;
const needsCodeVisibilityFallback=!CSS.supports('content-visibility','auto')&&'IntersectionObserver'in window;
document.documentElement.classList.add('mdvu-code-pending');
const revealCodeChunk=node=>{const chunk=node.closest?.('.mdvu-code-virtual');if(chunk)chunk.firstElementChild.hidden=false};
// Older WebKit cannot skip offscreen line groups. Keep their text in the DOM
// for find/ranges, with a fixed-height placeholder until the group is visible.
// Native selection/copy must see the complete text before it builds the range.
const revealLegacyCode=event=>{if(event.target?.closest?.('input,textarea,select,[contenteditable]:not([contenteditable=false])'))return;document.querySelectorAll('.mdvu-code-virtual>.mdvu-code-content').forEach(content=>{content.hidden=false})};
if(needsCodeVisibilityFallback){
 document.addEventListener('selectstart',revealLegacyCode);
 document.addEventListener('copy',revealLegacyCode);
 document.addEventListener('selectionchange',()=>{if(window.getSelection()?.isCollapsed)document.querySelectorAll('.mdvu-code-virtual').forEach(chunk=>{legacyCodeObserver?.unobserve(chunk);legacyCodeObserver?.observe(chunk)})});
}
const scheduleHighlight=()=>{
highlightObserver?.disconnect();legacyCodeObserver?.disconnect();
document.documentElement.classList.add('mdvu-code-pending');
// A single Unicode corpus can force seconds of font shaping on every zoom.
// Keep its text intact, but give the browser independent line groups to skip.
document.querySelectorAll('pre>code:not(.mdvu-chunked)').forEach(code=>{
const source=code.textContent;if(source.length<65536)return;
const style=getComputedStyle(code.parentElement),lineHeight=parseFloat(style.lineHeight)||parseFloat(style.fontSize)*1.55;
code.style.lineHeight=lineHeight+'px';const fragment=document.createDocumentFragment();
for(let offset=0;offset<source.length;){
let end=offset,lines=0;
while(lines<32&&end<source.length){const next=source.indexOf('\n',end);end=next<0?source.length:next+1;lines++}
const chunk=document.createElement('span');chunk.className=code.className+' mdvu-code-chunk';chunk.textContent=source.slice(offset,end);
chunk.style.setProperty('--mdvu-chunk-height',lines*lineHeight+'px');
if(needsCodeVisibilityFallback&&style.whiteSpace==='pre'){const content=document.createElement('span');content.className='mdvu-code-content '+code.className;content.append(...chunk.childNodes);content.hidden=true;chunk.append(content);chunk.classList.add('mdvu-code-virtual')}
fragment.append(chunk);offset=end;
}
code.replaceChildren(fragment);code.classList.add('mdvu-chunked');
});
if(needsCodeVisibilityFallback&&'IntersectionObserver'in window){
 legacyCodeObserver=new IntersectionObserver(entries=>entries.forEach(entry=>{const chunk=entry.target;if(entry.isIntersecting)chunk.firstElementChild.hidden=false;else if(window.getSelection()?.isCollapsed!==false&&!chunk.querySelector('.find-current'))chunk.firstElementChild.hidden=true}),{rootMargin:'800px 0px'});
 document.querySelectorAll('.mdvu-code-virtual').forEach(chunk=>legacyCodeObserver.observe(chunk));
}
document.documentElement.classList.remove('mdvu-code-pending');
const blocks=document.querySelectorAll('pre>code:not(.mdvu-chunked),.mdvu-code-chunk:not(.mdvu-code-virtual),.mdvu-code-content');
if(!('IntersectionObserver'in window)){blocks.forEach(highlightOne);return}
const observer=highlightObserver=new IntersectionObserver(entries=>entries.forEach(entry=>{if(entry.isIntersecting){observer.unobserve(entry.target);highlightOne(entry.target)}}),{rootMargin:'800px 0px'});
blocks.forEach(block=>observer.observe(block));
};
// Mermaid measures temporary SVGs in its own document, independent of the reading DOM.
window.__mdvuLoadMermaid=source=>{
if(window.__mdvuMermaidReady)return window.__mdvuMermaidReady;
window.__mdvuMermaidReady=new Promise((resolve,reject)=>{
const frame=document.createElement('iframe');frame.title='Diagram renderer';frame.setAttribute('aria-hidden','true');frame.tabIndex=-1;
frame.style.cssText='position:fixed;left:-10000px;top:0;width:920px;height:800px;visibility:hidden;pointer-events:none;border:0';
frame.onload=()=>{try{const context=frame.contentWindow,script=context.document.createElement('script');script.nonce=document.querySelector('meta[name=mdvu-script-nonce]').content;script.textContent=source;context.document.head.append(script);script.remove();source='';if(!context.mermaid)throw new Error('Mermaid runtime failed to initialize');window.mermaid=context.mermaid;window['mermaid-zenuml']=context['mermaid-zenuml'];resolve();window.__mdvuRenderDiagrams?.()}catch(error){window.__mdvuMermaidError=String(error);reject(error)}};
frame.srcdoc='<!doctype html><html><head><style>body{margin:0;font:16px Arial,sans-serif}</style></head><body></body></html>';document.body.append(frame);
});
return window.__mdvuMermaidReady;
};
const nativeDiagrams=()=>window.__mdvuNativeDiagramTransport;
const diagramRequests=new Map,diagramSession=Math.random().toString(36).slice(2);
window.__mdvuDiagramTimings=[];
window.__mdvuDiagramResult=result=>{const request=diagramRequests.get(result.id);if(!request)return;diagramRequests.delete(result.id);window.__mdvuDiagramTimings.push({type:result.type,ms:result.ms});if(result.error)request.reject(new Error(result.error));else request.resolve(result.svg)};
const renderNativeDiagram=(renderer,source,dark)=>new Promise((resolve,reject)=>{const id=diagramSession+String(++diagramSeq);diagramRequests.set(id,{resolve,reject});nativeDiagrams().post({id,renderer,source,dark})});
let diagramSeq=0,mermaidInitialized=false,currentMermaidTheme=null,diagramObserver=null;
const diagramStyle='<style>svg{max-width:100%;height:auto;background:transparent!important}.find-match{fill:#9b6400!important;text-decoration:underline}.find-current{fill:#c2410c!important}</style>';
const diagramViewportMargin=400,diagramRetentionMargin=800;
const diagramSVGs=new WeakMap;
const mountDiagram=node=>{
const record=diagramSVGs.get(node),host=node.querySelector('.diagram-content');
if(!record||!host||host.shadowRoot.firstChild)return;
host.style.aspectRatio='';host.shadowRoot.innerHTML=diagramStyle+record.svg;
};
const unmountDiagram=node=>{
const record=diagramSVGs.get(node),host=node.querySelector('.diagram-content');
if(!record||!host?.shadowRoot.firstChild||record.findActive)return;
// ResizeObserver supplies the last actual size without forcing an offscreen SVG
// to lay itself out. Its lightweight placeholder keeps the scroll position.
host.style.aspectRatio=record.ratio||'auto';host.shadowRoot.replaceChildren();
};
const diagramSizeObserver=typeof ResizeObserver==='undefined'?null:new ResizeObserver(entries=>entries.forEach(entry=>{
const record=diagramSVGs.get(entry.target.parentElement);
if(record&&entry.target.shadowRoot?.firstChild&&entry.contentRect.height>0)record.ratio=String(entry.contentRect.width/entry.contentRect.height);
}));
const diagramVisibilityObserver=typeof IntersectionObserver==='undefined'?null:new IntersectionObserver(entries=>entries.forEach(entry=>{
if(entry.isIntersecting&&isElementInViewport(entry.target))mountDiagram(entry.target);
}),{rootMargin:diagramViewportMargin+'px 0px'});
// Separate enter/leave bounds prevent repeated SVG parsing when reflow moves a
// diagram back and forth across the viewport boundary. Both observers are bounded.
const diagramRetentionObserver=typeof IntersectionObserver==='undefined'?null:new IntersectionObserver(entries=>entries.forEach(entry=>{if(!entry.isIntersecting&&!isElementInViewport(entry.target,diagramRetentionMargin))unmountDiagram(entry.target)}),{rootMargin:diagramRetentionMargin+'px 0px'});
window.__mdvuHasDiagramSVG=node=>diagramSVGs.has(node)||!!node.querySelector('.diagram-content')?.shadowRoot?.querySelector('svg');
// SVG styles otherwise join the page stylesheet set and slow every later render and zoom.
const installDiagramSVG=(node,svg)=>{
let host=node.querySelector('.diagram-content');
if(!host){host=document.createElement('div');host.className='diagram-content';host.attachShadow({mode:'open'});node.replaceChildren(host)}
const header=svg.match(/<svg\b[^>]*>/i)?.[0]||'';
const box=header.match(/\bviewBox=["']\s*[-\d.]+[ ,]+[-\d.]+[ ,]+([\d.]+)[ ,]+([\d.]+)\s*["']/);
const ratio=box&&Number(box[2])>0?String(Number(box[1])/Number(box[2])):'auto';
diagramSVGs.set(node,{svg,ratio});host.style.aspectRatio=ratio;
const width=header.match(/max-width:\s*([\d.]+)px/i)||header.match(/\bwidth=["']([\d.]+)(?:px)?["']/);
host.style.maxWidth=width?width[1]+'px':'';host.style.marginInline='auto';
if(!diagramVisibilityObserver)mountDiagram(node);
diagramSizeObserver?.observe(host);diagramVisibilityObserver?.observe(node);diagramRetentionObserver?.observe(node);
};
const diagramQueue=[];let isProcessingQueue=false,lastReadingInput=-Infinity;
['wheel','touchmove','keydown'].forEach(type=>window.addEventListener(type,event=>{if(event.isTrusted)lastReadingInput=performance.now()},{passive:true}));
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
mermaid.initialize({startOnLoad:false,securityLevel:'strict',maxTextSize:1000000,maxEdges:10000,theme:targetTheme,themeVariables:{background:'transparent'},suppressErrorRendering:true});
mermaidInitialized=true;
currentMermaidTheme=targetTheme;
};
const postDiagramCache=(key,svg)=>{if(!key||!svg)return;if(window.webkit?.messageHandlers?.diagramCache)window.webkit.messageHandlers.diagramCache.postMessage({key,svg});if(window.ipc?.postMessage)window.ipc.postMessage('cache_diagram:'+JSON.stringify({key,svg}))};
const renderSingleDiagram=async(node)=>{
if(!node.isConnected||!node.classList.contains('diagram-pending')||node.__mdvuRendering)return;
node.__mdvuRendering=true;
const pre=node.querySelector('pre');
if(!pre){node.classList.remove('diagram-pending');delete node.__mdvuRendering;return}
const renderer=node.dataset.renderer,rawSource=pre.textContent,source=cleanDiagramSource(rawSource),key=node.dataset.cacheKey;
try{
const selected=document.documentElement.dataset.theme;
const isDark=selected==='dark'||(selected==='system'&&matchMedia('(prefers-color-scheme:dark)').matches);
let svg;
if(nativeDiagrams()){svg=await renderNativeDiagram(renderer,source,isDark)}
else if(renderer==='mermaid'){
if(typeof mermaid==='undefined'){delete node.__mdvuRendering;node.__mdvuQueued=false;return}
await ensureMermaidInit();
svg=(await mermaid.render(`mdvu-diagram-${++diagramSeq}`,source)).svg;
}else if(renderer==='plantuml'){
if(typeof PlantUML==='undefined'||!PlantUML.renderToString){delete node.__mdvuRendering;node.__mdvuQueued=false;return}
const lines=source.trim().split(/\r?\n/);
if(!lines.some(l=>/^\s*@start/i.test(l))){lines.unshift('@startuml');lines.push('@enduml')}
if(isDark&&!lines.some(l=>/^\s*skinparam\s+backgroundColor/i.test(l)))lines.splice(1,0,'skinparam backgroundColor transparent');
svg=await new Promise((resolve,reject)=>PlantUML.renderToString(lines,value=>value?resolve(value):reject(new Error('PlantUML returned empty output')),error=>reject(new Error(error))));
}
if(!node.isConnected)return;
installDiagramSVG(node,svg);
node.classList.remove('diagram-pending');node.classList.add('diagram-rendered');
postDiagramCache(key,svg);
}catch(e){
if(!node.isConnected)return;
node.classList.remove('diagram-pending');
node.classList.add('diagram-error');
node.innerHTML=`<strong>Diagram could not be rendered</strong><pre></pre><small></small>`;
node.querySelector('pre').textContent=rawSource;
node.querySelector('small').textContent=String(e.message||e);
}finally{
delete node.__mdvuRendering;
}
};
const isElementInViewport=(el,margin=diagramViewportMargin)=>{
const rect=el.getBoundingClientRect(),vh=window.innerHeight||document.documentElement.clientHeight||800;
return rect.top<=vh+margin&&rect.bottom>=-margin;
};
const finishQueuedDiagram=node=>{node.__mdvuResolve?.();delete node.__mdvuResolve;delete node.__mdvuRenderPromise;node.__mdvuQueued=false};
const processQueue=async()=>{
if(isProcessingQueue)return;
isProcessingQueue=true;
try{
while(diagramQueue.length>0){
while(performance.now()-lastReadingInput<120)await new Promise(r=>setTimeout(r,32));
if(!diagramQueue.length)break;
const visibleIdx=diagramQueue.length>1?diagramQueue.findIndex(n=>n.isConnected&&isElementInViewport(n,200)):0;
const node=visibleIdx!==-1?diagramQueue.splice(visibleIdx,1)[0]:diagramQueue.shift();
try{if(node?.isConnected&&node.classList.contains('diagram-pending'))await renderSingleDiagram(node)}
finally{finishQueuedDiagram(node)}
await new Promise(r=>setTimeout(r,0));
}
}finally{isProcessingQueue=false}
};
const enqueueDiagram=node=>{
if(!node.isConnected||!node.classList.contains('diagram-pending'))return Promise.resolve();
if(node.__mdvuRenderPromise)return node.__mdvuRenderPromise;
node.__mdvuQueued=true;
const promise=node.__mdvuRenderPromise=new Promise(resolve=>node.__mdvuResolve=resolve);
diagramQueue.push(node);
processQueue();
return promise;
};
const initDiagramObserver=()=>{
if(!('IntersectionObserver'in window))return null;
if(diagramObserver)return diagramObserver;
diagramObserver=new IntersectionObserver((entries)=>{
entries.forEach(entry=>{
if(entry.isIntersecting&&isElementInViewport(entry.target)){
diagramObserver.unobserve(entry.target);
enqueueDiagram(entry.target);
}
});
},{rootMargin:diagramViewportMargin+'px 0px'});
return diagramObserver;
};
const isRendererReady=r=>!!nativeDiagrams()||(r==='mermaid'&&typeof mermaid!=='undefined')||(r==='plantuml'&&typeof PlantUML!=='undefined'&&!!PlantUML.renderToString);
const renderDiagrams=async(options)=>{
const forceAll=options===true||options?.all===true;
if(window.__mdvuMermaidReady&&document.querySelector('.diagram-pending[data-renderer="mermaid"]'))await window.__mdvuMermaidReady;
const pendingNodes=[...document.querySelectorAll('.diagram-pending')].filter(n=>isRendererReady(n.dataset.renderer));
if(!pendingNodes.length)return;
const observer=initDiagramObserver();
if(forceAll||!observer){
for(const node of pendingNodes){
if(observer)observer.unobserve(node);
await enqueueDiagram(node);
}
return;
}
const initialBatch=[];
pendingNodes.forEach(node=>{
if(isElementInViewport(node)){
initialBatch.push(node);
}else{
observer.observe(node);
}
});
for(const node of initialBatch){
await enqueueDiagram(node);
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
let readingAnchor=null,readingAnchorSeq=0;
const cancelReadingAnchor=()=>{if(readingAnchor){const {scroller,overflowAnchor,overflowAnchorPriority}=readingAnchor;scroller.style.setProperty('overflow-anchor',overflowAnchor,overflowAnchorPriority)}readingAnchor=null};
window.__mdvuCaptureReadingAnchor=(target=null,anchorOffset)=>{
cancelReadingAnchor();
const scroller=document.getElementById('mdvu-main-content')||document.scrollingElement;
const rect=scroller===document.scrollingElement?{left:0,top:0,width:innerWidth,height:innerHeight}:scroller.getBoundingClientRect();
let el=target||document.elementFromPoint(rect.left+rect.width/2,rect.top+rect.height/2);
el=target||el?.closest('p,h1,h2,h3,h4,h5,h6,li,pre,tr,blockquote,table,img,figure');
const token=++readingAnchorSeq,overflowAnchor=scroller.style.getPropertyValue('overflow-anchor'),overflowAnchorPriority=scroller.style.getPropertyPriority('overflow-anchor');
scroller.style.setProperty('overflow-anchor','none','important');
readingAnchor={token,scroller,el,overflowAnchor,overflowAnchorPriority,viewportWidth:innerWidth,offset:anchorOffset??(el?(el.getBoundingClientRect().top-rect.top)/rect.height:0),ratio:scroller.scrollTop/Math.max(1,scroller.scrollHeight-scroller.clientHeight)};
return token;
};
window.__mdvuRestoreReadingAnchor=(token,viewportScale=null)=>{
let frames=0,start,stable=0;
const restore=()=>{
if(readingAnchor?.token!==token)return;
const {scroller,el,offset,ratio,viewportWidth}=readingAnchor;
if(viewportScale!==null&&Math.abs(innerWidth-viewportWidth*viewportScale)>2&&frames++<4){requestAnimationFrame(restore);return}
start??=performance.now();
const rect=scroller===document.scrollingElement?{top:0,height:innerHeight}:scroller.getBoundingClientRect();
const delta=el?.isConnected?el.getBoundingClientRect().top-rect.top-offset*rect.height:ratio*Math.max(1,scroller.scrollHeight-scroller.clientHeight)-scroller.scrollTop;
if(Math.abs(delta)>.5){scroller.scrollBy({top:delta,behavior:'instant'});stable=0}else stable++;
// Lazy layout can move a block without resizing it or the article. Keep checking
// through the deferred layout frames, with one bounded task cancelled by input.
const elapsed=performance.now()-start;
if(elapsed<300||stable<2&&elapsed<1000)requestAnimationFrame(restore);
else{cancelReadingAnchor();window.__mdvuReadingAnchorSettled=token}
};
requestAnimationFrame(restore);
};
window.__mdvuPreserveReadingAnchor=mutate=>{const token=window.__mdvuCaptureReadingAnchor();mutate();window.__mdvuRestoreReadingAnchor(token)};
const scrollToReadingTarget=(target,offset)=>{revealCodeChunk(target);const token=window.__mdvuCaptureReadingAnchor(target,offset);target.scrollIntoView({block:offset===0?'start':'center',behavior:'instant'});window.__mdvuRestoreReadingAnchor(token)};
window.__mdvuScrollToFragment=(id,push=true)=>{try{id=decodeURIComponent(id)}catch{}const compact=value=>value.replace(/-/g,''),target=document.getElementById(id)||document.getElementsByName(id)[0]||[...document.querySelectorAll('h1,h2,h3,h4,h5,h6')].find(heading=>compact(heading.id)===compact(id));if(!target)return false;try{(push?history.pushState:history.replaceState).call(history,null,'','#'+encodeURIComponent(id))}catch(e){}scrollToReadingTarget(target,0);if(push&&window.webkit?.messageHandlers?.navigationHistory){window.webkit.messageHandlers.navigationHistory.postMessage({fragment:id})}return true};
document.addEventListener('click',event=>{const anchor=event.target.closest?.('a[href]'),href=anchor?.getAttribute('href');if(!href?.startsWith('#'))return;let id;try{id=decodeURIComponent(href.slice(1))}catch{id=href.slice(1)}if(window.__mdvuScrollToFragment(id)){event.preventDefault()}});
let allMatches=[];let currentIndex=-1;
const clearFind=()=>{
cancelReadingAnchor();
const parents=new Set;
allMatches.forEach(m=>{parents.add(m.parentNode);m.replaceWith(...m.childNodes)});
parents.forEach(p=>p?.normalize());
allMatches=[];currentIndex=-1;
document.querySelectorAll('figure.diagram-rendered').forEach(node=>{const record=diagramSVGs.get(node);if(record){record.findActive=false;if(!isElementInViewport(node,diagramRetentionMargin))unmountDiagram(node)}});
};
const searchFind=q=>{
clearFind();
if(!q||!q.trim())return{count:0,current:0};
const article=document.querySelector('article')||document.body;
// Only materialize offscreen diagrams which can contain this query. Searching
// labels must not retain every SVG DOM in a long document.
// Singleton classes preserve Unicode case folding without WebKit's faulty
// ignore-case literal fast path, which skips matches in long UTF-16 strings.
const pattern=new RegExp([...q].map(c=>'['+c.replace(/[\\\]\[\^-]/g,'\\$&')+']').join(''),'giu'),decode=document.createElement('textarea');
article.querySelectorAll('figure.diagram-rendered').forEach(node=>{
const record=diagramSVGs.get(node);if(!record)return;
if(record.text===undefined){decode.innerHTML=record.svg.replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi,'').replace(/<[^>]*>/g,' ');record.text=decode.value}
pattern.lastIndex=0;if(pattern.test(record.text)){record.findActive=true;mountDiagram(node)}
});
const nodes=[];
const collect=root=>{
const walker=document.createTreeWalker(root,NodeFilter.SHOW_ELEMENT|NodeFilter.SHOW_TEXT);let node;
while(node=walker.nextNode()){
if(node.nodeType===Node.ELEMENT_NODE){if(node.shadowRoot)collect(node.shadowRoot);continue}
const p=node.parentElement;
if(p&&!p.closest('script,style,.find-match,.heading-anchor,.diagram-pending,.diagram-error'))nodes.push(node);
}
};
collect(article);
const created=[];
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
const mark=node.parentElement.namespaceURI==='http://www.w3.org/2000/svg'?document.createElementNS('http://www.w3.org/2000/svg','tspan'):document.createElement('mark');
mark.setAttribute('class','find-match');
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
scrollToReadingTarget(allMatches[0],.5);
}
return{count:allMatches.length,current:allMatches.length?1:0};
};
const stepFind=delta=>{
if(!allMatches.length)return{count:0,current:0};
allMatches[currentIndex].classList.remove('find-current');
currentIndex=(currentIndex+delta+allMatches.length)%allMatches.length;
allMatches[currentIndex].classList.add('find-current');
scrollToReadingTarget(allMatches[currentIndex],.5);
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
window.__mdvuDisposeArticle=()=>{nativeDiagrams()?.cancel();diagramRequests.forEach(request=>request.reject(new Error('Diagram cancelled')));diagramRequests.clear();window.__mdvuDiagramTimings.length=0;cancelReadingAnchor();readingEdgeGeneration++;highlightObserver?.disconnect();highlightObserver=null;legacyCodeObserver?.disconnect();legacyCodeObserver=null;diagramObserver?.disconnect();diagramObserver=null;diagramSizeObserver?.disconnect();diagramVisibilityObserver?.disconnect();diagramRetentionObserver?.disconnect();diagramQueue.splice(0).forEach(finishQueuedDiagram);clearFind();document.getElementById('mdvu-toc-panel')?.remove();lastTOCKey=''};
window.__mdvuInitArticle=()=>{document.querySelectorAll('figure.diagram-rendered:not(.diagram-pending)').forEach(node=>{if(!node.querySelector('.diagram-content')&&node.querySelector('svg'))installDiagramSVG(node,node.innerHTML)});decorateHeadings();wrapTables();scheduleHighlight();renderMath();renderDiagrams()};
let readingEdgeGeneration=0;
for(const type of ['wheel','touchmove','pointerdown'])window.addEventListener(type,()=>{readingEdgeGeneration++;cancelReadingAnchor()},{passive:true});
window.addEventListener('keydown',e=>{
readingEdgeGeneration++;cancelReadingAnchor();
if(e.key==='Escape')document.getElementById('mdvu-toc-panel')?.classList.remove('visible');
if(e.defaultPrevented||e.shiftKey||e.altKey||e.target?.closest?.('input,textarea,select,[contenteditable]:not([contenteditable=false])'))return;
const end=e.key==='End'||(e.metaKey&&e.key==='ArrowDown'),home=e.key==='Home'||(e.metaKey&&e.key==='ArrowUp');
if(!end&&!home)return;
e.preventDefault();
const scroller=document.getElementById('mdvu-main-content')||document.scrollingElement;
cancelReadingAnchor();
if(home){scroller.scrollTo({top:0,behavior:'instant'});return}
// Offscreen content can acquire its real height after the initial jump.
// Keep the bottom anchored through layout, but stop as soon as the reader acts.
const generation=readingEdgeGeneration;
let frames=0,stable=0,lastHeight=0;
const reachEnd=()=>{
if(generation!==readingEdgeGeneration)return;
const height=scroller.scrollHeight;
scroller.scrollTo({top:height,behavior:'instant'});
stable=height===lastHeight?stable+1:0;lastHeight=height;
if(++frames<8&&stable<2)requestAnimationFrame(reachEnd);
else window.__mdvuReadingEdgeSettled=generation;
};
reachEnd();
});
document.addEventListener('DOMContentLoaded',()=>{window.__mdvuInitArticle();window.__mdvuRestoreScroll()});
})();
