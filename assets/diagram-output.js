// Classify SVG diagnostics independently of whether the engine returned a success callback.
(function () {
  function diagramOutputError(renderer, text) {
    if (renderer === 'plantuml') {
      if (/Diagram not supported by this release of PlantUML/i.test(text) && /directive[\s\S]*not recognized/i.test(text)) return 'unsupported-diagram';
      if (/PlantUML version[\s\S]*\[From [\s\S]*\(line \d+\)/i.test(text)) {
        if (/cannot include/i.test(text)) return 'missing-library';
        if (/Syntax Error\?/i.test(text)) return 'syntax-error';
        return 'preprocessor-error';
      }
    }
    if (renderer === 'mermaid' && /^\s*Syntax error in text[\s\S]*mermaid version/i.test(text)) return 'syntax-error';
    return null;
  }
  globalThis.__mdvuDiagramOutputError = diagramOutputError;
  function validateDiagramSVG(renderer, svg) {
    if (!/Diagram not supported by this release|PlantUML version|Syntax error in text/i.test(svg)) return svg;
    const reason = diagramOutputError(renderer,svg.replace(/<[^>]*>/g,' '));
    if (reason) throw new Error('PlantUML rendering failed: '+reason);
    return svg;
  }
  globalThis.__mdvuValidateDiagramSVG = validateDiagramSVG;
  if (typeof module !== 'undefined') { module.exports = diagramOutputError; module.exports.validate = validateDiagramSVG; }
})();
