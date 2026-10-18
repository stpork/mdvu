// Visit every diagram without zooming; a cached string is not a visible SVG.
(async()=>{
  const nextFrame=()=>new Promise(resolve=>requestAnimationFrame(resolve));
  const article=document.querySelector('article');
  const scroller=document.getElementById('mdvu-main-content')||document.scrollingElement;
  const cases=[];
  const viewport=()=>scroller===document.scrollingElement?{top:0,bottom:innerHeight}:scroller.getBoundingClientRect();
  const rect=node=>{const r=node?.getBoundingClientRect();return r?{top:r.top,bottom:r.bottom,width:r.width,height:r.height}:null};
  const visible=node=>{const r=rect(node),v=viewport();return !!r&&r.width>0&&r.height>0&&r.bottom>v.top&&r.top<v.bottom};
  const svg=node=>node.querySelector('.diagram-content')?.shadowRoot?.querySelector('svg')||node.querySelector('svg');
  const normalize=s=>(s||'').replace(/\r\n/g,'\n').trim();
  try {
    window.__mdvuInitArticle?.();
    const headings=[...article.querySelectorAll('h1,h2,h3,h4,h5,h6')];
    const figures=[...article.querySelectorAll('figure.diagram')];
    for(const [pass,nodes] of [figures,[...figures].reverse()].entries())for(const node of nodes) {
      const source=node.querySelector('pre')?.textContent;
      if(source&&(window.__mdvuExpectedDiagramErrors||[]).some(error=>normalize(error.source)===normalize(source)))continue;
      const heading=headings.filter(h=>h.compareDocumentPosition(node)&Node.DOCUMENT_POSITION_FOLLOWING).at(-1);
      const begin=performance.now();
      for(let parent=node.parentElement;parent&&parent!==article;parent=parent.parentElement)if(parent.tagName==='DETAILS')parent.open=true;
      node.scrollIntoView({block:'center',behavior:'instant'});
      await nextFrame();await nextFrame();
      const initial=rect(node);
      let corrections=0;
      while(performance.now()-begin<30000&&!node.classList.contains('diagram-error')&&!(visible(node)&&visible(svg(node)))){
        // Deferred text/math layout can move the target after scrollIntoView.
        // Bring the actual figure onscreen before judging whether it is blank.
        if(!visible(node)||svg(node)&&!visible(svg(node))){node.scrollIntoView({block:'center',behavior:'instant'});corrections++}
        await nextFrame();
      }
      cases.push({pass,heading:heading?.textContent,id:heading?.id,ms:performance.now()-begin,
        visible:visible(node)&&visible(svg(node)),initial,figure:rect(node),svg:rect(svg(node)),corrections,
        viewport:{top:viewport().top,bottom:viewport().bottom},scrollTop:scroller.scrollTop,classes:node.className,
        cached:!!window.__mdvuHasDiagramSVG?.(node),hostStyle:node.querySelector('.diagram-content')?.getAttribute('style')});
      if(cases.filter(c=>!c.visible).length===3)break;
    }
    const farMounted=()=>figures.filter(node=>{if(!svg(node))return false;const r=rect(node),v=viewport();return r.bottom<v.top-2000||r.top>v.bottom+2000});
    for(let n=0;n<60&&farMounted().length;n++)await nextFrame();
    const checks={diagramsVisibleBeforeZoom:cases.length>0&&cases.every(c=>c.visible),offscreenDiagramsReleased:farMounted().length===0};
    const result={checks,cases,mounted:figures.filter(node=>!!svg(node)).length,farMounted:farMounted().length,passed:Object.values(checks).every(Boolean),visibility:document.visibilityState};
    window.ipc?.postMessage('ui_test:'+JSON.stringify(result));
    window.webkit?.messageHandlers?.uiTest?.postMessage(result);
  } catch(error) {
    const result={passed:false,error:String(error),cases};
    window.ipc?.postMessage('ui_test:'+JSON.stringify(result));
    window.webkit?.messageHandlers?.uiTest?.postMessage(result);
  }
})();
