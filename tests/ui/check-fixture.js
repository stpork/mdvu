// Executed by the native test harness after the article is installed.
(async () => {
  if (window.__mdvuAuditRunning) return;
  window.__mdvuAuditRunning = true;
  const fullControls=window.__mdvuFullControlAudit!==false;
  const start = performance.now(), checks = {}, pause = ms => new Promise(r => setTimeout(r, ms));
  const checkpoint=stage=>window.webkit?.messageHandlers?.uiControl?.postMessage({checkpoint:stage});
  window.__mdvuAuditCheckpoint=checkpoint;
  checkpoint('start '+navigator.userAgent+' contentVisibility='+CSS.supports('content-visibility','auto'));
  const renderTimings=[], frameGaps=[];
  try {
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    window.__mdvuInitArticle?.();
    const article = document.querySelector('article');
    const tocPane = document.getElementById('mdvu-toc-sidebar');
    if (tocPane && !tocPane.classList.contains('hidden')) checks.tocInitialWidth = Math.abs(tocPane.getBoundingClientRect().width - Math.max(220,Math.min(260,Math.floor(innerWidth*.48)))) < 2;
    const roots=()=>[article,...[...article.querySelectorAll('figure.diagram')].map(n=>n.querySelector('.diagram-content')?.shadowRoot).filter(Boolean)];
    const diagramCount=()=>[...article.querySelectorAll('figure.diagram')].filter(n=>window.__mdvuHasDiagramSVG?.(n)).length;
    checks.article = !!article && article.textContent.trim().length > 0;
    if (document.getElementById('mdvu-one-screen')) {
      const board=document.querySelector('.board');
      checks.customStylesheet = getComputedStyle(board).display === 'grid';
      const style=getComputedStyle(article);
      checks.showcaseInsets=parseFloat(style.paddingTop)===12&&parseFloat(style.paddingRight)===12;
      const previousWidth=article.style.width;
      try {
        checks.showcaseResponsiveLayout=[[680,1],[1040,2],[2440,4]].every(([width,columns])=>{
          article.style.width=width+'px';
          const contentWidth=article.clientWidth-24;
          const fontSize=contentWidth<1300?14:Math.max(11,Math.min(contentWidth*.00745,64));
          return getComputedStyle(board).gridTemplateColumns.split(' ').length===columns&&Math.abs(parseFloat(getComputedStyle(board).fontSize)-fontSize)<.1;
        });
      } finally { article.style.width=previousWidth }
    }
    const needs = renderer => !!document.querySelector(`.diagram-pending[data-renderer="${renderer}"]`);
    const math = !!document.querySelector('.math-inline,.math-display');
    for (let n = 0; n < 400; n++) {
      if ((!math || window.katex) && (!needs('mermaid') || window.__mdvuNativeDiagramTransport || window.mermaid) && (!needs('plantuml') || window.__mdvuNativeDiagramTransport || window.PlantUML?.renderToString)) break;
      await pause(50);
    }
    window.__mdvuRenderMath?.();
    if(window.mermaid){const render=window.mermaid.render;window.mermaid.render=async function(...args){const t=performance.now();try{return await render.apply(this,args)}finally{renderTimings.push({type:args[1].split("\n")[0],ms:performance.now()-t})}}}
    let lastFrame=performance.now(), monitor=true;
    const trackFrame=now=>{if(!monitor)return;frameGaps.push(now-lastFrame);lastFrame=now;requestAnimationFrame(trackFrame)};
    requestAnimationFrame(trackFrame);
    const coldScroll=[],coldZoom=[],coldTargets=[...article.querySelectorAll('figure.diagram')];let rendering=true;
    const nextFrame=()=>new Promise(r=>requestAnimationFrame(r));
    const scrollerDuringLoad=document.getElementById('mdvu-main-content')||document.scrollingElement;
    const exercise=async()=>{
      do {
        window.dispatchEvent(new WheelEvent('wheel',{deltaY:70}));
        let t=performance.now();
        if(coldScroll.length%4===0)coldTargets[(coldScroll.length*17)%Math.max(1,coldTargets.length)]?.scrollIntoView({block:'center',behavior:'instant'});
        scrollerDuringLoad.scrollBy({top:70,behavior:'instant'});await nextFrame();coldScroll.push(performance.now()-t);
        const input=document.getElementById('mdvu-zoom-val');
        const zoomIn=document.getElementById('btn-zoom-in'),zoomOut=document.getElementById('btn-zoom-out');
        t=performance.now();
        if(zoomIn)zoomIn.click();else window.webkit?.messageHandlers?.uiControl?.postMessage('zoomIn');
        for(let n=0;n<100&&(input?input.value!=='110%':window.__mdvuAuditZoom!==1.1);n++)await nextFrame();
        await nextFrame();coldZoom.push(performance.now()-t);
        checks.coldZoomIn=checks.coldZoomIn!==false&&(input?input.value==='110%':window.__mdvuAuditZoom===1.1);
        t=performance.now();
        if(zoomOut)zoomOut.click();else window.webkit?.messageHandlers?.uiControl?.postMessage('zoomOut');
        for(let n=0;n<100&&(input?input.value!=='100%':window.__mdvuAuditZoom!==1);n++)await nextFrame();
        await nextFrame();coldZoom.push(performance.now()-t);
        checks.coldZoomOut=checks.coldZoomOut!==false&&(input?input.value==='100%':window.__mdvuAuditZoom===1);
        await pause(120);
      } while(rendering);
    };
    // CI's timer mode checks document/control correctness. The default mode
    // additionally stresses native zoom and scrolling throughout cold rendering.
    const interactions=window.__mdvuTimingMode==='timer'||!fullControls?Promise.resolve():exercise();
    checkpoint('render-all');
    let timer;
    try {
      await Promise.race([window.__mdvuRenderDiagrams?.({all:true}),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('Diagram rendering exceeded 90 seconds')),90000)})]);
    } finally { clearTimeout(timer);rendering=false;await interactions }
    for (let n = 0; n < 1200 && document.querySelector('.diagram-pending:not(.diagram-error)'); n++) await pause(50);
    checks.runtimes = !document.querySelector('.diagram-pending:not(.diagram-error),.math-inline:not(.math-rendered):not(.katex-error),.math-display:not(.math-rendered):not(.katex-error)');
    checkpoint('rendered');
    const renderFinishedMs = performance.now();
    monitor=false;
    const frames=[...frameGaps].sort((a,b)=>a-b);
    if(window.__mdvuNativeDiagramTransport){renderTimings.push(...window.__mdvuDiagramTimings);checks.enginesOutsideReader=!window.mermaid&&!window.PlantUML}

    const scroller=document.getElementById('mdvu-main-content')||document.scrollingElement;
    const edge=async key=>{const begin=performance.now(),previous=window.__mdvuReadingEdgeSettled;window.dispatchEvent(new KeyboardEvent('keydown',{key,bubbles:true,cancelable:true}));if(key==='End')for(let n=0;n<10&&window.__mdvuReadingEdgeSettled===previous;n++)await new Promise(r=>requestAnimationFrame(r));else await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));return performance.now()-begin};
    checkpoint('reading-edges');
    const endMs=await edge('End');
    checks.end=scroller.scrollHeight-scroller.clientHeight-scroller.scrollTop<3;
    const homeMs=await edge('Home');
    checks.home=scroller.scrollTop<3;
    const scrollFrames=[],warmPasses=[],passes=window.__mdvuWarmPasses||1;let previous=performance.now();
    const scrollable=scroller.scrollHeight>scroller.clientHeight+3;
    for(let pass=0;scrollable&&pass<passes;pass++){
      if(pass){scroller.scrollTo({top:0,behavior:'instant'});await nextFrame();await nextFrame();previous=performance.now()}
      const gaps=pass?[]:scrollFrames;
      for(let n=0;n<30;n++){scroller.scrollBy({top:120,behavior:'instant'});await nextFrame();const now=performance.now();gaps.push(now-previous);previous=now}
      if(passes>1)warmPasses.push(gaps);
    }
    scroller.scrollTo({top:0,behavior:'instant'});
    const mountedDiagrams=[...article.querySelectorAll('figure.diagram')].filter(n=>n.querySelector('.diagram-content')?.shadowRoot?.querySelector('svg')).length;
    const performanceMetrics={mountedDiagrams,coldInteractionCount:coldScroll.length,coldScrollMaxMs:fullControls?Math.max(...coldScroll,0):null,coldZoomMaxMs:fullControls?Math.max(...coldZoom,0):null,homeMs,endMs,renderFrameSamples:frames.length,renderFrameP95Ms:frames.length>=20?frames[Math.floor(frames.length*.95)]:null,renderFrameMaxMs:frames.at(-1)||0,scrollFrameP95Ms:scrollable?[...scrollFrames].sort((a,b)=>a-b)[Math.floor(scrollFrames.length*.95)]:null,scrollWarmPasses:passes>1?warmPasses:undefined};
    if(fullControls&&window.__mdvuTimingMode!=='timer')checks.coldResponsive=performanceMetrics.renderFrameMaxMs<500&&performanceMetrics.coldScrollMaxMs<250&&performanceMetrics.coldZoomMaxMs<500;
    const firstDiagram=article.querySelector('figure.diagram-rendered');
    if(firstDiagram&&window.__mdvuTimingMode!=='timer'){
      firstDiagram.scrollIntoView({block:'center',behavior:'instant'});
      const surface=()=>firstDiagram.querySelector('.diagram-content')?.shadowRoot?.querySelector('svg');
      const onscreen=()=>{const r=firstDiagram.getBoundingClientRect(),v=scroller===document.scrollingElement?{top:0,bottom:innerHeight}:scroller.getBoundingClientRect();return r.bottom>v.top&&r.top<v.bottom};
      for(let n=0;n<60&&(!surface()||!onscreen());n++){
        if(!onscreen())firstDiagram.scrollIntoView({block:'center',behavior:'instant'});
        await nextFrame();
      }
      const picture=surface();
      checks.visibleDiagram=onscreen()&&!!picture&&picture.getBoundingClientRect().width>0&&picture.getBoundingClientRect().height>0;
    }
    const headings = [...article.querySelectorAll('h1,h2,h3,h4,h5,h6')];
    const tocTree=document.getElementById('mdvu-toc-tree');
    if(tocTree){
      checks.tocHierarchy=tocTree.querySelectorAll('[role="treeitem"]').length===headings.length;
      const branch=tocTree.querySelector('[aria-expanded="true"]');
      if(branch){
        branch.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowLeft',bubbles:true,cancelable:true}));
        checks.tocCollapse=branch.getAttribute('aria-expanded')==='false';
        branch.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowRight',bubbles:true,cancelable:true}));
        checks.tocExpand=branch.getAttribute('aria-expanded')==='true';
      }
      checks.tocTabStop=tocTree.querySelectorAll('[tabindex="0"]').length===(headings.length?1:0);
    }
    const ids = headings.map(h => h.id);
    checks.uniqueHeadingTargets = ids.every(Boolean) && new Set(ids).size === ids.length;
    checks.fragment = !headings.length || window.__mdvuScrollToFragment?.(headings.at(-1).id, false) === true;
    if(headings.length&&checks.fragment){
      const begin=performance.now(),target=headings.at(-1);let stable=0;
      for(let n=0;n<120&&stable<2;n++){await nextFrame();const rect=scroller===document.scrollingElement?{top:0,height:innerHeight}:scroller.getBoundingClientRect(),top=target.getBoundingClientRect().top-rect.top;const bottom=scroller.scrollHeight-scroller.clientHeight-scroller.scrollTop<3;stable=(Math.abs(top)<3||bottom&&top>=-3&&top<rect.height)?stable+1:0}
      checks.fragmentPosition=stable>=2;performanceMetrics.fragmentMs=performance.now()-begin;
    }
    checkpoint('search');
    const word = (article.textContent.match(/[A-Za-z\p{L}\p{N}]{3,20}/u) || [])[0];
    if (word) {
      const found = window.__mdvuFind.search(word);
      checks.find = found.count > 0 && roots().reduce((count,root)=>count+root.querySelectorAll('.find-match').length,0) === found.count;
      const next = window.__mdvuFind.next(), previous = window.__mdvuFind.previous();
      checks.findNavigation = next.count === found.count && previous.current === 1;
      window.__mdvuFind.clear();
      checks.findClear = roots().every(root=>!root.querySelector('.find-match'));
    }
    if (fullControls && document.getElementById('btn-zoom-in')) {
      const zoom = document.getElementById('mdvu-zoom-val');
      let zoomStart=performance.now();
      document.getElementById('btn-zoom-in').click();
      for(let n=0;n<100&&zoom.value!=='110%';n++)await pause(5);
      await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
      performanceMetrics.zoomInMs=performance.now()-zoomStart;
      checks.zoomIn = zoom.value === '110%';
      zoomStart=performance.now();
      document.getElementById('btn-zoom-out').click();
      for(let n=0;n<100&&zoom.value!=='100%';n++)await pause(5);
      await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
      performanceMetrics.zoomOutMs=performance.now()-zoomStart;
      checks.zoomOut = zoom.value === '100%';
      for(let n=0;n<10;n++)window.dispatchEvent(new WheelEvent('wheel',{ctrlKey:true,deltaY:-1}));
      for(let n=0;n<100&&zoom.value!=='110%';n++)await pause(5);
      await pause(50);checks.wheelZoomCoalesced=zoom.value==='110%';
      document.getElementById('btn-zoom-out').click();await pause(100);
      const toc = document.getElementById('mdvu-toc-sidebar'), hidden = toc.classList.contains('hidden');
      document.getElementById('btn-toc').click(); await pause(150);
      checks.tocToggle = toc.classList.contains('hidden') !== hidden;
      document.getElementById('btn-toc').click(); await pause(150);
      const contentsKey=new KeyboardEvent('keydown',{key:'b',ctrlKey:true,bubbles:true,cancelable:true});
      window.dispatchEvent(contentsKey);await pause(150);
      checks.contentsShortcut=contentsKey.defaultPrevented&&toc.classList.contains('hidden')!==hidden;
      window.dispatchEvent(new KeyboardEvent('keydown',{key:'b',ctrlKey:true,bubbles:true,cancelable:true}));await pause(150);
      const windowsKey=new KeyboardEvent('keydown',{key:'b',metaKey:true,bubbles:true,cancelable:true});
      const saveAs=new KeyboardEvent('keydown',{key:'S',ctrlKey:true,shiftKey:true,bubbles:true,cancelable:true});
      window.dispatchEvent(windowsKey);window.dispatchEvent(saveAs);await pause(150);
      checks.reservedShortcuts=!windowsKey.defaultPrevented&&!saveAs.defaultPrevented&&toc.classList.contains('hidden')===hidden;
      const full = document.documentElement.classList.contains('full-width');
      document.getElementById('btn-full-width').click(); await pause(150);
      checks.fullWidth = document.documentElement.classList.contains('full-width') !== full;
      document.getElementById('btn-full-width').click(); await pause(150);
    }
    checkpoint('controls');
    if(fullControls)await window.__mdvuCheckControls({checks,metrics:performanceMetrics,article,nextFrame,pause,fullscreen:window.__mdvuTimingMode!=='timer'});
    checkpoint('controls-finished');
    await pause(400);
    // Keep the window at its initial reading position for the captured screenshot.
    document.getElementById('mdvu-main-content')?.scrollTo(0,0); window.scrollTo(0,0);
    const diagramErrors=[...article.querySelectorAll('.diagram-error')].map(n=>({message:n.querySelector('small')?.textContent,source:n.querySelector('pre')?.textContent}));
    const expected=window.__mdvuExpectedDiagramErrors||[];
    const normalize=s=>(s||'').replace(/\r\n/g,'\n').trim();
    checks.diagramErrors=diagramErrors.length===expected.length&&diagramErrors.every(e=>expected.some(known=>normalize(known.source)===normalize(e.source)&&(!known.message||known.message===e.message)));
    checks.diagrams=[...article.querySelectorAll('figure.diagram')].every(n=>n.classList.contains('diagram-error')||window.__mdvuHasDiagramSVG?.(n));
    if(window.__mdvuAuditIdleProbe)await pause(5500);
    const timerOnly=window.__mdvuTimingMode==='timer';
    const result = {checks, controlScope:fullControls?'full':'render', scrollable, timingMode:timerOnly?'timer-correctness-only':'animation-frame', idleProbe:!!window.__mdvuAuditIdleProbe, performance:timerOnly?null:performanceMetrics, diagnosticTimers:timerOnly?performanceMetrics:undefined, visibility:document.visibilityState, renderTimings, passed:Object.values(checks).every(Boolean), renderFinishedMs, auditMs:performance.now()-start,
      diagrams:diagramCount(),
      diagramErrors,
      mathErrors:article.querySelectorAll('.katex-error').length,
      images:[...article.querySelectorAll('img')].map(i=>({src:i.getAttribute('src'),loaded:i.complete&&i.naturalWidth>0})),
      textLength:article.textContent.length, headings:headings.length};
    window.__mdvuAuditResult = result;
    window.ipc?.postMessage('ui_test:' + JSON.stringify(result));
    window.webkit?.messageHandlers?.uiTest?.postMessage(result);
  } catch (error) {
    window.__mdvuAuditResult = {passed:false,error:String(error),checks,renderTimings,frameGaps,controls:window.__mdvuAuditControls,pending:[...document.querySelectorAll('.diagram-pending:not(.diagram-error)')].map(n=>({renderer:n.dataset.renderer,rendering:!!n.__mdvuRendering,source:n.textContent.slice(0,300)})),diagrams:[...document.querySelectorAll('figure.diagram')].filter(n=>n.querySelector('.diagram-content')?.shadowRoot?.querySelector('svg')||n.querySelector('svg')).length};
    window.ipc?.postMessage('ui_test:' + JSON.stringify(window.__mdvuAuditResult));
    window.webkit?.messageHandlers?.uiTest?.postMessage(window.__mdvuAuditResult);
  }
})();
