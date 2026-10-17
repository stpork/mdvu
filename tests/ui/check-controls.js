// Shared native-control scenarios. Included only by the two UI test runners.
window.__mdvuCheckControls = async ({checks, metrics, article, nextFrame, pause, fullscreen = true}) => {
  const windows = !!document.getElementById('btn-zoom-in'), samples = [];
  metrics.controls=samples;window.__mdvuAuditControls=samples;
  const changes={mounts:0,unmounts:0};
  const observer=new MutationObserver(entries=>{for(const e of entries){if(e.addedNodes.length)changes.mounts++;if(e.removedNodes.length)changes.unmounts++}});
  for(const host of article.querySelectorAll('.diagram-content'))if(host.shadowRoot)observer.observe(host.shadowRoot,{childList:true});
  let sequence = 0;
  const native = async (action, value) => {
    const id = ++sequence;
    window.webkit.messageHandlers.uiControl.postMessage({id, action, value});
    for (let n=0;n<300 && window.__mdvuAuditNative?.id!==id;n++) await nextFrame();
    if (window.__mdvuAuditNative?.id!==id) throw Error('Native control timeout: '+action);
    return window.__mdvuAuditNative;
  };
  const state = async () => {
    if (!windows) return native('state');
    const branch=document.querySelector('#mdvu-toc-tree [aria-expanded]');
    const folder=document.querySelector('#mdvu-nav-tree .nav-folder-header');
    return {zoom:parseFloat(document.getElementById('mdvu-zoom-val').value)/100,
      toc:!document.getElementById('mdvu-toc-sidebar').classList.contains('hidden'),
      navigator:!document.getElementById('mdvu-navigator-sidebar').classList.contains('hidden'),
      fullWidth:document.documentElement.classList.contains('full-width'),fullscreen:!!window.__mdvuAuditFullscreen,
      tocRows:[...document.querySelectorAll('#mdvu-toc-tree [role=treeitem]')].filter(n=>!n.closest('[hidden]')).length,
      tocBranch:branch?branch.getAttribute('aria-expanded')==='true':null,
      nav:{mode:window.__mdvuNavMode,rows:document.querySelectorAll('#mdvu-nav-tree .nav-file').length,
        branch:folder?folder.nextElementSibling.style.display!=='none':null}};
  };
  const act = async (action,value,expected) => {
    const begin=performance.now(),beforeChanges={...changes};
    if (!windows) await native(action,value);
    else {
      const buttons={zoomIn:'btn-zoom-in',zoomOut:'btn-zoom-out',toc:'btn-toc',navigator:'btn-navigator',fullWidth:'btn-full-width',navTree:'btn-nav-mode-tree',navList:'btn-nav-mode-list'};
      if (buttons[action]) document.getElementById(buttons[action]).click();
      else if(action==='zoomSet') {const field=document.getElementById('mdvu-zoom-val');field.value=value;field.dispatchEvent(new Event('change'))}
      else if(action==='zoomReset') document.getElementById('mdvu-zoom-val').dispatchEvent(new MouseEvent('dblclick'));
      else if(action==='fullscreen') window.ipc.postMessage('toggle_fullscreen');
      else if(action.startsWith('toc')) {
        const branch=document.querySelector('#mdvu-toc-tree [aria-expanded]');
        if(branch && (branch.getAttribute('aria-expanded')==='true')!==(action==='tocExpand')) branch.querySelector('.toc-expander').click();
      } else if(action.startsWith('nav')) {
        const folder=document.querySelector('#mdvu-nav-tree .nav-folder-header');
        if(folder && (folder.nextElementSibling.style.display!=='none')!==(action==='navExpand')) folder.click();
      }
    }
    let current,zoomApplied;
    for(let n=0;n<300;n++) {
      current=await state();
      zoomApplied=windows || expected?.zoom===undefined || Math.abs((window.__mdvuAuditZoom||0)-expected.zoom)<.001;
      if(zoomApplied && (!expected || Object.entries(expected).every(([key,value])=>typeof value==='number'?Math.abs(current[key]-value)<.001:current[key]===value))) break;
      await nextFrame();
    }
    if(!zoomApplied || expected && !Object.entries(expected).every(([key,value])=>typeof value==='number'?Math.abs(current[key]-value)<.001:current[key]===value)) throw Error(action+' state mismatch: '+JSON.stringify({expected,current}));
    await nextFrame();await nextFrame();
    const scroller=document.getElementById('mdvu-main-content')||document.scrollingElement;
    if(!Number.isFinite(scroller.scrollHeight)||scroller.clientHeight<=0||innerWidth<=0) throw Error('Invalid layout after '+action);
    samples.push({action,value,ms:performance.now()-begin,zoom:current.zoom,readerWidth:scroller.clientWidth,readerHeight:scroller.clientHeight,diagramMounts:changes.mounts-beforeChanges.mounts,diagramUnmounts:changes.unmounts-beforeChanges.unmounts});
    return current;
  };
  const initial=await state(), originalArticle=article.firstChild;
  // Every supported 10% step in both directions, including clamped endpoints.
  await act('zoomSet','10%',{zoom:.1});
  for(let percent=20;percent<=500;percent+=10) await act('zoomIn',null,{zoom:percent/100});
  await act('zoomIn',null,{zoom:5});
  for(let percent=490;percent>=10;percent-=10) await act('zoomOut',null,{zoom:percent/100});
  await act('zoomOut',null,{zoom:.1});
  await act('zoomSet','125%',{zoom:1.25});
  await act('zoomSet','not-a-percent',{zoom:1.25});
  await act('zoomSet','-100%',{zoom:.1});
  await act('zoomSet','999%',{zoom:5});
  await act('zoomReset',null,{zoom:1});
  checks.zoomFullRange=true;
  checks.zoomKeepsDocument=article.firstChild===originalArticle;

  // Verify the same visible block survives each width-changing operation.
  const capture=window.__mdvuCaptureReadingAnchor;let anchor;
  window.__mdvuCaptureReadingAnchor=()=>{
    const scroller=document.getElementById('mdvu-main-content')||document.scrollingElement;
    const rect=scroller===document.scrollingElement?{left:0,top:0,width:innerWidth,height:innerHeight}:scroller.getBoundingClientRect();
    const el=document.elementFromPoint(rect.left+rect.width/2,rect.top+rect.height/2)?.closest('p,h1,h2,h3,h4,h5,h6,li,pre,tr,blockquote,table,img,figure');
    const token=capture();anchor={el,offset:el?(el.getBoundingClientRect().top-rect.top)/rect.height:null,ratio:scroller.scrollTop/Math.max(1,scroller.scrollHeight-scroller.clientHeight),token};return token;
  };
  const pane=async (action,expected)=>{
    anchor=null;
    await act(action,null,expected);
    if(anchor) {
      for(let n=0;n<90 && window.__mdvuReadingAnchorSettled!==anchor.token;n++) await nextFrame();
      const scroller=document.getElementById('mdvu-main-content')||document.scrollingElement;
      const rect=scroller===document.scrollingElement?{top:0,height:innerHeight}:scroller.getBoundingClientRect();
      // At the document edges the scroll range may prevent exact preservation.
      const atEdge=scroller.scrollTop<2||scroller.scrollHeight-scroller.clientHeight-scroller.scrollTop<2;
      const drift=anchor.el?Math.abs((anchor.el.getBoundingClientRect().top-rect.top)/rect.height-anchor.offset):Math.abs(scroller.scrollTop/Math.max(1,scroller.scrollHeight-scroller.clientHeight)-anchor.ratio);
      checks[action+'ReadingPosition']=checks[action+'ReadingPosition']!==false&&(atEdge||drift<.04);
    }
    // Native Windows prevents duplicate toggle messages within 60 ms.
    await pause(65);
  };
  try {
    const middle=[...article.querySelectorAll('h2,p')];middle[Math.floor(middle.length/2)]?.scrollIntoView({block:'center',behavior:'instant'});
    await nextFrame();await nextFrame();
    for(const action of ['toc','navigator','fullWidth']) {
      const before=await state();await pane(action,{[action]:!before[action]});await pane(action,{[action]:before[action]});
      checks[action+'HideShow']=true;
    }
    const beforeNav=await state();if(!beforeNav.navigator) await pane('navigator',{navigator:true});
    const scanStart=performance.now();await act('navList');
    for(let n=0;n<300 && !(await state()).nav.rows;n++)await nextFrame();
    metrics.navigatorLoadMs=performance.now()-scanStart;
    checks.navigatorList=(await state()).nav.mode==='list'&&(await state()).nav.rows>0;
    await act('navTree');checks.navigatorTree=(await state()).nav.mode==='tree';
    let current=await state();
    if(current.nav.branch!==null) {
      await act('navCollapse');checks.folderCollapse=(await state()).nav.branch===false;
      await act('navExpand');checks.folderExpand=(await state()).nav.branch===true;
    }
    current=await state();
    if(current.tocBranch!==null) {
      const beforeRows=current.tocRows;await act('tocCollapse');const collapsed=await state();
      checks.tocCollapseReflow=collapsed.tocBranch===false&&collapsed.tocRows<=beforeRows;
      await act('tocExpand');const expanded=await state();
      checks.tocExpandReflow=expanded.tocBranch===true&&expanded.tocRows>collapsed.tocRows;
    }
    if(!beforeNav.navigator) await pane('navigator',{navigator:false});
    checks.navigatorKeepsDocument=article.firstChild===originalArticle;

    // Fullscreen follows the primary control and reflow scenarios.
    if(fullscreen) {
      const originalViewport={width:innerWidth,height:innerHeight};
      await act('fullscreen',null,{fullscreen:!initial.fullscreen});
      await pause(400);
      checks.fullscreenViewport=innerWidth>=originalViewport.width&&innerHeight>=originalViewport.height;
      await act('zoomIn',null,{zoom:1.1});await act('zoomReset',null,{zoom:1});
      for(const action of ['toc','navigator']) {
        const before=await state();await pane(action,{[action]:!before[action]});await pane(action,{[action]:before[action]});
      }
      const scroller=document.getElementById('mdvu-main-content')||document.scrollingElement;
      window.dispatchEvent(new KeyboardEvent('keydown',{key:'End',cancelable:true,bubbles:true}));await pause(150);
      checks.fullscreenEnd=scroller.scrollHeight-scroller.clientHeight-scroller.scrollTop<3;
      window.dispatchEvent(new KeyboardEvent('keydown',{key:'Home',cancelable:true,bubbles:true}));await nextFrame();await nextFrame();
      checks.fullscreenHome=scroller.scrollTop<3;
      await act('fullscreen',null,{fullscreen:initial.fullscreen});await pause(400);
      checks.fullscreenRestore=Math.abs(innerWidth-originalViewport.width)<3&&Math.abs(innerHeight-originalViewport.height)<3;
    }
  } finally {window.__mdvuCaptureReadingAnchor=capture;observer.disconnect()}
  metrics.controls=samples;
  metrics.controlMaxMs=Math.max(...samples.map(s=>s.ms),0);
  metrics.zoomRangeMaxMs=Math.max(...samples.filter(s=>s.action.startsWith('zoom')).map(s=>s.ms),0);
  metrics.paneMaxMs=Math.max(...samples.filter(s=>['toc','navigator','fullWidth'].includes(s.action)).map(s=>s.ms),0);
  if(window.__mdvuTimingMode!=='timer'){checks.zoomRangeResponsive=metrics.zoomRangeMaxMs<500;checks.paneResponsive=metrics.paneMaxMs<500}
};
