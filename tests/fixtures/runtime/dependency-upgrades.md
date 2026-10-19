# Diagram engine upgrade regression checks

Explicit ELK compound layout and nested ZenUML calls exercise the upgraded offline engines.


## D092 — Mermaid / ELK compound graph

```mermaid
---
config:
  layout: elk
  elk:
    mergeEdges: true
---
flowchart LR
  subgraph Reader[Native reader]
    Open[Open file] --> Parse[Parse Markdown]
  end
  subgraph Worker[Offline renderer]
    Queue[Queue] --> SVG[SVG output]
  end
  Parse --> Queue
  SVG --> Open
```

## D093 — ZenUML / nested calls and fragments

```zenuml
@Actor User
User -> Viewer.open() {
  Parser.parse()
  if (hasDiagrams) {
    loop (eachDiagram) {
      Worker.render() {
        Engine.layout()
      }
    }
  }
  return document
}
```
