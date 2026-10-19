// PlantUML's browser port omits its DOT factory; reuse the already bundled Viz runtime.
export function createPlantUMLRenderer(core, viz) {
  let instance;
  const sharedViz = {...viz, instance:() => instance ||= viz.instance().catch(error => { instance = null; throw error; })};
  globalThis.PLANTUML_VIZ = sharedViz;
  return {
    ...core,
    renderToString(lines, onSuccess, onError, options = {}) {
      if (!/^\s*@startdot(?:\s|$)/i.test(lines[0] || '')) return core.renderToString(lines, onSuccess, onError, options);
      if (!/^\s*@enddot\s*$/i.test(lines.at(-1) || '')) { onError('Missing @enddot'); return; }
      const color = options.dark ? '#e0e0e0' : '#202020';
      sharedViz.instance().then(engine => engine.renderString(lines.slice(1,-1).join('\n'), {
        format:'svg', graphAttributes:{bgcolor:'transparent',color,fontcolor:color},
        nodeAttributes:{color,fontcolor:color}, edgeAttributes:{color,fontcolor:color}
      })).then(onSuccess, error => onError(String(error.message || error)));
    }
  };
}
