// Native Windows TOC: the same hierarchy and expansion policy as NSOutlineView.
window.__mdvuBuildTOCTree=(container,entries,policy,navigate)=>{
container.replaceChildren();container.setAttribute('role','tree');container.setAttribute('aria-label','Table of Contents');
const roots=[],stack=[];
for(const entry of entries){
const node={entry,children:[]};
while(stack.length&&stack.at(-1).entry.level>=entry.level)stack.pop();
(stack.length?stack.at(-1).children:roots).push(node);stack.push(node);
}
const append=(nodes,parent,depth)=>nodes.forEach((node,index)=>{
const item=document.createElement('div');item.className='toc-node';item.setAttribute('role','treeitem');item.tabIndex=-1;
item.dataset.id=node.entry.id;item.setAttribute('aria-label',node.entry.title);item.setAttribute('aria-level',depth+1);item.setAttribute('aria-posinset',index+1);item.setAttribute('aria-setsize',nodes.length);item.setAttribute('aria-selected','false');
const row=document.createElement('div');row.className='toc-row';row.style.paddingInlineStart=depth*policy.indentation+'px';
const caret=document.createElement('button');caret.className='toc-expander';caret.tabIndex=-1;caret.setAttribute('aria-hidden','true');caret.textContent='›';
const title=document.createElement('span');title.className='toc-title';title.textContent=node.entry.title;title.title=node.entry.title;
row.append(caret,title);item.append(row);parent.append(item);
if(node.children.length){const expanded=entries.length<=policy.expandAllLimit||depth===0;item.setAttribute('aria-expanded',String(expanded));const group=document.createElement('div');group.setAttribute('role','group');group.hidden=!expanded;item.append(group);append(node.children,group,depth+1)}
else caret.style.visibility='hidden';
});
append(roots,container,0);
const items=()=>[...container.querySelectorAll('.toc-node')].filter(node=>!node.closest('[hidden]'));
const focus=item=>{if(!item)return;container.querySelector('[tabindex="0"]')?.setAttribute('tabindex','-1');container.querySelector('[aria-selected="true"]')?.setAttribute('aria-selected','false');item.tabIndex=0;item.setAttribute('aria-selected','true');item.focus({preventScroll:true});item.querySelector('.toc-row').scrollIntoView({block:'nearest'});navigate(item.dataset.id)};
const expand=(item,value)=>{const group=item.querySelector(':scope>[role="group"]');if(!group)return;item.setAttribute('aria-expanded',String(value));group.hidden=!value};
container.querySelector('.toc-node')?.setAttribute('tabindex','0');
container.onclick=event=>{const item=event.target.closest('.toc-row')?.parentElement;if(!item)return;if(event.target.closest('.toc-expander'))expand(item,item.getAttribute('aria-expanded')!=='true');else focus(item)};
container.onkeydown=event=>{
if(event.altKey||event.ctrlKey||event.metaKey)return;
const item=event.target.closest('.toc-node');if(!item)return;
const visible=items(),index=visible.indexOf(item),expanded=item.getAttribute('aria-expanded');
switch(event.key){
case 'ArrowDown':focus(visible[Math.min(index+1,visible.length-1)]);break;
case 'ArrowUp':focus(visible[Math.max(0,index-1)]);break;
case 'Home':focus(visible[0]);break;
case 'End':focus(visible.at(-1));break;
case 'ArrowRight':if(expanded==='false')expand(item,true);else if(expanded==='true')focus(item.querySelector('[role="group"]>.toc-node'));break;
case 'ArrowLeft':if(expanded==='true')expand(item,false);else focus(item.parentElement.closest('.toc-node'));break;
case 'Enter':case ' ':focus(item);break;
default:return;
}
event.preventDefault();event.stopPropagation();
};
};
