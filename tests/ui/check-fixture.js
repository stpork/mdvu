// Executed by the native test harness after the article is installed.
(async () => {
  if (window.__mdvuAuditRunning) return;
  window.__mdvuAuditRunning = true;
  const start = performance.now(), checks = {}, pause = ms => new Promise(r => setTimeout(r, ms));
  const renderTimings=[], frameGaps=[];
  try {
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    const article = document.querySelector('article');
    const roots=()=>[article,...[...article.querySelectorAll('figure.diagram')].map(n=>n.querySelector('.diagram-content')?.shadowRoot).filter(Boolean)];
    const diagramCount=()=>roots().reduce((count,root)=>count+root.querySelectorAll('svg').length,0);
    checks.article = !!article && article.textContent.trim().length > 0;
    if (document.getElementById('mdvu-one-screen')) checks.customStylesheet = getComputedStyle(document.querySelector('.board')).display === 'grid';
    const needs = renderer => !!document.querySelector(`.diagram-pending[data-renderer="${renderer}"]`);
    const math = !!document.querySelector('.math-inline,.math-display');
    for (let n = 0; n < 400; n++) {
      if ((!math || window.katex) && (!needs('mermaid') || window.mermaid) && (!needs('plantuml') || window.PlantUML?.renderToString)) break;
      await pause(50);
    }
    window.__mdvuRenderMath?.();
    if(window.mermaid){const render=window.mermaid.render;window.mermaid.render=async function(...args){const t=performance.now();try{return await render.apply(this,args)}finally{renderTimings.push({type:args[1].split("\n")[0],ms:performance.now()-t})}}}
    let lastFrame=performance.now(), monitor=true;
    const trackFrame=now=>{if(!monitor)return;frameGaps.push(now-lastFrame);lastFrame=now;requestAnimationFrame(trackFrame)};
    requestAnimationFrame(trackFrame);
    let timer;
    try {
      await Promise.race([window.__mdvuRenderDiagrams?.({all:true}),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('Diagram rendering exceeded 90 seconds')),90000)})]);
    } finally { clearTimeout(timer) }
    for (let n = 0; n < 1200 && document.querySelector('.diagram-pending:not(.diagram-error)'); n++) await pause(50);
    checks.runtimes = !document.querySelector('.diagram-pending:not(.diagram-error),.math-inline:not(.math-rendered):not(.katex-error),.math-display:not(.math-rendered):not(.katex-error)');
    const renderFinishedMs = performance.now();
    monitor=false;
    const frames=[...frameGaps].sort((a,b)=>a-b);
    const scroller=document.getElementById('mdvu-main-content')||document.scrollingElement;
    const edge=async key=>{const begin=performance.now();window.dispatchEvent(new KeyboardEvent('keydown',{key,bubbles:true,cancelable:true}));await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));return performance.now()-begin};
    const endMs=await edge('End');
    checks.end=scroller.scrollHeight-scroller.clientHeight-scroller.scrollTop<3;
    const homeMs=await edge('Home');
    checks.home=scroller.scrollTop<3;
    const scrollFrames=[];let previous=performance.now();
    for(let n=0;n<30;n++){scroller.scrollBy({top:120,behavior:'instant'});await new Promise(r=>requestAnimationFrame(r));const now=performance.now();scrollFrames.push(now-previous);previous=now}
    scroller.scrollTo({top:0,behavior:'instant'});
    const performanceMetrics={homeMs,endMs,renderFrameP95Ms:frames[Math.floor(frames.length*.95)]||0,renderFrameMaxMs:frames.at(-1)||0,scrollFrameP95Ms:[...scrollFrames].sort((a,b)=>a-b)[Math.floor(scrollFrames.length*.95)]};
    const headings = [...article.querySelectorAll('h1,h2,h3,h4,h5,h6')];
    const ids = headings.map(h => h.id);
    checks.uniqueHeadingTargets = ids.every(Boolean) && new Set(ids).size === ids.length;
    checks.fragment = !headings.length || window.__mdvuScrollToFragment?.(headings.at(-1).id, false) === true;
    const word = (article.textContent.match(/[A-Za-z\p{L}\p{N}]{3,20}/u) || [])[0];
    if (word) {
      const found = window.__mdvuFind.search(word);
      checks.find = found.count > 0 && roots().reduce((count,root)=>count+root.querySelectorAll('.find-match').length,0) === found.count;
      const next = window.__mdvuFind.next(), previous = window.__mdvuFind.previous();
      checks.findNavigation = next.count === found.count && previous.current === 1;
      window.__mdvuFind.clear();
      checks.findClear = roots().every(root=>!root.querySelector('.find-match'));
    }
    if (document.getElementById('btn-zoom-in')) {
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
      const full = document.documentElement.classList.contains('full-width');
      document.getElementById('btn-full-width').click(); await pause(150);
      checks.fullWidth = document.documentElement.classList.contains('full-width') !== full;
      document.getElementById('btn-full-width').click(); await pause(150);
    }
    await pause(400);
    // Keep the window at its initial reading position for the captured screenshot.
    document.getElementById('mdvu-main-content')?.scrollTo(0,0); window.scrollTo(0,0);
    const diagramErrors=[...article.querySelectorAll('.diagram-error')].map(n=>({message:n.querySelector('small')?.textContent,source:n.querySelector('pre')?.textContent}));
    const expected=window.__mdvuExpectedDiagramErrors||[];
    const normalize=s=>(s||'').replace(/\r\n/g,'\n').trim();
    checks.diagramErrors=diagramErrors.length===expected.length&&diagramErrors.every(e=>expected.some(known=>normalize(known.source)===normalize(e.source)));
    checks.diagrams=[...article.querySelectorAll('figure.diagram')].every(n=>n.classList.contains('diagram-error')||n.querySelector('.diagram-content')?.shadowRoot?.querySelector('svg'));
    const result = {checks, performance:performanceMetrics, visibility:document.visibilityState, renderTimings, passed:Object.values(checks).every(Boolean), renderFinishedMs, auditMs:performance.now()-start,
      diagrams:diagramCount(),
      diagramErrors,
      mathErrors:article.querySelectorAll('.katex-error').length,
      images:[...article.querySelectorAll('img')].map(i=>({src:i.getAttribute('src'),loaded:i.complete&&i.naturalWidth>0})),
      textLength:article.textContent.length, headings:headings.length};
    window.__mdvuAuditResult = result;
    window.ipc?.postMessage('ui_test:' + JSON.stringify(result));
    window.webkit?.messageHandlers?.uiTest?.postMessage(result);
  } catch (error) {
    window.__mdvuAuditResult = {passed:false,error:String(error),checks,renderTimings,frameGaps,pending:[...document.querySelectorAll('.diagram-pending:not(.diagram-error)')].map(n=>({renderer:n.dataset.renderer,rendering:!!n.__mdvuRendering,source:n.textContent.slice(0,300)})),diagrams:[...document.querySelectorAll('figure.diagram')].filter(n=>n.querySelector('.diagram-content')?.shadowRoot?.querySelector('svg')||n.querySelector('svg')).length};
    window.ipc?.postMessage('ui_test:' + JSON.stringify(window.__mdvuAuditResult));
    window.webkit?.messageHandlers?.uiTest?.postMessage(window.__mdvuAuditResult);
  }
})();
