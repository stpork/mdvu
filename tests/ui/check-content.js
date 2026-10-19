// Content-only audit. No zoom, scrolling benchmark, panel changes or fullscreen transitions.
(async () => {
  const start = performance.now();
  const frame = () => new Promise(resolve => requestAnimationFrame(resolve));
  const deadline = (promise, ms) => new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Content render deadline exceeded')), ms);
    Promise.resolve(promise).then(value => { clearTimeout(timer); resolve(value); }, error => { clearTimeout(timer); reject(error); });
  });
  const send = result => {
    window.__mdvuAuditResult = result;
    window.ipc?.postMessage('ui_test:' + JSON.stringify(result));
    window.webkit?.messageHandlers?.uiTest?.postMessage(result);
  };
  try {
    const article = document.querySelector('article');
    if (!article) throw new Error('Article missing');
    const originalSources = new Map([...article.querySelectorAll('figure.diagram')].map(node=>[node,node.querySelector('pre')?.textContent || '']));
    await frame(); await frame();
    const firstFramesMs = performance.now() - start;
    if (article.querySelector('.math-inline,.math-display')) {
      await deadline((async () => { while (!window.katex) await new Promise(resolve => setTimeout(resolve, 20)); })(), 20000);
      window.__mdvuRenderMath?.();
    }
    await deadline(window.__mdvuRenderDiagrams({all:true}), 90000);
    await frame(); await frame();
    const diagramsReadyMs = performance.now() - start;
    const figures = [...article.querySelectorAll('figure.diagram')];
    const details = [];
    for (const figure of figures) {
      // Mount virtualized SVGs only to inspect their actual output, not to measure scroll speed.
      figure.scrollIntoView({block:'start', behavior:'instant'});
      await frame(); await frame();
      for (let retry=0; retry<10 && !figure.classList.contains('diagram-error') && !figure.querySelector('.diagram-content')?.shadowRoot?.querySelector('svg'); retry++) await frame();
      const svg = figure.querySelector('.diagram-content')?.shadowRoot?.querySelector('svg') || figure.querySelector('svg');
      const text = (svg ? [...svg.querySelectorAll('text,title,desc')].map(n=>n.textContent).join('\n') : figure.textContent || '').trim();
      const errorKind = window.__mdvuDiagramOutputError(figure.dataset.renderer,text);
      const error = figure.classList.contains('diagram-error') || errorKind;
      details.push({renderer:figure.dataset.renderer, cacheKey:figure.dataset.cacheKey, source:originalSources.get(figure)||figure.querySelector('pre')?.textContent||'', status:error?'error':svg?'rendered':window.__mdvuHasDiagramSVG?.(figure)?'cached':'unresolved', errorKind:errorKind||undefined, error:error?text.slice(-1500):undefined});
    }
    const cases = [...article.querySelectorAll('h2')].filter(h=>/\bD\d{3}\b/.test(h.textContent)).map(heading => {
      const block = heading.nextElementSibling;
      const index = figures.indexOf(block);
      return {id:heading.textContent.match(/\bD\d{3}\b/)[0], heading:heading.textContent.trim(), ...(index>=0?details[index]:{status:block?.matches('pre')?'source':'unresolved'})};
    });
    window.scrollTo({top:0,behavior:'instant'}); await frame(); await frame();
    const expectedIds = window.__mdvuExpectedContentCases || [];
    const actualIds = cases.map(c=>c.id);
    const catalogueComplete = actualIds.length===expectedIds.length && new Set(actualIds).size===actualIds.length && expectedIds.every(id=>actualIds.includes(id));
    const supported = item=>item && ['rendered','cached'].includes(item.status);
    const requiredCasesRendered = (window.__mdvuExpectedRenderedContentCases||[]).every(id=>supported(cases.find(c=>c.id===id)));
    const requiredDiagramsRendered = !window.__mdvuRequireAllDiagrams || details.every(supported);
    send({passed:catalogueComplete&&requiredCasesRendered&&requiredDiagramsRendered&&details.every(d=>d.status!=='unresolved')&&cases.every(c=>c.status!=='unresolved'), profile:'content-only', catalogueComplete, requiredCasesRendered, requiredDiagramsRendered,
      timingNote:'Times begin in the documentReady audit callback. They are not process startup, file-open latency or physical first paint. Inspection scroll is excluded from diagramsReadyMs.',
      firstFramesMs, diagramsReadyMs, auditMs:performance.now()-start, viewport:{width:innerWidth,height:innerHeight},
      diagrams:details, cases, headings:article.querySelectorAll('h1,h2,h3,h4,h5,h6').length,
      math:{expressions:article.querySelectorAll('.math-inline,.math-display').length,errors:article.querySelectorAll('.katex-error').length},
      images:[...article.querySelectorAll('img')].map(img=>({src:img.getAttribute('src'),loaded:img.complete&&img.naturalWidth>0})),
      renderTimings:window.__mdvuDiagramTimings||[]});
  } catch(error) { send({passed:false, profile:'content-only', error:String(error), auditMs:performance.now()-start}); }
})();
