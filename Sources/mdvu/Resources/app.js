(()=>{'use strict';
const esc=s=>s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const highlightOne=el=>{const source=el.textContent;if(source.length>300000)return;const token=/("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`|\/\/[^\n]*|#[^\n]*|\b(?:class|struct|enum|protocol|func|let|var|if|else|for|while|return|import|from|def|async|await|throw|throws|try|catch|switch|case|const|function|new|true|false|null|nil|public|private|static|final)\b|\b\d+(?:\.\d+)?\b)/g;el.innerHTML=source.split(token).map((part,i)=>{if(i%2===0)return esc(part);let type=/^("|'|`)/.test(part)?'string':/^(\/\/|#)/.test(part)?'comment':/^\d/.test(part)?'number':'keyword';return `<span class="tok-${type}">${esc(part)}</span>`}).join('')};
const decorateHeadings=()=>{const counts=new Map,entries=[];document.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(heading=>{const title=heading.textContent.trim();let base=title.toLocaleLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu,'').trim().replace(/\s+/g,'-')||'section',count=counts.get(base)||0;counts.set(base,count+1);heading.id=count?`${base}-${count}`:base;entries.push({level:Number(heading.tagName.slice(1)),title,id:heading.id});const anchor=document.createElement('a');anchor.className='heading-anchor';anchor.href=`#${heading.id}`;anchor.textContent='#';heading.prepend(anchor)});window.webkit?.messageHandlers?.tableOfContents?.postMessage(entries)};
const wrapTables=()=>document.querySelectorAll('article table').forEach(table=>{const wrapper=document.createElement('div');wrapper.className='table-wrap';table.replaceWith(wrapper);wrapper.append(table)});
const scheduleHighlight=()=>{const blocks=document.querySelectorAll('pre>code');if(!('IntersectionObserver'in window)){blocks.forEach(highlightOne);return}const observer=new IntersectionObserver(entries=>entries.forEach(entry=>{if(entry.isIntersecting){observer.unobserve(entry.target);highlightOne(entry.target)}}),{rootMargin:'800px 0px'});blocks.forEach(block=>observer.observe(block))};
const renderDiagrams=async()=>{const nodes=[...document.querySelectorAll('.diagram-pending[data-renderer="mermaid"]')];if(!nodes.length||typeof mermaid==='undefined')return;const selected=document.documentElement.dataset.theme;const dark=selected==='dark'||selected==='system'&&matchMedia('(prefers-color-scheme:dark)').matches;mermaid.initialize({startOnLoad:false,securityLevel:'strict',theme:dark?'dark':'default',themeVariables:{background:'transparent'},suppressErrorRendering:true});for(let i=0;i<nodes.length;i++){const node=nodes[i],source=node.querySelector('pre').textContent,key=node.dataset.cacheKey;try{await new Promise(r=>requestAnimationFrame(r));const result=await mermaid.render(`mdvu-diagram-${i}-${Date.now()}`,source);node.innerHTML=result.svg;node.classList.remove('diagram-pending');if(window.webkit?.messageHandlers?.diagramCache)window.webkit.messageHandlers.diagramCache.postMessage({key,svg:result.svg})}catch(e){node.classList.add('diagram-error');node.innerHTML=`<strong>Diagram could not be rendered</strong><pre></pre><small></small>`;node.querySelector('pre').textContent=source;node.querySelector('small').textContent=String(e.message||e)}}};
window.__mdvuRestoreScroll=()=>{if(window.__mdvuRestore)requestAnimationFrame(()=>scrollTo(0,document.documentElement.scrollHeight*window.__mdvuRestore.ratio))};
window.__mdvuRenderDiagrams=renderDiagrams;
window.__mdvuScrollToFragment=(id,push=true)=>{const compact=value=>value.replace(/-/g,''),target=document.getElementById(id)||document.getElementsByName(id)[0]||[...document.querySelectorAll('h1,h2,h3,h4,h5,h6')].find(heading=>compact(heading.id)===compact(id));if(!target)return false;(push?history.pushState:history.replaceState).call(history,null,'','#'+encodeURIComponent(id));target.scrollIntoView({block:'start'});if(push&&window.webkit?.messageHandlers?.navigationHistory){window.webkit.messageHandlers.navigationHistory.postMessage({fragment:id})}return true};
document.addEventListener('click',event=>{const anchor=event.target.closest?.('a[href]'),href=anchor?.getAttribute('href');if(!href?.startsWith('#'))return;let id;try{id=decodeURIComponent(href.slice(1))}catch{id=href.slice(1)}if(window.__mdvuScrollToFragment(id)){event.preventDefault()}});
let allMatches=[];let currentIndex=-1;
const clearFind=()=>{document.querySelectorAll('mark.find-match').forEach(m=>m.replaceWith(...m.childNodes));document.querySelector('article')?.normalize();allMatches=[];currentIndex=-1};
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
const lower=q.toLocaleLowerCase(),len=q.length,created=[];
for(const node of nodes){
const text=node.textContent,lText=text.toLocaleLowerCase();
let idx=lText.indexOf(lower);
if(idx===-1)continue;
const frag=document.createDocumentFragment();
let last=0;
while(idx!==-1){
if(idx>last)frag.appendChild(document.createTextNode(text.slice(last,idx)));
const mark=document.createElement('mark');
mark.className='find-match';
mark.textContent=text.slice(idx,idx+len);
frag.appendChild(mark);
created.push(mark);
last=idx+len;
idx=lText.indexOf(lower,last);
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
document.addEventListener('DOMContentLoaded',()=>{window.__mdvuRestoreScroll();requestAnimationFrame(()=>{decorateHeadings();wrapTables();scheduleHighlight()})});
})();
