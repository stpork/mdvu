---
title: "mdvu Complete Ecosystem Validation — Markdown Dialects, Mermaid, ZenUML & PlantUML"
subtitle: "Global Knowledge Delivery Platform — Architecture, Operations, Localization and Renderer Conformance"
fixture_version: "2026.09.05-complete-extensions"
encoding: "UTF-8"
mermaid_target: "11.17.2"
plantuml_target: "1.2026.6"
purpose: "maximum practical functional coverage of Markdown ecosystems and diagram formats without pathological stress"
markdown_ecosystem_target: "CommonMark/GFM plus major public Markdown dialects and extensions current in 2026"
---

<a id="top"></a>

# mdvu Complete Ecosystem Validation 🌍🧪

**A realistic technical handbook and renderer-conformance fixture for Markdown ecosystems, Mermaid, ZenUML and PlantUML.**

This document is designed to test **as much real content behavior as practical in one normal-sized document**.
It deliberately avoids pathological stress patterns: there are no hundreds of duplicate diagrams, 300-row synthetic
tables, giant 300-node graphs, exhaustive Unicode code-point dumps, invisible bidi-control tricks, or intentionally
malformed syntax. Instead, each capability appears in a compact, meaningful context.

> [!IMPORTANT]
> **Target benchmark:** Mermaid **11.17.2** and PlantUML **1.2026.6 stable**. Newer Mermaid diagram families,
> ZenUML, and the current PlantUML diagram families are expected behavior for this fixture, not optional probes.

**Validation markers:** `MDVU-COMPLETE-BEGIN`, `MDVU-COMPLETE-MIDDLE`, `MDVU-COMPLETE-END`.

`MDVU-COMPLETE-BEGIN`

| Area | Practical coverage |
|---|---|
| Markdown core | CommonMark/GFM-style blocks and inline syntax, tables, tasks, callouts, HTML, details, footnotes, math probes, links, anchors, code fences |
| Markdown ecosystems | GitHub/GFM, GitLab, Obsidian, Pandoc, MultiMarkdown/Markdown Extra, kramdown/Jekyll, MkDocs/Python-Markdown/PyMdown, MDX/Docusaurus, Hugo/Goldmark, MyST, Quarto/R Markdown/bookdown, VuePress/VitePress, Markdoc, DocFX/Markdig, Marp/Marpit, Jupyter Markdown |
| Navigation | linked TOCs, explicit anchors, automatic heading slugs, duplicate headings, back-links, multilingual navigation targets |
| Mermaid | every diagram family in the Mermaid 11.17.2 syntax catalog, all five C4 views, ZenUML, plus compact feature probes for major grammars |
| PlantUML | all UML families and all non-UML families listed by current PlantUML documentation, plus Board, Wire, preprocessor, stdlib, links and styling |
| Unicode | Latin Extended, Cyrillic, Greek, Hebrew, Arabic/Persian, Indic, Thai, CJK, Japanese, Korean, Georgian, Armenian, emoji and grapheme clusters |
| RTL/LTR | Arabic and Hebrew paragraphs, mixed direction, URLs/numbers inside RTL content |
| Code | common programming/configuration fence languages and punctuation-heavy samples |

<a id="multilingual-toc"></a>

## Table of Contents / Содержание / 目录 / 目次 / الفهرس / תוכן עניינים / Sisällysluettelo

### English

- [1. Executive Summary](#section-1)
- [2. Context, Stakeholders and Requirements](#section-2)
- [3. Solution Architecture](#section-3)
- [4. Data and Integration](#section-4)
- [5. Security and Identity](#section-5)
- [6. Runtime Scenarios](#section-6)
- [7. Deployment and Delivery](#section-7)
- [8. Operations and Resilience](#section-8)
- [9. Governance, Decisions and Roadmap](#section-9)
- [10. Localization, Accessibility and Unicode](#section-10)
- [11. Markdown Feature Appendix](#section-11)
- [12. Mermaid 11.17.2 Reference Appendix](#section-12)
- [13. PlantUML 1.2026.6 Reference Appendix](#section-13)
- [14. Code and Configuration Appendix](#section-14)
- [15. Markdown Dialects & Ecosystem Extensions](#section-15)
- [16. Cross-Dialect Interaction Tests](#section-16)
- [17. Extension Coverage Matrix](#section-17)
- [18. Validation Checklist](#section-18)

### Русский

- [1. Краткое описание](#section-1) · [2. Контекст](#section-2) · [3. Архитектура](#section-3)
- [10. Локализация и Unicode](#section-10) · [11. Markdown](#section-11) · [12. Mermaid](#section-12) · [13. PlantUML](#section-13)
- [15. Диалекты и расширения Markdown](#section-15) · [18. Проверка](#section-18)
- [Навигационная цель на русском](#nav-ru)

### 中文

- [1. 摘要](#section-1) · [3. 解决方案架构](#section-3) · [10. 本地化与 Unicode](#section-10)
- [11. Markdown 功能](#section-11) · [12. Mermaid 图表](#section-12) · [13. PlantUML 图表](#section-13)
- [15. Markdown 方言与扩展](#section-15) · [18. 验证](#section-18)
- [中文导航目标](#nav-zh)

### 日本語

- [1. 概要](#section-1) · [3. アーキテクチャ](#section-3) · [10. ローカライズ](#section-10)
- [12. Mermaid](#section-12) · [13. PlantUML](#section-13) · [15. Markdown 方言・拡張](#section-15) · [日本語ナビゲーション対象](#nav-ja)

### العربية

- [١. الملخص](#section-1) · [٣. البنية](#section-3) · [١٠. الترجمة وUnicode](#section-10)
- [١٢. Mermaid](#section-12) · [١٣. PlantUML](#section-13) · [١٥. امتدادات Markdown](#section-15) · [هدف التنقل العربي](#nav-ar)

### עברית

- [תקציר](#section-1) · [ארכיטקטורה](#section-3) · [Unicode ולוקליזציה](#section-10)
- [Mermaid](#section-12) · [PlantUML](#section-13) · [הרחבות Markdown](#section-15) · [יעד ניווט בעברית](#nav-he)

### Suomi

- [Yhteenveto](#section-1) · [Arkkitehtuuri](#section-3) · [Lokalisointi ja Unicode](#section-10)
- [Markdown](#section-11) · [Mermaid](#section-12) · [PlantUML](#section-13) · [Markdown-laajennukset](#section-15) · [Suomenkielinen navigointikohde](#nav-fi)

---

<a id="section-1"></a>

## 1. Executive Summary

The Global Knowledge Delivery Platform, abbreviated GKDP in this document, is a reference system for
publishing, searching and distributing technical knowledge across web, desktop and API channels. Its purpose
is deliberately ordinary: authors create Markdown-based content, automated services validate and enrich it,
the publication service produces versioned releases, and readers consume the material through interfaces
optimized for navigation and search. The architecture therefore combines content management, rendering,
indexing, localization, access control, observability and software delivery concerns that commonly appear in
real engineering documentation.

The platform is organized around a small number of architectural principles. Source content remains portable
and human-readable; transformation stages are deterministic; published artifacts are immutable within a
release; services communicate through explicit contracts; security controls are applied at trust boundaries;
and operational telemetry is treated as a first-class product capability. These principles allow the same
content to be rendered in multiple clients without binding authors to one editor or one delivery channel.

| Goal | Measure | Target |
|---|---:|---:|
| Publication latency | p95 from merge to searchable release | < 10 min |
| Search availability | Monthly availability | 99.95% |
| Render compatibility | Supported Markdown documents | ≥ 99.9% |
| Localization | Major UI languages | 20+ |
| Recovery | RTO / RPO | 60 min / 15 min |

#### 1.1 System at a Glance

```mermaid
flowchart LR
    Author["Author / Reviewer"] --> Repo["Content Repository"]
    Repo --> CI["Validation & Build"]
    CI --> Publish["Publication Service"]
    Publish --> Search[("Search Index")]
    Publish --> CDN["Artifact / CDN"]
    Reader["Reader"] --> Web["Web / Desktop Viewer"]
    Web --> Search
    Web --> CDN
    Admin["Platform Operator"] --> Observe["Observability"]
    CI --> Observe
    Publish --> Observe
    Web --> Observe
```

### 1.2 Scope

- Content authoring conventions and versioned publication.
- Markdown and Mermaid rendering in desktop and web clients.
- Search, indexing, caching and content metadata.
- Authentication, authorization, audit and secrets handling.
- Localization, accessibility and Unicode behavior.
- Build, release, deployment, monitoring and recovery processes.

Out of scope: collaborative rich-text editing, billing, advertising, and domain-specific business workflows.

<a id="section-2"></a>

## 2. Context, Stakeholders and Requirements

Stakeholders have different expectations of the same publication chain. Authors value predictable syntax and
fast feedback. Reviewers need traceability between changes and releases. Readers need stable navigation,
legible diagrams, working anchors and accurate search. Operators need clear health signals and reversible
deployments. Security and compliance functions require least privilege, audit evidence and controlled
processing of sensitive material. The architecture treats these expectations as constraints rather than
optional enhancements.

#### 2.1 Stakeholder Context — C4

```mermaid
C4Context
    title GKDP System Context
    Person(author, "Author", "Creates and reviews technical content")
    Person(reader, "Reader", "Browses and searches published knowledge")
    Person(operator, "Operator", "Runs and monitors the platform")
    System(gkdp, "GKDP", "Publishes and serves versioned technical knowledge")
    System_Ext(idp, "Identity Provider", "Authentication and group membership")
    System_Ext(git, "Git Hosting", "Source repository and pull requests")
    System_Ext(obs, "Observability Platform", "Metrics, logs and traces")
    Rel(author, git, "Commits and reviews", "Git/HTTPS")
    Rel(git, gkdp, "Triggers publication", "Webhook/API")
    Rel(reader, gkdp, "Reads and searches", "HTTPS")
    Rel(gkdp, idp, "Authenticates users", "OIDC")
    Rel(operator, obs, "Investigates health")
    Rel(gkdp, obs, "Exports telemetry")
```

### 2.2 Functional Requirements

| ID | Requirement | Priority | Verification |
|---|---|---|---|
| FR-01 | Render CommonMark/GFM-style Markdown with stable anchors | Must | Automated fixture |
| FR-02 | Render Mermaid diagrams embedded in fenced code blocks | Must | Automated fixture |
| FR-03 | Preserve UTF-8 text across supported scripts | Must | Localization suite |
| FR-04 | Provide full-text search and heading navigation | Must | Integration test |
| FR-05 | Publish immutable versioned artifacts | Must | Release test |
| FR-06 | Support offline reading of previously downloaded content | Should | Client test |
| FR-07 | Expose health, metrics and diagnostics | Should | Operational test |
| FR-08 | Support accessible keyboard navigation and semantic structure | Must | Accessibility review |

#### 2.3 Requirement Relationships

```mermaid
requirementDiagram
    direction LR
    functionalRequirement rendering {
      id: "FR-01"
      text: "Render Markdown and Mermaid content"
      risk: high
      verifymethod: test
    }
    functionalRequirement unicode {
      id: "FR-03"
      text: "Preserve multilingual UTF-8 content"
      risk: high
      verifymethod: test
    }
    performanceRequirement navigation {
      id: "NFR-01"
      text: "Keep navigation responsive on large normal documents"
      risk: medium
      verifymethod: demonstration
    }
    element viewer {
      type: application
      docref: "test-complete.md"
    }
    viewer - satisfies -> rendering
    viewer - satisfies -> unicode
    viewer - satisfies -> navigation
```

### 2.4 Quality Attributes

Reliability is defined at the document boundary: one unsupported construct must not corrupt unrelated
content or make navigation unusable. Performance targets focus on realistic documents rather than synthetic
extremes; cold opening, heading navigation, scrolling and diagram completion should remain predictable.
Security requires authentication for restricted collections, content integrity checks, safe handling of
external links and conservative treatment of raw HTML. Accessibility requires semantic headings, keyboard
operation, visible focus, sufficient contrast and sensible text alternatives for information that would
otherwise exist only inside a diagram.

#### 2.5 Quality Trade-off Quadrants

```mermaid
quadrantChart
    title Delivery choices: value versus operational cost
    x-axis Lower user value --> Higher user value
    y-axis Lower operating cost --> Higher operating cost
    quadrant-1 Strategic capabilities
    quadrant-2 Expensive specialists
    quadrant-3 Defer or simplify
    quadrant-4 Efficient foundations
    Search indexing: [0.88, 0.55]
    Offline cache: [0.72, 0.45]
    Rich custom themes: [0.45, 0.60]
    Content validation: [0.84, 0.30]
```

<a id="section-3"></a>

## 3. Solution Architecture

GKDP separates source control, publication and consumption. The repository is the authoritative source for
text, diagrams and metadata. A validation pipeline parses Markdown, checks links, validates diagrams and
creates a release manifest. The publication service stores immutable artifacts and updates the search index.
Clients obtain metadata first and content second, allowing them to cache documents independently from query
results. This separation keeps the viewer simple and makes failures easier to isolate.

#### 3.1 Container View

```mermaid
C4Container
    title GKDP Container View
    Person(author, "Author")
    Person(reader, "Reader")
    System_Boundary(gkdp, "GKDP") {
      Container(pipeline, "Publication Pipeline", "CI", "Validates and packages content")
      Container(api, "Knowledge API", "HTTP service", "Serves metadata, documents and search")
      Container(indexer, "Indexer", "Worker", "Builds search documents")
      ContainerDb(store, "Artifact Store", "Object storage", "Versioned Markdown and assets")
      ContainerDb(search, "Search Index", "Search engine", "Full-text index")
      Container(viewer, "Viewer", "Desktop/Web", "Renders Markdown and Mermaid")
    }
    Rel(author, pipeline, "Publishes via repository")
    Rel(pipeline, store, "Writes immutable artifacts")
    Rel(pipeline, indexer, "Queues indexing")
    Rel(indexer, search, "Updates index")
    Rel(reader, viewer, "Reads")
    Rel(viewer, api, "Queries")
    Rel(api, store, "Reads documents")
    Rel(api, search, "Searches")
```

#### 3.2 Component View

```mermaid
C4Component
    title Viewer Components
    Container(viewer, "Viewer", "Desktop/Web", "Displays knowledge")
    ContainerDb(cache, "Local Cache", "SQLite/files", "Stores metadata and rendered fragments")
    Container_Boundary(core, "Rendering Core") {
      Component(loader, "Document Loader", "I/O", "Loads UTF-8 content")
      Component(parser, "Markdown Parser", "Parser", "Creates block structure")
      Component(mermaid, "Mermaid Adapter", "JavaScript", "Creates diagram SVG")
      Component(nav, "Navigation Index", "In-memory", "Headings and anchors")
      Component(search, "Local Search", "Index", "Searches cached content")
    }
    Rel(viewer, loader, "Open document")
    Rel(loader, parser, "Parse text")
    Rel(parser, mermaid, "Render diagram blocks")
    Rel(parser, nav, "Build heading map")
    Rel(viewer, search, "Search")
    Rel(loader, cache, "Read/write")
```

#### 3.3 Architecture Service Map

> Mermaid 11.17.2 benchmark syntax; expected to render in the target profile.

```mermaid
architecture-beta
    group client(cloud)[Client]
    group platform(cloud)[Knowledge Platform]
    service user(internet)[Reader] in client
    service viewer(server)[Viewer] in client
    service api(server)[Knowledge API] in platform
    service store(disk)[Artifact Store] in platform
    service index(database)[Search Index] in platform
    user:R --> L:viewer
    viewer:R --> L:api
    api:B --> T:store
    api:R --> L:index
```

### 3.4 Design Principles

- **Portable source:** Markdown remains readable without the application. Diagrams stay as Mermaid source next to the surrounding explanation.
- **Deterministic publication:** The same source commit, toolchain version and configuration should produce the same manifest and equivalent rendered output.
- **Graceful degradation:** Unsupported enrichment must not hide the surrounding prose. A diagram error is local to that block.
- **Explicit contracts:** APIs, events and artifact formats are versioned. Clients do not depend on undocumented storage implementation details.
- **Observable behavior:** Publication stages emit structured logs, metrics and traces so failures can be linked to source version and release identifier.

<a id="section-4"></a>

## 4. Data and Integration

Content is represented as a small set of durable entities: collection, document, release, asset and search
record. A document has a stable logical identifier while each release records the exact content hash and
publication metadata. Assets such as images are stored separately but referenced from the document manifest.
Search records are derived data and may be rebuilt from releases at any time. This distinction keeps
recovery procedures straightforward and prevents a search outage from becoming a content-integrity incident.

#### 4.1 Content Data Model

```mermaid
erDiagram
    COLLECTION ||--o{ DOCUMENT : contains
    DOCUMENT ||--o{ RELEASE : publishes
    RELEASE ||--o{ ASSET : references
    RELEASE ||--|| MANIFEST : has
    RELEASE ||--o{ SEARCH_RECORD : produces
    COLLECTION {
      string id PK
      string name
      string default_locale
    }
    DOCUMENT {
      string id PK
      string path
      string title
    }
    RELEASE {
      string id PK
      string document_id FK
      string git_sha
      datetime published_at
    }
    ASSET {
      string id PK
      string media_type
      string sha256
    }
    MANIFEST {
      string release_id PK
      string content_sha256
      string renderer_version
    }
    SEARCH_RECORD {
      string release_id FK
      string locale
      string text
    }
```

### 4.2 API Conventions

- JSON over HTTPS for metadata and search.
- Raw UTF-8 Markdown for document bodies.
- Strong ETags based on immutable content hashes.
- Cursor pagination for search results.
- Explicit locale and content-language metadata.
- ISO 8601 timestamps in UTC at service boundaries.

```http
GET /v1/documents/security/zero-trust?version=2026.09 HTTP/1.1
Host: knowledge.example.test
Accept: text/markdown
Accept-Language: fi-FI, en;q=0.8
If-None-Match: "sha256-88c1..."
```

```json
{
  "id": "security/zero-trust",
  "version": "2026.09",
  "title": "Zero Trust Reference Architecture",
  "locale": "en",
  "contentType": "text/markdown; charset=utf-8",
  "sha256": "88c1d84f...",
  "links": {"self": "/v1/documents/security/zero-trust?version=2026.09"}
}
```

#### 4.3 Publication Data Flow

```mermaid
sankey
    Source Markdown,Validation,100
    Validation,Published Artifact,82
    Validation,Rejected Change,18
    Published Artifact,Search Index,45
    Published Artifact,Client Cache,37
    Search Index,Reader Discovery,45
    Client Cache,Reader Open,37
```

#### 4.4 Search and Read Sequence

```mermaid
sequenceDiagram
    autonumber
    actor Reader
    participant Viewer
    participant API
    participant Search
    participant Store
    Reader->>Viewer: Search "identity federation"
    Viewer->>API: GET /search?q=identity+federation
    API->>Search: Query index
    Search-->>API: Ranked results
    API-->>Viewer: Result metadata
    Reader->>Viewer: Open result
    Viewer->>API: GET document release
    API->>Store: Read immutable artifact
    Store-->>API: Markdown + manifest
    API-->>Viewer: UTF-8 document
    Viewer-->>Reader: Render text and diagrams
```

<a id="section-5"></a>

## 5. Security and Identity

The primary security boundary is between untrusted content input and published output. Contributions are
authenticated through the source-control platform, validated in isolated build jobs, and published only
after policy checks succeed. The viewer treats embedded HTML, external links and diagram content as data
rather than trusted executable code. Server APIs rely on federated identity and short-lived tokens, while
internal service credentials are managed through workload identity or secret stores rather than static
credentials in repository files.

#### 5.1 Trust Boundaries

```mermaid
flowchart TB
    subgraph Internet[Untrusted / External]
      Author[Contributor]
      Reader[Reader]
    end
    subgraph Control[Control Plane]
      Git[Git Hosting]
      CI[Isolated Validation Job]
      Policy[Policy Checks]
    end
    subgraph Runtime[Serving Plane]
      API[Knowledge API]
      Store[(Artifact Store)]
      Search[(Search Index)]
    end
    Author --> Git
    Git --> CI
    CI --> Policy
    Policy -->|approved| Store
    Reader --> API
    API --> Store
    API --> Search
```

### 5.2 Security Controls

| Control | Purpose | Evidence |
|---|---|---|
| Federated SSO | Central authentication and MFA | IdP sign-in logs |
| Least privilege | Limit write access to publishing and storage | IAM policy review |
| Artifact hashing | Detect unexpected content replacement | Release manifest |
| Dependency scanning | Identify vulnerable build dependencies | CI security report |
| HTML sanitization | Reduce script and unsafe-link exposure | Renderer test suite |
| Audit logging | Trace administrative and publication actions | Immutable audit stream |
| Backup and restore | Recover metadata and configurations | Quarterly restore exercise |

#### 5.3 Security State Model

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Review : pull request opened
    Review --> Rejected : policy failure
    Rejected --> Draft : author updates
    Review --> Approved : review + checks pass
    Approved --> Published : signed publication job
    Published --> Superseded : newer release
    Superseded --> Archived : retention transition
    Archived --> [*]
```

#### 5.4 Risk Analysis — Ishikawa

> Mermaid 11.17.2 benchmark syntax; expected to render in the target profile.

```mermaid
ishikawa-beta
    Rendering Incident
      Content
        Unsupported syntax
        Unsafe HTML
      Runtime
        Mermaid version mismatch
        Font fallback
      Delivery
        Partial artifact upload
        Stale cache
      Operations
        Missing alert
        Insufficient diagnostics
```

<a id="section-6"></a>

## 6. Runtime Scenarios

Runtime scenarios describe observable behavior rather than internal implementation. They are useful both for
design reviews and for viewer regression tests because they combine prose, headings and diagrams in the same
section. The scenarios below cover opening a document, rendering diagrams progressively, searching, offline
access and handling a new publication while a reader has an older version cached.

#### 6.1 Open and Render

```mermaid
sequenceDiagram
    actor User
    participant UI as Viewer UI
    participant Loader
    participant Parser
    participant Mermaid
    User->>UI: Open document
    UI->>Loader: load(path)
    Loader-->>UI: UTF-8 text
    UI->>Parser: parse(text)
    Parser-->>UI: document blocks
    par text blocks
      UI->>UI: render immediately
    and diagram blocks
      UI->>Mermaid: render(source)
      Mermaid-->>UI: SVG
    end
    UI-->>User: Fully rendered document
```

#### 6.2 Dynamic Render Path — C4

```mermaid
C4Dynamic
    title Reader opens a document
    Container(ui, "Viewer", "Desktop/Web", "Displays the document")
    Container_Boundary(core, "Rendering Core") {
      Component(parser, "Markdown Parser", "Parser", "Builds block model")
      Component(renderer, "Mermaid Renderer", "JavaScript", "Builds SVG")
    }
    Rel(ui, parser, "1. Parse Markdown")
    Rel(parser, renderer, "2. Render Mermaid blocks")
    Rel(renderer, ui, "3. Return SVG")
```

#### 6.3 Alternative Interaction — ZenUML

```mermaid
zenuml
    @Actor Reader
    Reader->Viewer: open(document)
    Viewer->Parser: parse(markdown)
    if(hasDiagrams) {
      Viewer->Mermaid: render(diagrams)
      Mermaid->Viewer: svg
    }
    Viewer->Reader: display(document)
```

#### 6.4 Workflow Swimlanes

> Extended Mermaid syntax; intentionally small and business-like.

```mermaid
swimlane-beta LR
    subgraph Author[Author]
      A[Edit Markdown]
      D[Address review]
    end
    subgraph Platform[Platform]
      B[Validate]
      C[Publish]
    end
    subgraph Reader[Reader]
      E[Open release]
    end
    A --> B
    B --> D
    D --> B
    B --> C
    C --> E
```

<a id="section-7"></a>

## 7. Deployment and Delivery

Deployment separates the publication toolchain from the serving plane. Publication runs in ephemeral CI
workers with network access limited to required repositories and artifact destinations. Serving components
run across at least two failure domains, while immutable artifacts are stored independently of the API
processes. The desktop viewer contains its Markdown parser and Mermaid runtime so that previously downloaded
documents remain readable without an active network connection.

#### 7.1 Deployment View

```mermaid
C4Deployment
    title GKDP Deployment
    Deployment_Node(cloud, "Cloud Region", "Managed platform") {
      Deployment_Node(app, "Application Cluster", "Containers") {
        Container(api, "Knowledge API", "Service", "Metadata and content API")
        Container(indexer, "Indexer", "Worker", "Search indexing")
      }
      Deployment_Node(data, "Data Services", "Managed") {
        ContainerDb(store, "Artifact Store", "Object storage", "Published content")
        ContainerDb(search, "Search", "Search engine", "Indexes")
      }
    }
    Deployment_Node(mac, "Reader Device", "macOS") {
      Container(viewer, "Viewer", "Native app", "Markdown + Mermaid rendering")
    }
    Rel(viewer, api, "HTTPS")
    Rel(api, store, "Read")
    Rel(api, search, "Query")
    Rel(indexer, search, "Write")
```

#### 7.2 Release Timeline

```mermaid
gantt
    title Example release train
    dateFormat YYYY-MM-DD
    axisFormat %d %b
    section Content
    Draft documentation      :done, a1, 2026-09-01, 2d
    Technical review         :done, after a1, 1d
    Localization             :active, 2026-09-03, 2d
    section Engineering
    Renderer validation      :done, b1, 2026-09-02, 2d
    Package release          :2026-09-04, 1d
    section Release
    Publish                  :milestone, 2026-09-05, 0d
    Observe                  :2026-09-05, 2d
```

#### 7.3 Git Release Flow

```mermaid
gitGraph
    commit id: "baseline"
    branch feature/docs
    checkout feature/docs
    commit id: "update handbook"
    commit id: "add diagrams"
    checkout main
    merge feature/docs
    commit id: "release metadata" tag: "v1.4.0"
    branch hotfix/link
    checkout hotfix/link
    commit id: "fix link"
    checkout main
    merge hotfix/link tag: "v1.4.1"
```

### 7.4 Release Checklist

- [x] Source revision identified.
- [x] Markdown validation passed.
- [x] Mermaid baseline diagrams rendered.
- [x] Links and assets checked.
- [x] Release notes prepared.
- [ ] Production publication approved.
- [ ] Post-release smoke check completed.

<a id="section-8"></a>

## 8. Operations and Resilience

Operational design focuses on diagnosis and recovery rather than on avoiding every failure. Metrics provide
aggregate health, logs explain individual operations, and traces connect user requests to storage and search
dependencies. Alerts are tied to user-visible symptoms such as elevated document-open failures, publication
backlog or search latency rather than to every infrastructure fluctuation. Runbooks start with observable
symptoms and decision points so they remain useful when the underlying implementation changes.

#### 8.1 Operational State Machine

```mermaid
stateDiagram
    [*] --> Healthy
    Healthy --> Degraded : dependency latency
    Degraded --> Healthy : recovery
    Degraded --> Incident : error budget exceeded
    Incident --> Mitigated : traffic or feature mitigation
    Mitigated --> Recovering : root cause addressed
    Recovering --> Healthy : validation passed
```

### 8.2 Service Objectives

| Signal | SLI | Objective | Alerting window |
|---|---|---:|---|
| Document open | Successful opens / attempts | 99.95% | 5m + 1h |
| Search | Successful searches / attempts | 99.90% | 10m + 6h |
| Publication | Successful releases / attempted releases | 99.5% | per release |
| Latency | p95 API latency | < 400 ms | 15m |
| Freshness | Merge-to-searchable p95 | < 10 min | 30m |

#### 8.3 Example Performance Trend

```mermaid
xychart
    title "Typical document-open latency"
    x-axis ["1k lines", "3k lines", "6k lines", "10k lines", "15k lines"]
    y-axis "milliseconds" 0 --> 800
    bar "cold" [90, 170, 290, 460, 680]
    line "warm" [55, 90, 145, 240, 360]
```

#### 8.4 Capability Radar

> Mermaid 11.17.2 benchmark syntax. Values are illustrative coverage scores, not performance measurements.

```mermaid
radar-beta
    title Viewer validation coverage
    axis md["Markdown"], mm["Mermaid"], uc["Unicode"], nav["Navigation"], code["Code"], rtl["RTL"]
    curve light["Complete fixture"]{90, 90, 85, 90, 85, 80}
    curve smoke["Tiny smoke test"]{55, 35, 30, 50, 35, 15}
    min 0
    max 100
    ticks 5
```

<a id="section-9"></a>

## 9. Governance, Decisions and Roadmap

Architecture governance is intentionally lightweight. Decisions that affect compatibility, security
boundaries, artifact formats or operational responsibilities are recorded as short architecture decision
records. Routine library updates and implementation refactoring remain within team ownership unless they
alter one of those contracts. This keeps the decision log small enough to be read while still preserving the
reasoning behind costly-to-reverse choices.

### 9.1 Decision Log

| ADR | Decision | Status | Consequence |
|---|---|---|---|
| ADR-001 | Markdown is the canonical source format | Accepted | Portable and diff-friendly source |
| ADR-002 | Mermaid is the canonical diagram-as-code format | Accepted | Diagrams version with prose |
| ADR-003 | Releases use immutable content hashes | Accepted | Caches and audits are reliable |
| ADR-004 | Viewer supports progressive diagram rendering | Accepted | Text is usable before all diagrams finish |
| ADR-005 | New Mermaid grammars are introduced behind compatibility tests | Proposed | Runtime upgrades become controlled |

#### 9.2 Capability Roadmap

```mermaid
timeline
    title GKDP capability roadmap
    2026 Q3 : Stable Markdown viewer
            : Mermaid baseline coverage
    2026 Q4 : Offline collections
            : Improved accessibility
    2027 Q1 : Cross-document references
            : Search ranking improvements
    2027 Q2 : Policy-aware collections
            : Localization workflow automation
```

#### 9.3 Delivery Portfolio

```mermaid
kanban
  Backlog
    task1[Cross-document backlinks]
    task2[Additional locale QA]
  In Progress
    task3[Offline cache improvements]
  Review
    task4[Accessibility audit]
  Done
    task5[Immutable release manifest]
    task6[Mermaid rendering bridge]
```

#### 9.4 Product Capability Tree

```mermaid
mindmap
  root((Knowledge Platform))
    Authoring
      Markdown
      Mermaid
      Reviews
    Publication
      Validation
      Versioning
      Indexing
    Consumption
      Navigation
      Search
      Offline cache
    Operations
      Metrics
      Logs
      Recovery
```

#### 9.5 Portfolio Treemap

> Mermaid 11.17.2 benchmark syntax; expected to render in the target profile.

```mermaid
treemap-beta
    "Knowledge Platform"
      "Authoring"
        "Markdown": 25
        "Review": 10
      "Publication"
        "Validation": 20
        "Indexing": 15
      "Consumption"
        "Viewer": 20
        "Search": 10
```

### 9.6 Engineering Practice Deep Dives

The following practice notes make the fixture resemble a real engineering handbook rather than a diagram
gallery. They use ordinary technical prose with interfaces, controls, operational responsibilities,
trade-offs and evidence. Each subsection is long enough to exercise paragraph layout and navigation, but
none is intended as a stress test.

#### 9.6.1 Content lifecycle management

The purpose of this practice is to keep the logical identity of a document separate from individual
published versions. In a documentation platform this matters because the rendered file is not an isolated
page: it participates in publication, navigation, search, caching and long-term references. A design that
looks acceptable in a one-off preview can become expensive once documents are versioned and distributed to
many clients. The practice is therefore expressed as an architectural behavior rather than as a preference
for one library or framework.

The main engineering challenge is that authors may rename files, split sections, translate content, or
retire obsolete guidance while readers still depend on stable references. These conditions tend to appear
gradually as the corpus grows, so they are easy to dismiss during early development. A useful design review
asks what happens when a document is renamed, localized, partially cached, opened offline, rendered with a
newer runtime, or referenced from an older release. The answers should remain understandable without
requiring a developer to inspect implementation internals.

The preferred approach is to use stable document identifiers, explicit release metadata, redirect records
for moved content, and retention rules for superseded releases. This is intentionally technology-neutral: a
desktop implementation and a web implementation may use different APIs, but they should preserve the same
externally visible guarantees. Where a feature is optional, the fallback should preserve readable text and
navigation. Where data integrity is involved, immutable identifiers and explicit validation are preferred
over best-effort inference.

Operationally, operators monitor publication failures, redirect loops, orphaned assets, and unexpectedly
large changes in document count. The objective is not to instrument every line of rendering code. Instead,
diagnostics should distinguish user-visible failure modes and retain the version information needed to
reproduce them. Metrics and logs are most valuable when they help an operator decide whether the problem
belongs to the document, the renderer, a dependency, a platform release or a remote service.

Verification should be proportionate to the risk. For this practice, a release manifest, link report,
redirect report, and sampled navigation test provide practical evidence that the lifecycle remains coherent.
The routine light fixture is expected to cover the normal path, while targeted regression cases capture bugs
that deserve permanent protection. The much larger torture fixture is reserved for changes where memory
pressure, unusual Unicode behavior, very large graphs or parser recovery are specifically under
investigation.

#### 9.6.2 Markdown compatibility policy

The purpose of this practice is to provide a predictable authoring contract without pretending that every
Markdown dialect is identical. In a documentation platform this matters because the rendered file is not an
isolated page: it participates in publication, navigation, search, caching and long-term references. A
design that looks acceptable in a one-off preview can become expensive once documents are versioned and
distributed to many clients. The practice is therefore expressed as an architectural behavior rather than as
a preference for one library or framework.

The main engineering challenge is that differences around tables, footnotes, callouts, raw HTML, math and
task lists can produce documents that look correct in one renderer and degrade in another. These conditions
tend to appear gradually as the corpus grows, so they are easy to dismiss during early development. A useful
design review asks what happens when a document is renamed, localized, partially cached, opened offline,
rendered with a newer runtime, or referenced from an older release. The answers should remain understandable
without requiring a developer to inspect implementation internals.

The preferred approach is to define a documented baseline, identify optional extensions, test representative
fixtures, and prefer portable constructs for information that is essential to the reader. This is
intentionally technology-neutral: a desktop implementation and a web implementation may use different APIs,
but they should preserve the same externally visible guarantees. Where a feature is optional, the fallback
should preserve readable text and navigation. Where data integrity is involved, immutable identifiers and
explicit validation are preferred over best-effort inference.

Operationally, version upgrades are introduced through compatibility tests and a small canary corpus before
they become the default renderer. The objective is not to instrument every line of rendering code. Instead,
diagnostics should distinguish user-visible failure modes and retain the version information needed to
reproduce them. Metrics and logs are most valuable when they help an operator decide whether the problem
belongs to the document, the renderer, a dependency, a platform release or a remote service.

Verification should be proportionate to the risk. For this practice, the compatibility fixture, parser
version inventory, release notes and known-differences list form the minimum evidence set for an upgrade.
The routine light fixture is expected to cover the normal path, while targeted regression cases capture bugs
that deserve permanent protection. The much larger torture fixture is reserved for changes where memory
pressure, unusual Unicode behavior, very large graphs or parser recovery are specifically under
investigation.

#### 9.6.3 Mermaid compatibility management

The purpose of this practice is to treat Mermaid syntax as executable document grammar with an explicit
runtime dependency. In a documentation platform this matters because the rendered file is not an isolated
page: it participates in publication, navigation, search, caching and long-term references. A design that
looks acceptable in a one-off preview can become expensive once documents are versioned and distributed to
many clients. The practice is therefore expressed as an architectural behavior rather than as a preference
for one library or framework.

The main engineering challenge is that new diagram families and grammar changes can make an otherwise
unchanged Markdown document render differently after a runtime upgrade. These conditions tend to appear
gradually as the corpus grows, so they are easy to dismiss during early development. A useful design review
asks what happens when a document is renamed, localized, partially cached, opened offline, rendered with a
newer runtime, or referenced from an older release. The answers should remain understandable without
requiring a developer to inspect implementation internals.

The preferred approach is to pin the renderer version in reproducible builds, separate common baseline
diagrams from newer probes, and keep diagrams small enough that textual explanations remain authoritative.
This is intentionally technology-neutral: a desktop implementation and a web implementation may use
different APIs, but they should preserve the same externally visible guarantees. Where a feature is
optional, the fallback should preserve readable text and navigation. Where data integrity is involved,
immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, render failures are counted by diagram family and document so a single unsupported grammar
does not become an unexplained global failure rate. The objective is not to instrument every line of
rendering code. Instead, diagnostics should distinguish user-visible failure modes and retain the version
information needed to reproduce them. Metrics and logs are most valuable when they help an operator decide
whether the problem belongs to the document, the renderer, a dependency, a platform release or a remote
service.

Verification should be proportionate to the risk. For this practice, a gallery of representative diagrams,
runtime version metadata, screenshot review for selected complex diagrams, and automated error counts
support release confidence. The routine light fixture is expected to cover the normal path, while targeted
regression cases capture bugs that deserve permanent protection. The much larger torture fixture is reserved
for changes where memory pressure, unusual Unicode behavior, very large graphs or parser recovery are
specifically under investigation.

#### 9.6.4 Search indexing

The purpose of this practice is to make published knowledge discoverable without turning the search index
into the authoritative source of content. In a documentation platform this matters because the rendered file
is not an isolated page: it participates in publication, navigation, search, caching and long-term
references. A design that looks acceptable in a one-off preview can become expensive once documents are
versioned and distributed to many clients. The practice is therefore expressed as an architectural behavior
rather than as a preference for one library or framework.

The main engineering challenge is that tokenization, language handling, heading weights, code blocks and
duplicated versions can all distort ranking if indexing rules are not explicit. These conditions tend to
appear gradually as the corpus grows, so they are easy to dismiss during early development. A useful design
review asks what happens when a document is renamed, localized, partially cached, opened offline, rendered
with a newer runtime, or referenced from an older release. The answers should remain understandable without
requiring a developer to inspect implementation internals.

The preferred approach is to derive searchable records from immutable releases, record document and locale
identifiers, boost titles and headings, and exclude purely presentational markup from primary ranking
signals. This is intentionally technology-neutral: a desktop implementation and a web implementation may use
different APIs, but they should preserve the same externally visible guarantees. Where a feature is
optional, the fallback should preserve readable text and navigation. Where data integrity is involved,
immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, operators watch indexing backlog, index freshness, zero-result rates, query latency and the
proportion of results that point to unavailable releases. The objective is not to instrument every line of
rendering code. Instead, diagnostics should distinguish user-visible failure modes and retain the version
information needed to reproduce them. Metrics and logs are most valuable when they help an operator decide
whether the problem belongs to the document, the renderer, a dependency, a platform release or a remote
service.

Verification should be proportionate to the risk. For this practice, rebuild exercises, sampled query sets,
freshness dashboards and a versioned index schema demonstrate that search can be recovered independently
from source content. The routine light fixture is expected to cover the normal path, while targeted
regression cases capture bugs that deserve permanent protection. The much larger torture fixture is reserved
for changes where memory pressure, unusual Unicode behavior, very large graphs or parser recovery are
specifically under investigation.

#### 9.6.5 Offline cache behavior

The purpose of this practice is to allow readers to reopen previously downloaded knowledge when the network
is unavailable or intentionally disconnected. In a documentation platform this matters because the rendered
file is not an isolated page: it participates in publication, navigation, search, caching and long-term
references. A design that looks acceptable in a one-off preview can become expensive once documents are
versioned and distributed to many clients. The practice is therefore expressed as an architectural behavior
rather than as a preference for one library or framework.

The main engineering challenge is that cache invalidation, storage limits, renamed documents and partial
asset downloads can otherwise leave a client with a confusing mixture of old metadata and new content. These
conditions tend to appear gradually as the corpus grows, so they are easy to dismiss during early
development. A useful design review asks what happens when a document is renamed, localized, partially
cached, opened offline, rendered with a newer runtime, or referenced from an older release. The answers
should remain understandable without requiring a developer to inspect implementation internals.

The preferred approach is to cache immutable releases by content hash, store a small metadata catalog
separately, download assets transactionally, and make eviction decisions at release boundaries rather than
individual blocks. This is intentionally technology-neutral: a desktop implementation and a web
implementation may use different APIs, but they should preserve the same externally visible guarantees.
Where a feature is optional, the fallback should preserve readable text and navigation. Where data integrity
is involved, immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, the client records cache size, failed downloads, stale metadata age and recovery from
interrupted downloads without collecting document contents as telemetry. The objective is not to instrument
every line of rendering code. Instead, diagnostics should distinguish user-visible failure modes and retain
the version information needed to reproduce them. Metrics and logs are most valuable when they help an
operator decide whether the problem belongs to the document, the renderer, a dependency, a platform release
or a remote service.

Verification should be proportionate to the risk. For this practice, offline scenario tests, checksum
validation and deterministic cache cleanup give stronger evidence than simply verifying that a file exists
on disk. The routine light fixture is expected to cover the normal path, while targeted regression cases
capture bugs that deserve permanent protection. The much larger torture fixture is reserved for changes
where memory pressure, unusual Unicode behavior, very large graphs or parser recovery are specifically under
investigation.

#### 9.6.6 Progressive rendering

The purpose of this practice is to show useful text quickly while diagrams and expensive enrichments
complete independently. In a documentation platform this matters because the rendered file is not an
isolated page: it participates in publication, navigation, search, caching and long-term references. A
design that looks acceptable in a one-off preview can become expensive once documents are versioned and
distributed to many clients. The practice is therefore expressed as an architectural behavior rather than as
a preference for one library or framework.

The main engineering challenge is that blocking the whole document on every diagram makes first paint
sensitive to one complex SVG layout and creates the impression that the viewer is frozen. These conditions
tend to appear gradually as the corpus grows, so they are easy to dismiss during early development. A useful
design review asks what happens when a document is renamed, localized, partially cached, opened offline,
rendered with a newer runtime, or referenced from an older release. The answers should remain understandable
without requiring a developer to inspect implementation internals.

The preferred approach is to parse the document once, display ordinary text and code blocks immediately,
schedule diagram work with bounded concurrency, and preserve layout placeholders so late SVG insertion does
not cause disruptive jumps. This is intentionally technology-neutral: a desktop implementation and a web
implementation may use different APIs, but they should preserve the same externally visible guarantees.
Where a feature is optional, the fallback should preserve readable text and navigation. Where data integrity
is involved, immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, measure time to first readable content separately from time to full render, and record
diagram queue depth or render errors when diagnostics are enabled. The objective is not to instrument every
line of rendering code. Instead, diagnostics should distinguish user-visible failure modes and retain the
version information needed to reproduce them. Metrics and logs are most valuable when they help an operator
decide whether the problem belongs to the document, the renderer, a dependency, a platform release or a
remote service.

Verification should be proportionate to the risk. For this practice, performance tests on small, medium and
large normal documents verify that progressive behavior remains stable without requiring pathological
benchmark files. The routine light fixture is expected to cover the normal path, while targeted regression
cases capture bugs that deserve permanent protection. The much larger torture fixture is reserved for
changes where memory pressure, unusual Unicode behavior, very large graphs or parser recovery are
specifically under investigation.

#### 9.6.7 Anchor and navigation stability

The purpose of this practice is to let users bookmark headings and share references that continue to work as
a document evolves. In a documentation platform this matters because the rendered file is not an isolated
page: it participates in publication, navigation, search, caching and long-term references. A design that
looks acceptable in a one-off preview can become expensive once documents are versioned and distributed to
many clients. The practice is therefore expressed as an architectural behavior rather than as a preference
for one library or framework.

The main engineering challenge is that automatic slug generation differs between Markdown engines,
especially for punctuation, repeated headings and non-Latin scripts. These conditions tend to appear
gradually as the corpus grows, so they are easy to dismiss during early development. A useful design review
asks what happens when a document is renamed, localized, partially cached, opened offline, rendered with a
newer runtime, or referenced from an older release. The answers should remain understandable without
requiring a developer to inspect implementation internals.

The preferred approach is to define one slug algorithm, expose explicit anchors where long-term stability
matters, disambiguate duplicates deterministically, and keep navigation based on the parsed heading tree
rather than visual text search. This is intentionally technology-neutral: a desktop implementation and a web
implementation may use different APIs, but they should preserve the same externally visible guarantees.
Where a feature is optional, the fallback should preserve readable text and navigation. Where data integrity
is involved, immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, broken fragment links and duplicate generated IDs should be visible in validation output
because they often remain unnoticed during ordinary reading. The objective is not to instrument every line
of rendering code. Instead, diagnostics should distinguish user-visible failure modes and retain the version
information needed to reproduce them. Metrics and logs are most valuable when they help an operator decide
whether the problem belongs to the document, the renderer, a dependency, a platform release or a remote
service.

Verification should be proportionate to the risk. For this practice, a heading index dump, internal-link
checker and regression cases for Latin, Cyrillic, CJK and RTL headings provide concrete compatibility
evidence. The routine light fixture is expected to cover the normal path, while targeted regression cases
capture bugs that deserve permanent protection. The much larger torture fixture is reserved for changes
where memory pressure, unusual Unicode behavior, very large graphs or parser recovery are specifically under
investigation.

#### 9.6.8 External link handling

The purpose of this practice is to make external references convenient while preventing document content
from silently gaining application-level privileges. In a documentation platform this matters because the
rendered file is not an isolated page: it participates in publication, navigation, search, caching and
long-term references. A design that looks acceptable in a one-off preview can become expensive once
documents are versioned and distributed to many clients. The practice is therefore expressed as an
architectural behavior rather than as a preference for one library or framework.

The main engineering challenge is that links can target unexpected schemes, redirect through tracking
services, contain Unicode lookalikes, or point to resources that disappear after publication. These
conditions tend to appear gradually as the corpus grows, so they are easy to dismiss during early
development. A useful design review asks what happens when a document is renamed, localized, partially
cached, opened offline, rendered with a newer runtime, or referenced from an older release. The answers
should remain understandable without requiring a developer to inspect implementation internals.

The preferred approach is to allow a conservative scheme set, present destinations clearly, open external
resources through the platform security model, and distinguish link validation from automatic content
retrieval. This is intentionally technology-neutral: a desktop implementation and a web implementation may
use different APIs, but they should preserve the same externally visible guarantees. Where a feature is
optional, the fallback should preserve readable text and navigation. Where data integrity is involved,
immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, operators and authors review broken-link reports, but temporary network failures are not
treated as reasons to block access to an otherwise valid local document. The objective is not to instrument
every line of rendering code. Instead, diagnostics should distinguish user-visible failure modes and retain
the version information needed to reproduce them. Metrics and logs are most valuable when they help an
operator decide whether the problem belongs to the document, the renderer, a dependency, a platform release
or a remote service.

Verification should be proportionate to the risk. For this practice, policy tests for schemes,
representative internationalized URLs and scheduled link checks provide evidence without requiring the
viewer to become a general-purpose browser. The routine light fixture is expected to cover the normal path,
while targeted regression cases capture bugs that deserve permanent protection. The much larger torture
fixture is reserved for changes where memory pressure, unusual Unicode behavior, very large graphs or parser
recovery are specifically under investigation.

#### 9.6.9 Raw HTML policy

The purpose of this practice is to support practical documentation fragments such as details, tables and
keyboard tags without allowing arbitrary active content. In a documentation platform this matters because
the rendered file is not an isolated page: it participates in publication, navigation, search, caching and
long-term references. A design that looks acceptable in a one-off preview can become expensive once
documents are versioned and distributed to many clients. The practice is therefore expressed as an
architectural behavior rather than as a preference for one library or framework.

The main engineering challenge is that Markdown frequently permits raw HTML, but a desktop or web viewer can
create security problems if scripts, event handlers or unsafe embedded objects execute with application
privileges. These conditions tend to appear gradually as the corpus grows, so they are easy to dismiss
during early development. A useful design review asks what happens when a document is renamed, localized,
partially cached, opened offline, rendered with a newer runtime, or referenced from an older release. The
answers should remain understandable without requiring a developer to inspect implementation internals.

The preferred approach is to define an allowlist or sanitization policy, keep scripting disabled, restrict
dangerous URL schemes, and document differences between source-preserving and rendered views. This is
intentionally technology-neutral: a desktop implementation and a web implementation may use different APIs,
but they should preserve the same externally visible guarantees. Where a feature is optional, the fallback
should preserve readable text and navigation. Where data integrity is involved, immutable identifiers and
explicit validation are preferred over best-effort inference.

Operationally, sanitization rejections are diagnostic events rather than application crashes, and the
surrounding Markdown remains visible even if one HTML fragment is removed. The objective is not to
instrument every line of rendering code. Instead, diagnostics should distinguish user-visible failure modes
and retain the version information needed to reproduce them. Metrics and logs are most valuable when they
help an operator decide whether the problem belongs to the document, the renderer, a dependency, a platform
release or a remote service.

Verification should be proportionate to the risk. For this practice, security tests use benign
representatives of allowed and rejected elements, while code review verifies that sanitization happens
before insertion into a privileged rendering context. The routine light fixture is expected to cover the
normal path, while targeted regression cases capture bugs that deserve permanent protection. The much larger
torture fixture is reserved for changes where memory pressure, unusual Unicode behavior, very large graphs
or parser recovery are specifically under investigation.

#### 9.6.10 Unicode and font fallback

The purpose of this practice is to render legitimate multilingual source without data loss and without
assuming a single font contains every script. In a documentation platform this matters because the rendered
file is not an isolated page: it participates in publication, navigation, search, caching and long-term
references. A design that looks acceptable in a one-off preview can become expensive once documents are
versioned and distributed to many clients. The practice is therefore expressed as an architectural behavior
rather than as a preference for one library or framework.

The main engineering challenge is that CJK ideographs, Arabic shaping, Indic combining sequences, emoji and
technical symbols may require different fonts or shaping behavior even within one paragraph. These
conditions tend to appear gradually as the corpus grows, so they are easy to dismiss during early
development. A useful design review asks what happens when a document is renamed, localized, partially
cached, opened offline, rendered with a newer runtime, or referenced from an older release. The answers
should remain understandable without requiring a developer to inspect implementation internals.

The preferred approach is to keep source as UTF-8, use platform text shaping, select a sensible fallback
stack, avoid per-character manual layout, and test language samples that reflect real scripts instead of
exhaustive Unicode ranges. This is intentionally technology-neutral: a desktop implementation and a web
implementation may use different APIs, but they should preserve the same externally visible guarantees.
Where a feature is optional, the fallback should preserve readable text and navigation. Where data integrity
is involved, immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, missing-glyph boxes, replacement characters and unexpected text-direction changes are
high-value visual signals during compatibility testing. The objective is not to instrument every line of
rendering code. Instead, diagnostics should distinguish user-visible failure modes and retain the version
information needed to reproduce them. Metrics and logs are most valuable when they help an operator decide
whether the problem belongs to the document, the renderer, a dependency, a platform release or a remote
service.

Verification should be proportionate to the risk. For this practice, the multilingual appendix, screenshot
checks on representative systems and round-trip source hashing provide reasonable evidence that rendering
does not corrupt content. The routine light fixture is expected to cover the normal path, while targeted
regression cases capture bugs that deserve permanent protection. The much larger torture fixture is reserved
for changes where memory pressure, unusual Unicode behavior, very large graphs or parser recovery are
specifically under investigation.

#### 9.6.11 Bidirectional text

The purpose of this practice is to keep right-to-left prose readable when it contains numbers, code
identifiers, links and left-to-right product names. In a documentation platform this matters because the
rendered file is not an isolated page: it participates in publication, navigation, search, caching and
long-term references. A design that looks acceptable in a one-off preview can become expensive once
documents are versioned and distributed to many clients. The practice is therefore expressed as an
architectural behavior rather than as a preference for one library or framework.

The main engineering challenge is that mixed-direction text can reorder punctuation visually, make cursor
movement surprising and produce ambiguous selection if paragraph direction is inferred incorrectly. These
conditions tend to appear gradually as the corpus grows, so they are easy to dismiss during early
development. A useful design review asks what happens when a document is renamed, localized, partially
cached, opened offline, rendered with a newer runtime, or referenced from an older release. The answers
should remain understandable without requiring a developer to inspect implementation internals.

The preferred approach is to respect Unicode bidi behavior, support explicit direction on HTML containers
where authors need it, keep code blocks in their expected technical direction, and avoid inserting hidden
direction controls during rendering. This is intentionally technology-neutral: a desktop implementation and
a web implementation may use different APIs, but they should preserve the same externally visible
guarantees. Where a feature is optional, the fallback should preserve readable text and navigation. Where
data integrity is involved, immutable identifiers and explicit validation are preferred over best-effort
inference.

Operationally, testers compare Arabic and Hebrew paragraphs that contain ASCII URLs and numbers, because
those mixed cases reveal practical bidi problems faster than isolated alphabet samples. The objective is not
to instrument every line of rendering code. Instead, diagnostics should distinguish user-visible failure
modes and retain the version information needed to reproduce them. Metrics and logs are most valuable when
they help an operator decide whether the problem belongs to the document, the renderer, a dependency, a
platform release or a remote service.

Verification should be proportionate to the risk. For this practice, visual regression snapshots and
copy-paste checks complement automated text equality because bidi defects are often presentational rather
than byte-level corruption. The routine light fixture is expected to cover the normal path, while targeted
regression cases capture bugs that deserve permanent protection. The much larger torture fixture is reserved
for changes where memory pressure, unusual Unicode behavior, very large graphs or parser recovery are
specifically under investigation.

#### 9.6.12 Accessibility semantics

The purpose of this practice is to preserve document meaning for keyboard users and assistive technologies
rather than treating rendered Markdown as a purely visual canvas. In a documentation platform this matters
because the rendered file is not an isolated page: it participates in publication, navigation, search,
caching and long-term references. A design that looks acceptable in a one-off preview can become expensive
once documents are versioned and distributed to many clients. The practice is therefore expressed as an
architectural behavior rather than as a preference for one library or framework.

The main engineering challenge is that heading hierarchy, tables, links, task states, code and expandable
sections all carry semantics that can be lost if the renderer flattens everything into generic drawing
primitives. These conditions tend to appear gradually as the corpus grows, so they are easy to dismiss
during early development. A useful design review asks what happens when a document is renamed, localized,
partially cached, opened offline, rendered with a newer runtime, or referenced from an older release. The
answers should remain understandable without requiring a developer to inspect implementation internals.

The preferred approach is to map parsed structures to native or web accessibility roles, retain visible
focus, expose link purpose, provide useful table headers, and ensure diagram explanations exist in
surrounding prose when the diagram is essential. This is intentionally technology-neutral: a desktop
implementation and a web implementation may use different APIs, but they should preserve the same externally
visible guarantees. Where a feature is optional, the fallback should preserve readable text and navigation.
Where data integrity is involved, immutable identifiers and explicit validation are preferred over
best-effort inference.

Operationally, accessibility issues are reviewed as product defects, not merely documentation polish,
because they can make otherwise correct information unusable. The objective is not to instrument every line
of rendering code. Instead, diagnostics should distinguish user-visible failure modes and retain the version
information needed to reproduce them. Metrics and logs are most valuable when they help an operator decide
whether the problem belongs to the document, the renderer, a dependency, a platform release or a remote
service.

Verification should be proportionate to the risk. For this practice, keyboard walkthroughs, automated
accessibility scans where applicable, semantic-tree inspection and selected screen-reader checks form a
balanced verification approach. The routine light fixture is expected to cover the normal path, while
targeted regression cases capture bugs that deserve permanent protection. The much larger torture fixture is
reserved for changes where memory pressure, unusual Unicode behavior, very large graphs or parser recovery
are specifically under investigation.

#### 9.6.13 Client-side search

The purpose of this practice is to provide fast navigation within downloaded documents and collections
without requiring a server round trip for every query. In a documentation platform this matters because the
rendered file is not an isolated page: it participates in publication, navigation, search, caching and
long-term references. A design that looks acceptable in a one-off preview can become expensive once
documents are versioned and distributed to many clients. The practice is therefore expressed as an
architectural behavior rather than as a preference for one library or framework.

The main engineering challenge is that naive substring search can mishandle case folding, diacritics, CJK
segmentation and large code blocks, while aggressive normalization can make technical identifiers difficult
to find exactly. These conditions tend to appear gradually as the corpus grows, so they are easy to dismiss
during early development. A useful design review asks what happens when a document is renamed, localized,
partially cached, opened offline, rendered with a newer runtime, or referenced from an older release. The
answers should remain understandable without requiring a developer to inspect implementation internals.

The preferred approach is to maintain separate exact and normalized matching paths, index headings with
higher weight, preserve source ranges for result highlighting, and keep search work off the interactive
rendering path when possible. This is intentionally technology-neutral: a desktop implementation and a web
implementation may use different APIs, but they should preserve the same externally visible guarantees.
Where a feature is optional, the fallback should preserve readable text and navigation. Where data integrity
is involved, immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, diagnostics record index build time and result count rather than the user query itself when
privacy requirements call for local-only search behavior. The objective is not to instrument every line of
rendering code. Instead, diagnostics should distinguish user-visible failure modes and retain the version
information needed to reproduce them. Metrics and logs are most valuable when they help an operator decide
whether the problem belongs to the document, the renderer, a dependency, a platform release or a remote
service.

Verification should be proportionate to the risk. For this practice, fixture markers, multilingual queries
and technical identifiers such as version strings provide repeatable tests for both navigation and text
highlighting. The routine light fixture is expected to cover the normal path, while targeted regression
cases capture bugs that deserve permanent protection. The much larger torture fixture is reserved for
changes where memory pressure, unusual Unicode behavior, very large graphs or parser recovery are
specifically under investigation.

#### 9.6.14 Observability design

The purpose of this practice is to make failures diagnosable from symptoms through dependencies without
collecting unnecessary document content. In a documentation platform this matters because the rendered file
is not an isolated page: it participates in publication, navigation, search, caching and long-term
references. A design that looks acceptable in a one-off preview can become expensive once documents are
versioned and distributed to many clients. The practice is therefore expressed as an architectural behavior
rather than as a preference for one library or framework.

The main engineering challenge is that a rendering issue may originate in parsing, Mermaid layout, font
fallback, asset loading or platform UI, and logs that only say rendering failed do not narrow the problem
enough. These conditions tend to appear gradually as the corpus grows, so they are easy to dismiss during
early development. A useful design review asks what happens when a document is renamed, localized, partially
cached, opened offline, rendered with a newer runtime, or referenced from an older release. The answers
should remain understandable without requiring a developer to inspect implementation internals.

The preferred approach is to use structured events with document identifiers, release hashes, block type,
renderer version, duration and bounded error categories while excluding full sensitive document bodies. This
is intentionally technology-neutral: a desktop implementation and a web implementation may use different
APIs, but they should preserve the same externally visible guarantees. Where a feature is optional, the
fallback should preserve readable text and navigation. Where data integrity is involved, immutable
identifiers and explicit validation are preferred over best-effort inference.

Operationally, metrics aggregate success, latency and queue depth; traces connect operations when
distributed services are involved; local viewer diagnostics remain user-controlled. The objective is not to
instrument every line of rendering code. Instead, diagnostics should distinguish user-visible failure modes
and retain the version information needed to reproduce them. Metrics and logs are most valuable when they
help an operator decide whether the problem belongs to the document, the renderer, a dependency, a platform
release or a remote service.

Verification should be proportionate to the risk. For this practice, a documented event schema, sample
dashboards and incident exercises demonstrate that telemetry supports diagnosis rather than merely
generating large volumes of data. The routine light fixture is expected to cover the normal path, while
targeted regression cases capture bugs that deserve permanent protection. The much larger torture fixture is
reserved for changes where memory pressure, unusual Unicode behavior, very large graphs or parser recovery
are specifically under investigation.

#### 9.6.15 Release engineering

The purpose of this practice is to ensure that a published version, its source revision, its artifacts and
its release notes describe the same immutable state. In a documentation platform this matters because the
rendered file is not an isolated page: it participates in publication, navigation, search, caching and
long-term references. A design that looks acceptable in a one-off preview can become expensive once
documents are versioned and distributed to many clients. The practice is therefore expressed as an
architectural behavior rather than as a preference for one library or framework.

The main engineering challenge is that manual packaging can accidentally mix source revisions, stale
generated assets or checksums from an earlier build, especially when a release is retried after a partial
failure. These conditions tend to appear gradually as the corpus grows, so they are easy to dismiss during
early development. A useful design review asks what happens when a document is renamed, localized, partially
cached, opened offline, rendered with a newer runtime, or referenced from an older release. The answers
should remain understandable without requiring a developer to inspect implementation internals.

The preferred approach is to build from a tagged commit in a clean environment, generate checksums after
final packaging, attach versioned artifacts, record toolchain versions, and update distribution metadata
only after the upstream release is available. This is intentionally technology-neutral: a desktop
implementation and a web implementation may use different APIs, but they should preserve the same externally
visible guarantees. Where a feature is optional, the fallback should preserve readable text and navigation.
Where data integrity is involved, immutable identifiers and explicit validation are preferred over
best-effort inference.

Operationally, release jobs fail closed when validation or signing fails, and reruns create the same logical
release artifacts rather than silently replacing already published bytes. The objective is not to instrument
every line of rendering code. Instead, diagnostics should distinguish user-visible failure modes and retain
the version information needed to reproduce them. Metrics and logs are most valuable when they help an
operator decide whether the problem belongs to the document, the renderer, a dependency, a platform release
or a remote service.

Verification should be proportionate to the risk. For this practice, tag verification, artifact hashes, CI
logs and a concise release manifest provide the evidence needed to trace an installed package back to
source. The routine light fixture is expected to cover the normal path, while targeted regression cases
capture bugs that deserve permanent protection. The much larger torture fixture is reserved for changes
where memory pressure, unusual Unicode behavior, very large graphs or parser recovery are specifically under
investigation.

#### 9.6.16 Dependency upgrades

The purpose of this practice is to introduce parser, Mermaid, syntax-highlighting and platform-library
updates without converting every dependency change into an uncontrolled compatibility experiment. In a
documentation platform this matters because the rendered file is not an isolated page: it participates in
publication, navigation, search, caching and long-term references. A design that looks acceptable in a
one-off preview can become expensive once documents are versioned and distributed to many clients. The
practice is therefore expressed as an architectural behavior rather than as a preference for one library or
framework.

The main engineering challenge is that rendering libraries may change defaults, CSS, generated SVG structure
or accepted syntax even when their public version change appears minor. These conditions tend to appear
gradually as the corpus grows, so they are easy to dismiss during early development. A useful design review
asks what happens when a document is renamed, localized, partially cached, opened offline, rendered with a
newer runtime, or referenced from an older release. The answers should remain understandable without
requiring a developer to inspect implementation internals.

The preferred approach is to separate dependency update branches, run the light compatibility fixture on
every update, reserve the full torture corpus for major renderer changes, and document intentional visual
differences. This is intentionally technology-neutral: a desktop implementation and a web implementation may
use different APIs, but they should preserve the same externally visible guarantees. Where a feature is
optional, the fallback should preserve readable text and navigation. Where data integrity is involved,
immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, canary users or preview builds catch platform-specific behavior that automated CI cannot
reproduce, while rollback remains possible until the new runtime is proven stable. The objective is not to
instrument every line of rendering code. Instead, diagnostics should distinguish user-visible failure modes
and retain the version information needed to reproduce them. Metrics and logs are most valuable when they
help an operator decide whether the problem belongs to the document, the renderer, a dependency, a platform
release or a remote service.

Verification should be proportionate to the risk. For this practice, before-and-after fixture results,
changelog review and pinned lockfiles form a practical minimum control set for dependency maintenance. The
routine light fixture is expected to cover the normal path, while targeted regression cases capture bugs
that deserve permanent protection. The much larger torture fixture is reserved for changes where memory
pressure, unusual Unicode behavior, very large graphs or parser recovery are specifically under
investigation.

#### 9.6.17 Backup and recovery

The purpose of this practice is to recover authoritative metadata and publication capabilities without
confusing derived indexes or caches with irreplaceable source data. In a documentation platform this matters
because the rendered file is not an isolated page: it participates in publication, navigation, search,
caching and long-term references. A design that looks acceptable in a one-off preview can become expensive
once documents are versioned and distributed to many clients. The practice is therefore expressed as an
architectural behavior rather than as a preference for one library or framework.

The main engineering challenge is that backup plans often fail because teams back up large derived stores
while omitting small but critical configuration, signing metadata or identity mappings. These conditions
tend to appear gradually as the corpus grows, so they are easy to dismiss during early development. A useful
design review asks what happens when a document is renamed, localized, partially cached, opened offline,
rendered with a newer runtime, or referenced from an older release. The answers should remain understandable
without requiring a developer to inspect implementation internals.

The preferred approach is to classify source repositories and immutable artifacts as authoritative, define
separate protection for configuration and secrets metadata, and rebuild search or client caches from
published releases when practical. This is intentionally technology-neutral: a desktop implementation and a
web implementation may use different APIs, but they should preserve the same externally visible guarantees.
Where a feature is optional, the fallback should preserve readable text and navigation. Where data integrity
is involved, immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, recovery procedures specify order of restoration, validation criteria and ownership so an
operator does not need to reconstruct architectural assumptions during an outage. The objective is not to
instrument every line of rendering code. Instead, diagnostics should distinguish user-visible failure modes
and retain the version information needed to reproduce them. Metrics and logs are most valuable when they
help an operator decide whether the problem belongs to the document, the renderer, a dependency, a platform
release or a remote service.

Verification should be proportionate to the risk. For this practice, scheduled restore exercises, checksum
comparisons and documented RTO/RPO measurements provide stronger evidence than a dashboard that only reports
successful backup jobs. The routine light fixture is expected to cover the normal path, while targeted
regression cases capture bugs that deserve permanent protection. The much larger torture fixture is reserved
for changes where memory pressure, unusual Unicode behavior, very large graphs or parser recovery are
specifically under investigation.

#### 9.6.18 Incident response

The purpose of this practice is to restore reader-facing service quickly while preserving enough evidence to
determine why the failure occurred. In a documentation platform this matters because the rendered file is
not an isolated page: it participates in publication, navigation, search, caching and long-term references.
A design that looks acceptable in a one-off preview can become expensive once documents are versioned and
distributed to many clients. The practice is therefore expressed as an architectural behavior rather than as
a preference for one library or framework.

The main engineering challenge is that rendering incidents can tempt teams to clear caches, restart
processes and upgrade dependencies simultaneously, which may hide the root cause or create a second
variable. These conditions tend to appear gradually as the corpus grows, so they are easy to dismiss during
early development. A useful design review asks what happens when a document is renamed, localized, partially
cached, opened offline, rendered with a newer runtime, or referenced from an older release. The answers
should remain understandable without requiring a developer to inspect implementation internals.

The preferred approach is to start with scope and symptom confirmation, capture relevant versions and
diagnostics, apply the smallest safe mitigation, communicate user impact, and defer unrelated cleanup until
service is stable. This is intentionally technology-neutral: a desktop implementation and a web
implementation may use different APIs, but they should preserve the same externally visible guarantees.
Where a feature is optional, the fallback should preserve readable text and navigation. Where data integrity
is involved, immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, runbooks include explicit decision points for disabling optional diagram rendering, serving
cached releases, rolling back a viewer build or temporarily reducing publication throughput. The objective
is not to instrument every line of rendering code. Instead, diagnostics should distinguish user-visible
failure modes and retain the version information needed to reproduce them. Metrics and logs are most
valuable when they help an operator decide whether the problem belongs to the document, the renderer, a
dependency, a platform release or a remote service.

Verification should be proportionate to the risk. For this practice, incident timelines, selected logs,
release identifiers and follow-up actions become inputs to regression cases when the failure can reasonably
recur. The routine light fixture is expected to cover the normal path, while targeted regression cases
capture bugs that deserve permanent protection. The much larger torture fixture is reserved for changes
where memory pressure, unusual Unicode behavior, very large graphs or parser recovery are specifically under
investigation.

#### 9.6.19 Capacity and performance

The purpose of this practice is to keep ordinary large documents responsive without optimizing exclusively
for synthetic maximum-size inputs. In a documentation platform this matters because the rendered file is not
an isolated page: it participates in publication, navigation, search, caching and long-term references. A
design that looks acceptable in a one-off preview can become expensive once documents are versioned and
distributed to many clients. The practice is therefore expressed as an architectural behavior rather than as
a preference for one library or framework.

The main engineering challenge is that real workloads combine parsing, text layout, syntax highlighting,
image loading, diagram generation, search indexing and user interaction, so one microbenchmark rarely
predicts perceived performance. These conditions tend to appear gradually as the corpus grows, so they are
easy to dismiss during early development. A useful design review asks what happens when a document is
renamed, localized, partially cached, opened offline, rendered with a newer runtime, or referenced from an
older release. The answers should remain understandable without requiring a developer to inspect
implementation internals.

The preferred approach is to measure cold open, first readable content, full render, navigation and search
on representative document sizes, then profile the dominant stage before adding caching or concurrency. This
is intentionally technology-neutral: a desktop implementation and a web implementation may use different
APIs, but they should preserve the same externally visible guarantees. Where a feature is optional, the
fallback should preserve readable text and navigation. Where data integrity is involved, immutable
identifiers and explicit validation are preferred over best-effort inference.

Operationally, bounded diagram concurrency prevents a document with many diagrams from monopolizing CPU,
while lazy work should not make search or heading navigation depend on unrendered content. The objective is
not to instrument every line of rendering code. Instead, diagnostics should distinguish user-visible failure
modes and retain the version information needed to reproduce them. Metrics and logs are most valuable when
they help an operator decide whether the problem belongs to the document, the renderer, a dependency, a
platform release or a remote service.

Verification should be proportionate to the risk. For this practice, the light fixture acts as a routine
performance sentinel and the separate full torture fixture remains available for memory-pressure,
scalability and pathological-input investigations. The routine light fixture is expected to cover the normal
path, while targeted regression cases capture bugs that deserve permanent protection. The much larger
torture fixture is reserved for changes where memory pressure, unusual Unicode behavior, very large graphs
or parser recovery are specifically under investigation.

#### 9.6.20 Privacy and local data

The purpose of this practice is to minimize collection of reading behavior and document contents while still
providing useful diagnostics and product quality signals. In a documentation platform this matters because
the rendered file is not an isolated page: it participates in publication, navigation, search, caching and
long-term references. A design that looks acceptable in a one-off preview can become expensive once
documents are versioned and distributed to many clients. The practice is therefore expressed as an
architectural behavior rather than as a preference for one library or framework.

The main engineering challenge is that technical knowledge may include confidential architecture, incident
details or internal identifiers, so telemetry that captures raw paragraphs or search terms can create an
unexpected secondary data store. These conditions tend to appear gradually as the corpus grows, so they are
easy to dismiss during early development. A useful design review asks what happens when a document is
renamed, localized, partially cached, opened offline, rendered with a newer runtime, or referenced from an
older release. The answers should remain understandable without requiring a developer to inspect
implementation internals.

The preferred approach is to prefer aggregate counters and technical metadata, keep local search indexes on
device when feasible, make diagnostic export explicit, and apply retention limits to server-side operational
data. This is intentionally technology-neutral: a desktop implementation and a web implementation may use
different APIs, but they should preserve the same externally visible guarantees. Where a feature is
optional, the fallback should preserve readable text and navigation. Where data integrity is involved,
immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, privacy review covers logs, crash reports, analytics, caches and temporary rendering files
rather than focusing only on the primary content API. The objective is not to instrument every line of
rendering code. Instead, diagnostics should distinguish user-visible failure modes and retain the version
information needed to reproduce them. Metrics and logs are most valuable when they help an operator decide
whether the problem belongs to the document, the renderer, a dependency, a platform release or a remote
service.

Verification should be proportionate to the risk. For this practice, data-flow diagrams, event-schema
reviews and tests that inspect emitted telemetry provide evidence that implementation behavior matches the
stated privacy model. The routine light fixture is expected to cover the normal path, while targeted
regression cases capture bugs that deserve permanent protection. The much larger torture fixture is reserved
for changes where memory pressure, unusual Unicode behavior, very large graphs or parser recovery are
specifically under investigation.

#### 9.6.21 Testing strategy

The purpose of this practice is to use a layered test corpus so common regressions are found quickly and
extreme behavior remains testable without slowing every development loop. In a documentation platform this
matters because the rendered file is not an isolated page: it participates in publication, navigation,
search, caching and long-term references. A design that looks acceptable in a one-off preview can become
expensive once documents are versioned and distributed to many clients. The practice is therefore expressed
as an architectural behavior rather than as a preference for one library or framework.

The main engineering challenge is that a single tiny fixture misses integration problems, while running a
multi-megabyte torture file for every edit makes feedback slow and encourages developers to skip validation.
These conditions tend to appear gradually as the corpus grows, so they are easy to dismiss during early
development. A useful design review asks what happens when a document is renamed, localized, partially
cached, opened offline, rendered with a newer runtime, or referenced from an older release. The answers
should remain understandable without requiring a developer to inspect implementation internals.

The preferred approach is to keep a tiny smoke file for startup, this light handbook for broad routine
compatibility, targeted regression files for known bugs, and the full torture fixture for major parser,
Mermaid or performance changes. This is intentionally technology-neutral: a desktop implementation and a web
implementation may use different APIs, but they should preserve the same externally visible guarantees.
Where a feature is optional, the fallback should preserve readable text and navigation. Where data integrity
is involved, immutable identifiers and explicit validation are preferred over best-effort inference.

Operationally, tests assert structural outcomes such as end-marker reachability, diagram error isolation,
heading discovery and source preservation rather than relying only on screenshot equality. The objective is
not to instrument every line of rendering code. Instead, diagnostics should distinguish user-visible failure
modes and retain the version information needed to reproduce them. Metrics and logs are most valuable when
they help an operator decide whether the problem belongs to the document, the renderer, a dependency, a
platform release or a remote service.

Verification should be proportionate to the risk. For this practice, the corpus itself is versioned with the
application so changes in expected behavior are reviewed alongside the code that implements them. The
routine light fixture is expected to cover the normal path, while targeted regression cases capture bugs
that deserve permanent protection. The much larger torture fixture is reserved for changes where memory
pressure, unusual Unicode behavior, very large graphs or parser recovery are specifically under
investigation.

`MDVU-COMPLETE-MIDDLE`

<a id="section-10"></a>

## 10. Localization, Accessibility and Unicode

Localization is treated as both a product requirement and a rendering requirement. The viewer must preserve
UTF-8 source exactly, choose appropriate fallback fonts, support right-to-left paragraphs, keep code and
URLs visually stable inside RTL text, and avoid assuming that one visible character equals one Unicode
scalar value. Search normalization may be language-aware, but rendering must not silently rewrite the source
document.

### 10.1 Language Samples

| Language | Sample |
|---|---|
| **English** | The platform publishes technical knowledge for readers around the world. |
| **Suomi** | Alusta julkaisee teknistä tietoa lukijoille eri puolilla maailmaa. Ääkköset: å ä ö Å Ä Ö. |
| **Svenska** | Plattformen publicerar teknisk kunskap för läsare över hela världen. Å, ä och ö. |
| **Deutsch** | Die Plattform veröffentlicht technisches Wissen für Leser auf der ganzen Welt. Ä, Ö, Ü und ß. |
| **Français** | La plateforme publie des connaissances techniques pour les lecteurs du monde entier : é, è, ê, ç, œ. |
| **Español** | La plataforma publica conocimiento técnico para lectores de todo el mundo: ñ, á, é, í, ó, ú, ü, ¿qué?, ¡sí! |
| **Português** | A plataforma publica conhecimento técnico para leitores em todo o mundo: ã, õ, á, ê, ç. |
| **Polski** | Platforma publikuje wiedzę techniczną dla czytelników na całym świecie: ą ć ę ł ń ó ś ź ż. |
| **Türkçe** | Platform dünyanın her yerindeki okuyucular için teknik bilgi yayımlar: İ ı Ş ş Ğ ğ Ç ç. |
| **Ελληνικά** | Η πλατφόρμα δημοσιεύει τεχνική γνώση για αναγνώστες σε όλο τον κόσμο. |
| **Русский** | Платформа публикует технические материалы для читателей по всему миру. Ёж, объём, «кавычки». |
| **Українська** | Платформа публікує технічні матеріали для читачів у всьому світі: Ґ Є І Ї. |
| **עברית** | הפלטפורמה מפרסמת ידע טכני לקוראים ברחבי העולם. מספרים 12345 ומונח English באמצע. |
| **العربية** | تنشر المنصة المعرفة التقنية للقراء في جميع أنحاء العالم. أرقام ١٢٣٤٥ وعبارة English داخل النص. |
| **فارسی** | این سامانه دانش فنی را برای خوانندگان سراسر جهان منتشر می‌کند. اعداد ۱۲۳۴۵ و واژه English. |
| **हिन्दी** | यह मंच दुनिया भर के पाठकों के लिए तकनीकी ज्ञान प्रकाशित करता है। अंक १२३४५। |
| **বাংলা** | এই প্ল্যাটফর্মটি সারা বিশ্বের পাঠকদের জন্য প্রযুক্তিগত জ্ঞান প্রকাশ করে। সংখ্যা ১২৩৪৫। |
| **தமிழ்** | இந்த தளம் உலகம் முழுவதும் உள்ள வாசகர்களுக்கான தொழில்நுட்ப அறிவை வெளியிடுகிறது. |
| **ไทย** | แพลตฟอร์มนี้เผยแพร่ความรู้ทางเทคนิคสำหรับผู้อ่านทั่วโลก ตัวเลข ๑๒๓๔๕ |
| **简体中文** | 该平台为世界各地的读者发布技术知识。全角标点：，。！？《》；数字１２３４５。 |
| **繁體中文** | 該平台為世界各地的讀者發布技術知識。全形標點：，。！？《》；數字１２３４５。 |
| **日本語** | このプラットフォームは世界中の読者向けに技術知識を公開します。「日本語」、１２３４５。 |
| **한국어** | 이 플랫폼은 전 세계 독자를 위해 기술 지식을 게시합니다. 한글과 숫자 １２３４５를 확인합니다. |
| **ქართული** | პლატფორმა მთელ მსოფლიოში მკითხველებისთვის ტექნიკურ ცოდნას აქვეყნებს. |
| **Հայերեն** | Հարթակը տեխնիկական գիտելիք է հրապարակում ամբողջ աշխարհի ընթերցողների համար։ |

### 10.2 Mixed Direction and Graphemes

<div dir="rtl">العربية مع English و URL https://example.com و الرقم 12345 ثم نص عربي مرة أخرى.</div>

<div dir="rtl">עברית עם English, כתובת https://example.com והמספר 12345 בתוך משפט מימין לשמאל.</div>

Mixed LTR/RTL: `Build 42` → العربية ١٢٣ → English → עברית 456 → Suomi äö.

Emoji and grapheme samples: 😀 😎 🚀 🧪 ✅ ⚠️ ❤️ 👍🏽 👩🏽‍💻 👨‍👩‍👧‍👦 🇫🇮 🇯🇵 🇺🇦.

Normalization sample (visually similar): precomposed `é` and decomposed `é`; precomposed `Å` and decomposed `Å`.

#### 10.3 Multilingual Flowchart

```mermaid
flowchart LR
    EN["English: Start"] --> FI["Suomi: Aloita"]
    FI --> RU["Русский: Проверка"]
    RU --> AR["العربية: تحقق"]
    AR --> ZH["中文：发布"]
    ZH --> JA["日本語：完了"]
    JA --> KO["한국어: 완료"]
```

#### 10.4 Multilingual Sequence

```mermaid
sequenceDiagram
    actor 用户 as 用户 / User
    participant 客户端 as クライアント / Client
    participant 服务 as خدمة / Service
    用户->>客户端: 打开文档 / Open document
    客户端->>服务: طلب المحتوى / Request content
    服务-->>客户端: UTF-8 Markdown
    客户端-->>用户: 表示完了 / Render complete ✅
```



### 10.5 Multilingual Navigation Targets

These headings deliberately use different writing systems. The explicit anchors make cross-navigation deterministic while the headings themselves exercise TOC/search rendering.

<a id="nav-en"></a>
#### English — Navigation target
The reader can jump here from any language-specific contents list. [Back to multilingual contents](#multilingual-toc).

<a id="nav-fi"></a>
#### Suomi — Navigointikohde
Lukija voi siirtyä tähän kohtaan monikielisestä sisällysluettelosta. [Takaisin](#multilingual-toc).

<a id="nav-ru"></a>
#### Русский — Навигационная цель
На этот раздел ведёт ссылка из многоязычного оглавления. [Назад](#multilingual-toc).

<a id="nav-zh"></a>
#### 中文 — 导航目标
此标题用于验证中文目录、锚点和搜索。 [返回目录](#multilingual-toc).

<a id="nav-ja"></a>
#### 日本語 — ナビゲーション対象
この見出しは日本語の目次、アンカー、検索を検証します。 [目次へ戻る](#multilingual-toc).

<a id="nav-ko"></a>
#### 한국어 — 탐색 대상
이 제목은 한국어 목차, 앵커 및 검색을 확인합니다. [목차로](#multilingual-toc).

<a id="nav-ar"></a>
#### العربية — هدف التنقل
يختبر هذا العنوان الفهرس والروابط والبحث باللغة العربية. [العودة](#multilingual-toc).

<a id="nav-he"></a>
#### עברית — יעד ניווט
כותרת זו בודקת תוכן עניינים, עוגנים וחיפוש בעברית. [חזרה](#multilingual-toc).

<a id="nav-hi"></a>
#### हिन्दी — नेविगेशन लक्ष्य
यह शीर्षक हिन्दी सामग्री-सूची, एंकर और खोज की जाँच करता है। [वापस](#multilingual-toc).

<a id="nav-th"></a>
#### ไทย — เป้าหมายการนำทาง
หัวข้อนี้ใช้ตรวจสอบสารบัญ จุดยึด และการค้นหาภาษาไทย [กลับ](#multilingual-toc).

### 10.6 Accessibility Notes


- Headings follow a logical hierarchy and are not used only for visual size.
- Links should have meaningful text rather than repeated “click here”.
- Tables include header rows and avoid excessive horizontal width in normal content.
- Keyboard focus must remain visible in interactive UI surrounding the rendered document.
- Diagram meaning should be summarized in prose when the diagram contains essential information.
- Color should not be the only way to distinguish states.

<a id="section-11"></a>

## 11. Markdown Feature Appendix

This appendix intentionally compresses common Markdown features into a small area so a regression run can
verify them without turning the entire handbook into a parser torture test. The examples are valid, ordinary
constructs that often appear in READMEs, architecture documents and operational runbooks.

### 11.1 Headings H1–H6

# Appendix heading level 1 — Åä 中文 Русский العربية 😀
## Appendix heading level 2 — Åä 中文 Русский العربية 😀
### Appendix heading level 3 — Åä 中文 Русский العربية 😀
#### Appendix heading level 4 — Åä 中文 Русский العربية 😀
##### Appendix heading level 5 — Åä 中文 Русский العربية 😀
###### Appendix heading level 6 — Åä 中文 Русский العربية 😀

### 11.2 Emphasis, Escaping and Inline Code

Normal, **bold**, *italic*, ***bold italic***, ~~strikethrough~~, `inline_code()`, and escaped \*literal asterisks\*.

Symbols: `& < > " ' / \ | { } [ ] ( ) # + - _ = ~ ^ % $ € £ ¥ ₹ ₪ ₩ © ® ™ ± × ÷ ≤ ≥ ≠ ∞ → ← ↔`

### 11.3 Quotes and Callouts

> A blockquote can contain **formatting**, `code`, [links](https://example.com), and Unicode: 中文 / العربية / 😀.
>> Nested blockquote level two.

> [!NOTE]
> Useful context.

> [!TIP]
> A practical recommendation.

> [!IMPORTANT]
> A requirement that affects correctness.

> [!WARNING]
> A condition that may cause degraded behavior.

> [!CAUTION]
> A condition that may cause data loss if ignored.

### 11.4 Lists and Tasks

- Architecture
  - Rendering
    - Markdown
    - Mermaid
  - Operations
    1. Detect
    2. Diagnose
    3. Recover
- [x] Parse headings
- [x] Render tables
- [x] Render Mermaid
- [ ] Verify platform-specific keyboard shortcuts

### 11.5 Tables

| Left | Center | Right | Unicode | Code |
|:---|:---:|---:|---|---|
| Row 1 | 10% | 1,000 | Åä 中文 عربي 😀 | `value_1` |
| Row 2 | 20% | 2,000 | Åä 中文 عربي 😀 | `value_2` |
| Row 3 | 30% | 3,000 | Åä 中文 عربي 😀 | `value_3` |
| Row 4 | 40% | 4,000 | Åä 中文 عربي 😀 | `value_4` |
| Row 5 | 50% | 5,000 | Åä 中文 عربي 😀 | `value_5` |
| Row 6 | 60% | 6,000 | Åä 中文 عربي 😀 | `value_6` |
| Row 7 | 70% | 7,000 | Åä 中文 عربي 😀 | `value_7` |
| Row 8 | 80% | 8,000 | Åä 中文 عربي 😀 | `value_8` |

### 11.6 Links, Anchors and Images

<a id="explicit-test-anchor"></a>
[Absolute](https://example.com) · [Relative](./docs/architecture.md) · [Anchor](#explicit-test-anchor) · <https://example.org/autolink>

![Remote image syntax example](https://dummyimage.com/320x80/eeeeee/333333.png&text=mdvu+image+test "Remote image")

Reference-style link: [Mermaid documentation][mermaid-docs].

[mermaid-docs]: https://mermaid.js.org/

### 11.7 HTML and Details

<details>
<summary><strong>Expandable implementation note</strong></summary>

Markdown inside details: **bold**, `code`, and a short list:

- first item
- second item

</details>

<table><tr><th>HTML cell</th><th>Unicode</th></tr><tr><td><kbd>⌘</kbd> + <kbd>K</kbd></td><td>中文 العربية 😀</td></tr></table>

<!-- HTML comments should not become visible document text. -->

### 11.8 Footnotes and Math Dialect Probes

A normal sentence may contain a footnote reference.[^rendering] Another paragraph contains inline math `$E = mc^2$`.

$$
R = \frac{successful\ renders}{total\ renders} \times 100\%
$$

[^rendering]: Footnote syntax is supported by some Markdown dialects and is included as a compatibility probe.

### 11.9 Code Fences

#### bash

```bash
set -euo pipefail
printf "release=%s\n" "1.4.0"
```

#### python

```python
def slug(title: str) -> str:
    return title.casefold().replace(" ", "-")

print(slug("Überblick 中文"))
```

#### typescript

```typescript
type Document = { id: string; locale: string };
const doc: Document = { id: "intro", locale: "fi" };
```

#### kotlin

```kotlin
data class Document(val id: String, val locale: String)
println(Document("intro", "ja"))
```

#### swift

```swift
struct Document { let id: String; let locale: String }
print(Document(id: "intro", locale: "ar"))
```

#### rust

```rust
fn main() { println!("Markdown + Mermaid 🦀"); }
```

#### sql

```sql
SELECT document_id, locale FROM releases WHERE published_at >= DATE '2026-09-01';
```

#### json

```json
{"id":"intro","locale":"zh-CN","published":true}
```

#### yaml

```yaml
document:
  id: intro
  locale: fi-FI
  published: true
```

#### xml

```xml
<document id="intro" lang="ja">技術文書</document>
```



### 11.10 Navigation, Automatic Slugs and Duplicate Headings

<a id="explicit-anchor-ascii"></a>
<a id="явный-якорь"></a>
<a id="显式锚点"></a>
<a id="مرساة-صريحة"></a>

Explicit-anchor links: [ASCII](#explicit-anchor-ascii) · [Русский](#явный-якорь) · [中文](#显式锚点) · [العربية](#مرساة-صريحة) · [Top](#top).

The next repeated headings intentionally exercise automatic duplicate-heading disambiguation.

#### Duplicate heading

First duplicate target. Expected conventional slug: `duplicate-heading`.

#### Duplicate heading

Second duplicate target. Expected conventional slug: `duplicate-heading-1`.

Navigation probes: [first duplicate](#duplicate-heading) · [second duplicate](#duplicate-heading-1).

#### Heading with punctuation: API / SDK + C++ & C# — Åä 中文 العربية 😀

This heading tests punctuation stripping, Unicode preservation, and navigation indexing.

### 11.11 Setext Headings, Thematic Breaks and Indented Code

Setext heading level 1
======================

Setext heading level 2 — Русский / 中文 / العربية
-------------------------------------------------

Three thematic-break spellings follow:

---

***

___

Indented code block:

    GET /v1/documents HTTP/1.1
    Accept: text/markdown
    X-Unicode: Åä 中文 العربية 😀

### 11.12 Reference Links, Autolinks and Entities

A [reference-style link][reference-docs], a [collapsed reference][], and an autolink <https://example.com/docs?q=Åä%20中文#fragment>.
Email autolink: <reader@example.org>. Escaped entities: `&amp; &lt; &gt; &quot; &#169; &#x1F680;`.

[reference-docs]: https://example.com/reference "Reference title"
[collapsed reference]: https://example.com/collapsed

### 11.13 Nested and Alternate Fences

Four-backtick fence containing a literal triple-backtick example:

````markdown
```mermaid
flowchart LR
    Source --> Render
```
````

Tilde fence:

~~~text
Literal backticks: ``` and Unicode: Русский 中文 العربية 👩🏽‍💻
~~~

### 11.14 Common Code-Fence Language Matrix

```java
record Document(String id, String title) {}
```

```go
package main
import "fmt"
func main() { fmt.Println("こんにちは / مرحبا") }
```

```c
#include <stdio.h>
int main(void) { puts("UTF-8 fixture"); return 0; }
```

```cpp
#include <iostream>
int main() { std::cout << "C++ → 中文"; }
```

```csharp
record Document(string Id, string Title);
```

```ruby
puts "Привет, мир"
```

```php
<?php echo "Olá, mundo"; ?>
```

```powershell
Write-Output "Hei maailma — ÅÄÖ"
```

```dockerfile
FROM alpine:3
RUN printf 'mdvu fixture\\n'
```

```toml
[viewer]
locale = "fi-FI"
diagrams = ["mermaid", "plantuml", "zenuml"]
```

```ini
[viewer]
theme=system
unicode=true
```

```css
.viewer > h2 { scroll-margin-top: 4rem; }
```

```html
<nav aria-label="Document navigation"><a href="#section-12">Mermaid</a></nav>
```

```diff
- renderer = "text-only"
+ renderer = "markdown+diagrams"
```

### 11.15 Inline HTML, Semantic Elements and Nested Details

<details>
<summary><strong>Nested details — открыть / 打开 / افتح</strong></summary>

<details>
<summary>Second level</summary>

Markdown inside HTML containers: **bold**, `code`, <kbd>⌘K</kbd>, <mark>highlight</mark>, H<sub>2</sub>O, x<sup>2</sup>, <del>old</del>, <ins>new</ins>.

</details>
</details>

Inline semantic HTML: <abbr title="HyperText Markup Language">HTML</abbr>, <time datetime="2026-09-05">5 Sep 2026</time>, <code>UTF-8</code>.


<a id="section-12"></a>

## 12. Mermaid Reference Appendix

The main chapters already use the most common diagram families. This appendix adds one compact, meaningful
example for specialized Mermaid grammars so the file can act as a broad compatibility fixture without
repeating the same diagram hundreds of times. The appendix targets Mermaid 11.17.2 and intentionally includes both established and newer diagram families. Each family appears only a small number of times so coverage stays broad without becoming a stress test.

#### 12.1 Legacy graph Alias

```mermaid
graph TD
    A[Legacy graph keyword] --> B{Compatible?}
    B -->|Yes| C[Render normally]
    B -->|No| D[Report locally]
```

#### 12.2 Styled Flowchart with Subgraphs

```mermaid
%%{init: {"theme":"neutral"}}%%
flowchart TB
    subgraph Source[Source]
      A[Markdown] --> B[Parser]
    end
    subgraph Render[Render]
      B --> C{Block type}
      C -->|Text| D[Native text]
      C -->|Mermaid| E[SVG]
    end
    D --> F[Document]
    E --> F
    classDef input fill:#eef,stroke:#447
    class A input
```

#### 12.3 Class Model

```mermaid
classDiagram
    class Document {
      +String id
      +String title
      +String locale
      +List~Block~ blocks
      +render()
    }
    class Block {
      <<interface>>
      +render()
    }
    class MarkdownBlock
    class MermaidBlock {
      +String source
      +renderSvg()
    }
    Document "1" *-- "1..*" Block
    Block <|.. MarkdownBlock
    Block <|.. MermaidBlock
```

#### 12.4 User Journey

```mermaid
journey
    title Reader opens a newly published handbook
    section Discover
      Search topic: 4: Reader
      Review result list: 4: Reader
    section Read
      Open document: 5: Reader
      Navigate headings: 5: Reader
      Inspect diagram: 4: Reader
    section Reuse
      Copy link: 5: Reader
      Save offline: 4: Reader
```

#### 12.5 Pie Chart

```mermaid
pie showData title Example document block mix
    "Prose" : 55
    "Tables and lists" : 15
    "Code" : 12
    "Mermaid" : 18
```

#### 12.6 Block Diagram

> Mermaid 11.17.2 benchmark syntax; expected to render in the target profile.

```mermaid
block-beta
    columns 4
    A["Source"] B("Parser") C(("Renderer")) D[("Cache")]
    A --> B
    B --> C
    C --> D
```

#### 12.7 Packet Diagram

```mermaid
packet
    title Simplified content envelope
    0-7: "Version"
    8-15: "Flags"
    16-31: "Header length"
    32-63: "Document ID hash"
    64-95: "Content length"
    96-127: "Checksum"
```

#### 12.8 Event Modeling

> Mermaid 11.17.2 benchmark syntax; expected to render in the target profile.

```mermaid
eventmodeling
    tf 01 ui Editor
    tf 02 cmd PublishDocument
    tf 03 evt DocumentPublished
    tf 04 rmo PublishedDocument
    tf 05 ui Viewer
```

#### 12.9 Tree View

> Mermaid 11.17.2 benchmark syntax; expected to render in the target profile.

```mermaid
treeView-beta
    ├── docs/
    │   ├── architecture.md
    │   ├── security.md
    │   └── operations.md
    ├── diagrams/
    │   └── platform.mmd
    ├── assets/
    │   └── logo.svg
    └── README.md
```

#### 12.10 Venn Diagram

> Mermaid 11.17.2 benchmark syntax; expected to render in the target profile.

```mermaid
venn-beta
    title "Viewer compatibility"
    set Markdown["Markdown"]:80
    set Mermaid["Mermaid"]:70
    set Unicode["Unicode"]:90
    union Markdown,Mermaid["Fenced diagrams"]:25
    union Mermaid,Unicode["Unicode labels"]:20
    union Markdown,Unicode["Multilingual prose"]:35
    union Markdown,Mermaid,Unicode["Production document"]:15
```

#### 12.11 Wardley Map

> Mermaid 11.17.2 benchmark syntax; expected to render in the target profile.

```mermaid
wardley-beta
    title Knowledge Delivery Stack
    size [900, 520]
    evolution Genesis@0.25 -> Custom@0.5 -> Product@0.75 -> Commodity@1.0
    anchor Reader [0.95, 0.90]
    component "Viewer" [0.80, 0.65] (build)
    component "Markdown parser" [0.62, 0.85] (buy)
    component "Mermaid renderer" [0.55, 0.76] (buy)
    component "Unicode fonts" [0.35, 0.95] (market)
    Reader -> "Viewer"
    "Viewer" -> "Markdown parser"
    "Viewer" -> "Mermaid renderer"
    "Mermaid renderer" -> "Unicode fonts"
```

#### 12.12 Cynefin View

> Mermaid 11.17.2 benchmark syntax; expected to render in the target profile.

```mermaid
cynefin-beta
    title Documentation Platform Problems
    complex
      "Mixed bidi rendering"
      "Unexpected content interaction"
    complicated
      "SVG performance profiling"
      "Search ranking tuning"
    clear
      "Broken relative link"
      "Missing asset"
    chaotic
      "Renderer process crash"
    confusion
      "Unclassified failure"
```

#### 12.13 C4 Context-to-Component Coverage

```mermaid
C4Context
    title Compact C4 Context Probe
    Person(reader, "Reader")
    System(viewer, "Viewer", "Renders documents")
    System_Ext(api, "Knowledge API", "Serves published content")
    Rel(reader, viewer, "Reads")
    Rel(viewer, api, "Loads", "HTTPS")
```

#### 12.14 C4 Component Probe

```mermaid
C4Component
    title Compact C4 Component Probe
    Container_Boundary(core, "Viewer Core") {
      Component(parser, "Parser", "Markdown", "Parses blocks")
      Component(renderer, "Diagram Renderer", "Mermaid", "Produces SVG")
    }
    Rel(parser, renderer, "Delegates Mermaid blocks")
```

#### 12.15 Radar / Specialized Coverage

> Mermaid 11.17.2 benchmark syntax; expected to render in the target profile.

```mermaid
radar-beta
    title Normal-document validation profile
    axis prose["Prose"], tables["Tables"], code["Code"], diagrams["Diagrams"], i18n["I18N"]
    curve fixture["Complete fixture"]{95, 85, 85, 90, 85}
    min 0
    max 100
    ticks 5
```



#### 12.16 Flowchart Feature Probe — Shapes, Links, Classes and Markdown Labels

```mermaid
flowchart LR
    %% comment should be ignored
    A@{ shape: rounded, label: "`**Markdown** label 🚀`" }
    B{Decision?}
    C[(Database)]
    D((Circle))
    E[/Input / Output/]
    F{{Hexagon}}
    G>Asymmetric]
    A -->|normal| B
    B -.->|dotted| C
    B ==>|thick| D
    C --- E
    D --> F
    E --> G
    subgraph Unicode["Unicode / 多语言 / العربية"]
      U1["Русский"] --> U2["日本語"] --> U3["العربية"]
    end
    G --> U1
    classDef accent fill:#eef,stroke:#446,stroke-width:2px
    class A,U1,U2,U3 accent
    linkStyle 1 stroke-width:3px
```

#### 12.17 Sequence Control Structures — alt / opt / loop / par / critical / break

```mermaid
sequenceDiagram
    autonumber
    box Client side
      actor Reader
      participant Viewer
    end
    box Platform
      participant API
      participant Cache
    end
    Reader->>Viewer: Open document
    activate Viewer
    Viewer->>API: GET /document
    alt cache hit
      API->>Cache: read
      Cache-->>API: content
    else cache miss
      API->>API: load release
    end
    opt diagrams present
      loop each diagram
        Viewer->>Viewer: enqueue render
      end
    end
    par text
      Viewer-->>Reader: show text
    and diagrams
      Viewer-->>Reader: progressively insert SVG
    end
    critical publish consistency
      API->>Cache: update immutable release
    option transient failure
      API->>API: retry safely
    end
    break user closes document
      Reader->>Viewer: close
    end
    deactivate Viewer
```

#### 12.18 Class Relations, Generics and Annotations

```mermaid
classDiagram
    direction LR
    class Renderer~T~ {
      <<interface>>
      +render(T source) String
    }
    class MermaidRenderer {
      +render(String source) String
    }
    class PlantUMLRenderer {
      +render(String source) String
    }
    class Document {
      +String id
      +List~Block~ blocks
    }
    class Block {
      <<abstract>>
      +String language
    }
    Renderer~String~ <|.. MermaidRenderer
    Renderer~String~ <|.. PlantUMLRenderer
    Document "1" *-- "1..*" Block : contains
    Block o-- Renderer~String~ : selects
```

#### 12.19 Composite State and Concurrency

```mermaid
stateDiagram-v2
    [*] --> Loading
    Loading --> Ready
    state Ready {
      [*] --> TextVisible
      state "Diagram work" as DiagramWork {
        [*] --> Queued
        Queued --> Rendering
        Rendering --> Complete
        Complete --> [*]
      }
      TextVisible --> DiagramWork
      --
      [*] --> NavigationReady
      NavigationReady --> SearchReady
    }
    Ready --> Closed
    Closed --> [*]
```

#### 12.20 ER Cardinality Matrix

```mermaid
erDiagram
    USER ||--o{ DOCUMENT : authors
    DOCUMENT ||--|{ RELEASE : publishes
    RELEASE ||--o{ ASSET : references
    RELEASE ||--|| MANIFEST : owns
    USER }o--o{ GROUP : belongs_to
    GROUP }|--|{ POLICY : receives
    USER {
      uuid id PK
      string display_name
    }
    DOCUMENT {
      uuid id PK
      string locale
    }
```

#### 12.21 Gantt Status and Milestone Probe

```mermaid
gantt
    title Functional benchmark release
    dateFormat YYYY-MM-DD
    axisFormat %d %b
    section Authoring
    Draft content       :done, a1, 2026-09-01, 2d
    Review              :active, a2, after a1, 2d
    section Validation
    Markdown checks     :crit, a3, after a2, 1d
    Diagram checks      :a4, after a2, 1d
    Release             :milestone, m1, after a3, 0d
```

#### 12.22 GitGraph Branch, Merge and Tags

```mermaid
gitGraph LR:
    commit id: "init"
    branch feature/navigation
    checkout feature/navigation
    commit id: "toc"
    commit id: "anchors"
    checkout main
    merge feature/navigation tag: "v1.0.0"
    branch hotfix
    checkout hotfix
    commit id: "rtl-fix"
    checkout main
    merge hotfix tag: "v1.0.1"
```

#### 12.23 ZenUML Advanced Control Flow

```mermaid
zenuml
    @Actor Reader
    Reader->Viewer: open(document)
    Viewer->Parser: parse(markdown)
    if(hasDiagrams) {
      while(nextDiagram) {
        Viewer->Renderer: render(source)
        Renderer->Viewer: result
      }
    } else {
      Viewer->Viewer: textOnly()
    }
    Viewer->Reader: display(document)
```

#### 12.24 Diagram Hyperlink and Tooltip Probe

```mermaid
flowchart LR
    A[Top] --> B[Mermaid appendix]
    B --> C[PlantUML appendix]
    click A "#top" "Go to top"
    click B "#section-12" "Mermaid section"
    click C "#section-13" "PlantUML section"
```



`MDVU-COMPLETE-MIDDLE`

<a id="section-13"></a>

## 13. PlantUML 1.2026.6 Reference Appendix

This section targets **PlantUML 1.2026.6 stable**. It intentionally covers every diagram family listed on the
current PlantUML home page, plus the current Board and Wire start-tag families. Examples are compact and use
normal documentation content rather than synthetic large graphs. Unless a subsection says otherwise, each
block is expected to render successfully in the target benchmark.

> [!IMPORTANT]
> `plantuml` is the canonical fence in this fixture. One `puml` fence is included explicitly as an alias probe.
> PlantUML-specific `@start...` / `@end...` tags remain inside the fence because they determine the actual
> PlantUML diagram family.

### 13.1 UML Diagram Families

#### 13.1.1 Sequence Diagram

```plantuml
@startuml
title Publication sequence — Русский / 中文 / العربية 🚀
autonumber
actor Reader
participant Viewer
participant "Knowledge API" as API
database Cache
Reader -> Viewer : Open document
activate Viewer
Viewer -> API : GET /document
activate API
alt cached
  API -> Cache : lookup(id)
  Cache --> API : Markdown
else not cached
  API -> API : load immutable release
end
API --> Viewer : UTF-8 Markdown
Viewer --> Reader : Rendered document ✅
deactivate API
deactivate Viewer
note over Viewer,API
  Unicode: ÅÄÖ · Русский · 中文 · العربية · 日本語
end note
@enduml
```

#### 13.1.2 Use Case Diagram

```plantuml
@startuml
left to right direction
actor Reader
actor Author
rectangle "mdvu" {
  usecase "Open Markdown" as UC1
  usecase "Navigate headings" as UC2
  usecase "Render diagrams" as UC3
  usecase "Search document" as UC4
}
Reader --> UC1
Reader --> UC2
Reader --> UC4
Author --> UC1
UC1 .> UC3 : <<include>>
@enduml
```

#### 13.1.3 Class Diagram

```plantuml
@startuml
interface Renderer<T> {
  +render(source: T): String
}
abstract class Block {
  +language: String
}
class MermaidBlock
class PlantUMLBlock
class Document {
  +id: String
  +title: String
}
Renderer <|.. MermaidBlock
Renderer <|.. PlantUMLBlock
Block <|-- MermaidBlock
Block <|-- PlantUMLBlock
Document "1" *-- "1..*" Block
@enduml
```

#### 13.1.4 Object Diagram

```plantuml
@startuml
object document {
  id = "architecture/overview"
  locale = "fi-FI"
  title = "Arkkitehtuuri"
}
object release {
  version = "2026.09"
  immutable = true
}
object manifest {
  encoding = "UTF-8"
  diagrams = "Mermaid + PlantUML"
}
document --> release
release --> manifest
@enduml
```

#### 13.1.5 Activity Diagram — Current Syntax

```plantuml
@startuml
start
:Open Markdown file;
if (front matter present?) then (yes)
  :Parse metadata;
endif
:Parse Markdown blocks;
if (diagram block?) then (yes)
  :Dispatch to diagram renderer;
else (no)
  :Render native Markdown;
endif
:Build navigation index;
stop
@enduml
```

#### 13.1.6 Activity Diagram — Legacy Syntax Probe

```puml
@startuml
(*) --> "Open document"
--> "Parse Markdown"
if "Has diagrams?" then
  -->[yes] "Render diagrams"
  --> "Display"
else
  ->[no] "Display"
endif
--> (*)
@enduml
```

#### 13.1.7 Component Diagram

```plantuml
@startuml
package "Viewer" {
  [Document Loader] as Loader
  [Markdown Parser] as Parser
  [Navigation Index] as Nav
  [Diagram Router] as Router
}
component "Mermaid 11.17.2" as Mermaid
component "PlantUML 1.2026.6" as PUML
Loader --> Parser
Parser --> Nav
Parser --> Router
Router --> Mermaid
Router --> PUML
@enduml
```

#### 13.1.8 Deployment Diagram

```plantuml
@startuml
node "Desktop" as desktop {
  artifact "test-complete.md" as doc
  component "mdvu" as viewer
}
node "Diagram Runtime" as runtime {
  component "Mermaid" as mermaid
  component "PlantUML" as plantuml
}
database "Local cache" as cache
doc --> viewer
viewer --> mermaid
viewer --> plantuml
viewer --> cache
@enduml
```

#### 13.1.9 State Diagram

```plantuml
@startuml
[*] --> Loading
Loading --> Ready : parsed
Loading --> Error : invalid input
Ready --> Rendering : diagram pending
Rendering --> Ready : diagram complete
Rendering --> Error : renderer failure
Error --> Ready : recoverable block skipped
Ready --> Closed
Closed --> [*]
@enduml
```

#### 13.1.10 Timing Diagram

```plantuml
@startuml
robust "Viewer" as V
concise "Reader" as R
@0
R is Idle
V is Loading
@100
R is Waiting
V is Parsing
@220
V is Rendering
@420
V is Ready
R is Reading
@700
R is Idle
@enduml
```

### 13.2 PlantUML Non-UML Diagram Families

#### 13.2.1 JSON Data

```plantuml
@startjson
{
  "document": {
    "id": "unicode-demo",
    "title": "Русский / 中文 / العربية 🚀",
    "locales": ["en", "fi", "ru", "zh-CN", "ar"],
    "valid": true
  }
}
@endjson
```

#### 13.2.2 YAML Data

```plantuml
@startyaml
document:
  id: unicode-demo
  title: "Åä Русский 中文 العربية 🚀"
  locales:
    - en
    - fi
    - ru
    - zh-CN
    - ar
  valid: true
@endyaml
```

#### 13.2.3 EBNF Diagram

```plantuml
@startebnf
title Compact Markdown heading grammar
heading = atx_heading | setext_heading;
atx_heading = "#", {"#"}, " ", text;
setext_heading = text, ("=" | "-");
text = ? Unicode text ?;
@endebnf
```

#### 13.2.4 Regex Diagram

```plantuml
@startregex
!option language en
!option useDescriptiveNames true
^(?<scheme>https?)://(?<host>[\w.-]+)(?<path>/[^\s]*)?$
@endregex
```

#### 13.2.5 Network Diagram (nwdiag)

```plantuml
@startnwdiag
network dmz {
  address = "203.0.113.0/24"
  gateway [address = "203.0.113.1"];
  viewer [address = "203.0.113.20"];
}
network internal {
  address = "10.0.0.0/24"
  viewer [address = "10.0.0.20"];
  cache [address = "10.0.0.30", shape = database];
}
@endnwdiag
```

#### 13.2.6 Salt Wireframe

```plantuml
@startsalt
{
  {+ mdvu Viewer
    File | "test-complete.md"
    Search | "Unicode Mermaid PlantUML"
    [Open] | [Reload]
    [X] Table of contents
    [X] Diagram rendering
    Locale | ^English^Русский^中文^العربية^
  }
}
@endsalt
```

#### 13.2.7 ArchiMate Diagram

```plantuml
@startuml
archimate #Business "Reader" as reader <<business-actor>>
archimate #Application "mdvu" as app <<application-component>>
archimate #Technology "Diagram Runtime" as runtime <<technology-device>>
reader --> app : reads
app --> runtime : renders
@enduml
```

#### 13.2.8 SDL Shapes

```plantuml
@startuml
start
:Receive Markdown; <<input>>
:Parse document; <<procedure>>
:Load renderer; <<load>>
:Render output; <<task>>
:Store cache; <<save>>
:Display document; <<output>>
stop
@enduml
```

#### 13.2.9 Ditaa Diagram

> Upstream PlantUML documents Ditaa as PNG-only; this fixture still includes it because it is an official
> PlantUML diagram family and therefore useful for end-to-end renderer capability testing.

```plantuml
@startditaa
+------------+     +-------------+     +-----------+
| Markdown   | --> | mdvu        | --> | Document  |
| source {d} |     | renderer    |     | view      |
+------------+     +------+------+     +-----------+
                         |
                         v
                    +----+-----+
                    | Cache {s}|
                    +----------+
@endditaa
```

#### 13.2.10 Gantt Diagram

```plantuml
@startgantt
Project starts the 2026-09-01
[Fixture draft] lasts 2 days
[Review] starts at [Fixture draft]'s end and lasts 2 days
[Renderer validation] starts at [Review]'s end and lasts 2 days
[Release] happens at [Renderer validation]'s end
@endgantt
```

#### 13.2.11 Chronology Diagram

```plantuml
@startchronology
title mdvu fixture chronology
[Draft] happens on 2026-09-01 09:00:00
[Review] happens on 2026-09-03 12:00:00
[Benchmark] happens on 2026-09-05 18:00:00
@endchronology
```

#### 13.2.12 MindMap Diagram

```plantuml
@startmindmap
* mdvu
** Markdown
*** Navigation
*** Tables
*** Unicode
** Mermaid
*** 11.17.2
** PlantUML
*** 1.2026.6
** Languages
*** Русский
*** 中文
*** العربية
@endmindmap
```

#### 13.2.13 WBS Diagram

```plantuml
@startwbs
* Complete functional validation
** Markdown
*** Blocks
*** Inline syntax
*** Navigation
** Diagrams
*** Mermaid
*** ZenUML
*** PlantUML
** Unicode
*** LTR
*** RTL
*** CJK
@endwbs
```

#### 13.2.14 Standalone AsciiMath

```plantuml
@startmath
f(x)=sum_(n=0)^oo (x^n)/(n!)
@endmath
```

#### 13.2.15 Standalone JLaTeXMath

```plantuml
@startlatex
\sum_{i=0}^{n-1} (a_i + b_i^2) = \int_0^1 f(x)\,dx
@endlatex
```

#### 13.2.16 Information Engineering Diagram

```plantuml
@startuml
entity DOCUMENT {
  * id : UUID
  --
  * title : TEXT
  locale : TEXT
}
entity RELEASE {
  * id : UUID
  --
  * version : TEXT
}
DOCUMENT ||--o{ RELEASE : publishes
@enduml
```

#### 13.2.17 Chen ER Diagram

```plantuml
@startchen
entity Document {
  ID <<key>>
  Title
}
entity Release {
  ID <<key>>
  Version
}
relationship Publishes {
}
Publishes -1- Document
Publishes -N- Release
@endchen
```

#### 13.2.18 Chart Diagram

```plantuml
@startchart
h-axis [Markdown, Mermaid, PlantUML, Unicode]
v-axis "Coverage" 0 --> 100
bar "Functional fixture" [95, 100, 100, 95]
line "Smoke fixture" [60, 35, 20, 45]
legend right
@endchart
```

#### 13.2.19 Files Tree Diagram

```plantuml
@startfiles
/README.md
/docs/architecture.md
/docs/security.md
/docs/локализация.md
/diagrams/mermaid.mmd
/diagrams/plantuml.puml
/assets/图标.svg
/tests/test-complete.md
@endfiles
```

### 13.3 Additional Current PlantUML Start-Tag Families

#### 13.3.1 Board Diagram

```plantuml
@startboard
A1
+U1.1
++S1 R1
++S1 R2
+U1.2
A2
@endboard
```

#### 13.3.2 Wire Diagram

```plantuml
@startwire
* Viewer
* sidebar [180x420]
* document [640x420]
* status [820x40]
@endwire
```

### 13.4 PlantUML Feature Probes

#### 13.4.1 Hyperlinks, Tooltips, Creole and Unicode

```plantuml
@startuml
title **Rich text** / //italic// / 中文 / العربية / 😀
actor "Reader 👩🏽‍💻" as Reader
component "[[https://plantuml.com PlantUML docs]]" as Docs
component "[[#top Back to document top]]" as Top
Reader --> Docs : Open [[https://plantuml.com sequence docs]]
Reader --> Top : Internal navigation probe
note right of Reader
  **Bold**, //italic//, ""monospace""
  Русский · 中文 · العربية · 日本語
end note
legend right
  |= Format |= Expected |
  | Unicode | preserved |
  | Links | clickable/sanitized |
endlegend
@enduml
```

#### 13.4.2 Style and Handwritten Option

```plantuml
@startuml
!option handwritten true
<style>
componentDiagram {
  component {
    LineThickness 1.5
  }
}
</style>
[Markdown] --> [Renderer]
[Renderer] --> [SVG]
@enduml
```

#### 13.4.3 Preprocessor and Standard Library Include

```plantuml
@startuml
!define PRODUCT mdvu
!$version = "1.2026.6"
!include <archimate/Archimate>
title PRODUCT + " — stdlib / preprocessor probe"
Application_Component(app, "mdvu")
Technology_Service(runtime, "PlantUML " + $version)
Rel_Serving_Up(runtime, app, "renders")
@enduml
```

#### 13.4.4 Teoz Sequence Engine

```plantuml
@startuml
!pragma teoz true
participant A
participant B
participant C
A -> B : request
& B -> C : parallel request
B --> A : response
C --> B : response
@enduml
```

[Back to top](#top)


<a id="section-14"></a>

## 14. Code and Configuration Appendix

A realistic technical document usually contains configuration fragments next to explanatory text. These
examples are small enough to read but diverse enough to exercise syntax highlighting, punctuation and
indentation. They do not represent secrets or production endpoints.

### 14.1 Application Configuration

```yaml
viewer:
  theme: system
  mermaid:
    enabled: true
    securityLevel: strict
  cache:
    maxDocuments: 200
  locales:
    - en
    - fi
    - sv
    - ru
    - ja
    - ar
```

### 14.2 Release Manifest

```json
{
  "release": "2026.09",
  "git": "2f6c4b1",
  "documents": 148,
  "renderer": {
    "markdown": "gfm-compatible",
    "mermaid": "11.17.2",
    "plantuml": "1.2026.6"
  },
  "integrity": "sha256:example"
}
```

### 14.3 Example SQL Migration

```sql
CREATE TABLE document_release (
    id              TEXT PRIMARY KEY,
    document_id     TEXT NOT NULL,
    locale          TEXT NOT NULL,
    content_sha256  TEXT NOT NULL,
    published_at    TIMESTAMP NOT NULL
);
CREATE INDEX idx_release_document ON document_release(document_id, published_at DESC);
```

### 14.4 Example Shell Validation

```bash
#!/usr/bin/env bash
set -euo pipefail
file="${1:-test-complete.md}"
printf 'lines=%s\n' "$(wc -l < "$file")"
printf 'bytes=%s\n' "$(wc -c < "$file")"
grep -q 'MDVU-COMPLETE-END' "$file"
```



### 14.5 Benchmark Reference Links

These links are also external-link rendering tests:

- [Mermaid syntax reference](https://mermaid.js.org/intro/syntax-reference.html)
- [Mermaid flowchart syntax](https://mermaid.js.org/syntax/flowchart.html)
- [Mermaid C4 syntax](https://mermaid.js.org/syntax/c4.html)
- [PlantUML home / diagram catalog](https://plantuml.com/)
- [PlantUML chart diagrams](https://plantuml.com/chart-diagram)
- [PlantUML JSON](https://plantuml.com/json)
- [PlantUML YAML](https://plantuml.com/yaml)

[Back to top](#top)


<a id="section-15"></a>

## 15. Markdown Dialects & Ecosystem Extensions

This section is intentionally **dialect-rich but not stress-heavy**. Each family gets a compact, recognizable
sample of its native syntax. Unsupported constructs should remain local and readable rather than breaking the
rest of the document.

> [!NOTE]
> This is a **target benchmark**, not a promise that every Markdown engine interprets every syntax identically.
> When an extension is unsupported, the expected fallback is readable source text or a block-local diagnostic.

<a id="ext-gfm"></a>

### 15.1 GitHub Flavored Markdown / GitHub Markdown

GitHub-oriented behavior extends CommonMark with tables, task lists, strikethrough, autolinks and platform
features such as alerts and footnotes.

#### GFM table, task list and strikethrough

| Feature | Example | Expected |
|---|---|---|
| Strikethrough | ~~obsolete~~ | deleted text |
| Autolink | https://example.com/path?q=mdvu | clickable URL |
| Task | [x] complete | checked |
| Task | [ ] pending | unchecked |

- [x] Render Markdown
- [x] Render Mermaid
- [x] Render PlantUML
- [ ] Verify every extension family

#### GitHub alerts

> [!NOTE]
> Note alert with **Markdown**, `code`, 中文 and emoji 📝.

> [!TIP]
> Tip alert.

> [!IMPORTANT]
> Important alert.

> [!WARNING]
> Warning alert.

> [!CAUTION]
> Caution alert.

#### Footnotes

GitHub-style footnote reference.[^github-footnote]

[^github-footnote]: Footnote body with a [link](https://example.com), `code`, Русский, 中文 and العربية.

#### GitHub reference-like text probes

`@octocat` · `#123` · `owner/repository#456` · `SHA deadbeef` · `:rocket:` · `:warning:`

These are platform-sensitive references/emoji aliases and may remain literal in a standalone viewer.

---

<a id="ext-obsidian"></a>

### 15.2 Obsidian Markdown

#### Wikilinks

[[Architecture Overview]]

[[Architecture Overview|Architecture alias]]

[[Architecture Overview#Deployment]]

[[#Local Obsidian Heading]]

[[Projects/Renderer Compatibility]]

#### Block references

This paragraph is a block-reference target for the Obsidian fixture. ^mdvu-block-target

Link to the block: [[test-complete-extensions#^mdvu-block-target]]

A structured block follows:

> A quoted block that receives a separate block identifier.

^mdvu-quoted-block

Reference: [[test-complete-extensions#^mdvu-quoted-block]]

#### Embeds / transclusion

![[Architecture Overview]]

![[Architecture Overview#Deployment]]

![[test-complete-extensions#^mdvu-block-target]]

![[diagram.png]]

![[diagram.png|320]]

![[diagram.png|320x180]]

![[document.pdf]]

![[document.pdf#page=3]]

![[audio-example.ogg]]

![[canvas-example.canvas]]

#### Obsidian properties

The document-level YAML front matter at the beginning of this file is the real metadata probe. The following
property-shaped fragment is intentionally shown in a fenced block because YAML properties are only document
metadata when placed at the beginning:

```yaml
tags:
  - mdvu
  - benchmark
aliases:
  - Complete Renderer Benchmark
cssclasses:
  - wide-page
status: active
score: 9.5
published: true
review_date: 2026-09-05
```

#### Obsidian tags

#mdvu #renderer #markdown/extensions #unicode/rtl #diagram-as-code

#### Obsidian comments

%%
This is an Obsidian comment.
A supporting renderer may hide the complete region.
The source includes **Markdown-looking** content and [[wikilinks]].
%%

Visible text after the Obsidian comment.

#### Obsidian callouts — standard families

> [!note] Note
> Basic note callout.

> [!abstract] Abstract / summary / tldr
> Compact summary.

> [!info] Info
> Informational callout.

> [!todo] Todo
> - [x] Existing coverage
> - [ ] Future coverage

> [!tip] Tip / hint / important
> Helpful guidance.

> [!success] Success / check / done
> Validation succeeded.

> [!question] Question / help / faq
> Can the renderer fold this structure?

> [!warning] Warning / caution / attention
> Potential compatibility gap.

> [!failure] Failure / fail / missing
> Example failure state.

> [!danger] Danger / error
> High-severity state.

> [!bug] Bug
> Reproducible renderer defect.

> [!example] Example
> A compact example.

> [!quote] Quote / cite
> “Portable source matters.”

#### Foldable and nested Obsidian callouts

> [!faq]- Collapsed by default
> Hidden until expanded in a supporting renderer.
>
> > [!tip]+ Nested and expanded
> > Nested **Markdown**, `code`, [[Wikilink]] and emoji ✅.

#### Obsidian math

Inline math: $E = mc^2$ and $\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$.

$$
\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}
$$

#### Local Obsidian Heading

Target for `[[#Local Obsidian Heading]]`.

---

<a id="ext-gitlab"></a>

### 15.3 GitLab Flavored Markdown

#### GitLab table of contents tokens

[[_TOC_]]

[TOC]

#### Description list

Renderer
: Parses and displays the document.
: Preserves unsupported source locally.

Diagram engine
: Mermaid or PlantUML.

#### Three-state task list

- [x] Complete
- [~] Inapplicable
- [ ] Incomplete

#### GitLab multiline blockquote

>>>
This is a GitLab fenced multiline blockquote.

It contains multiple paragraphs, **formatting**, `code`, 中文 and العربية.
>>>

#### GitLab inline diff

- {+ addition using braces +}
- [+ addition using brackets +]
- {- deletion using braces -}
- [- deletion using brackets -]

#### GitLab references

`#123` · `!456` · `@username` · `group/project#789` · `group/project!321` · `abcdef12`

#### Color chips

`#FF00AA` · `rgb(12, 34, 56)` · `hsl(210, 50%, 40%)`

#### GitLab include directives

::include{file=chapter1.md}

::include{file=https://example.org/shared-section.md}

Inside a code fence:

```javascript
::include{file=javascript_code.js}
```

#### GitLab placeholders

`%{gitlab_server}` · `%{project_path}` · `%{project_name}` · `%{default_branch}` · `%{commit_sha}` · `%{latest_tag}`

#### GitLab JSON table

```json:table
{
  "items": [
    {"feature": "Markdown", "status": "supported"},
    {"feature": "Mermaid", "status": "target"},
    {"feature": "PlantUML", "status": "target"}
  ],
  "fields": ["feature", "status"],
  "caption": "Renderer capability sample"
}
```

#### GitLab media dimensions syntax

![Missing test image](./assets/missing-test-image.png "Dimension probe"){width=160 height=90px}

#### GitLab math variants

Inline: $`a^2+b^2=c^2`$

Display:

$$
f(x)=\frac{1}{1+e^{-x}}
$$

```math
\nabla \cdot \vec{E} = \frac{\rho}{\varepsilon_0}
```

---

<a id="ext-pandoc"></a>

### 15.4 Pandoc Markdown

#### Definition list

Term A
: Definition A with **emphasis**.
: Second definition for the same term.

Term B
: Definition B.

#### Header attributes

#### Pandoc attributed heading {#pandoc-heading .benchmark data-kind="extension"}

Link to the explicit Pandoc-style identifier: [Pandoc attributed heading](#pandoc-heading).

#### Inline attributes / bracketed spans

A [small-cap candidate]{.smallcaps} and a [language span]{lang=fi} containing “Hyvää päivää”.

#### Fenced Div

::: {.note #pandoc-fenced-div data-source="pandoc"}
This is a Pandoc fenced Div containing **Markdown**, a list, and a table.

- alpha
- beta
- gamma

| key | value |
|---|---|
| mode | fenced div |
| unicode | Ω Ж 中 ع 😀 |
:::

#### Fenced code attributes

```{.python #pandoc-code .numberLines startFrom="100"}
def render(document: str) -> str:
    return f"Rendered: {document}"
```

#### Raw attribute blocks and spans

```{=html}
<section data-dialect="pandoc"><strong>Raw HTML block candidate</strong></section>
```

Inline raw candidate: `<mark>raw html</mark>`{=html}

#### Citations

Narrative citation: @doe2026.

Parenthetical citation: [@doe2026, pp. 10-12; @smith2025].

Citation with prefix/suffix: [see @unicode-standard, chap. 5].

#### Line blocks

| First line preserves line structure
| Second line follows directly
| 第三行 contains CJK
| السطر الرابع يحتوي العربية

#### Superscript and subscript

Pandoc-style examples: H~2~O, CO~2~, 2^10^, x^n^.

#### Grid table

+----------------------+---------------------------+
| Feature              | Result                    |
+======================+===========================+
| Grid table           | Pandoc-style structure    |
+----------------------+---------------------------+
| Unicode              | Русский 中文 العربية 😀   |
+----------------------+---------------------------+

#### Image/link attributes

[Example with attributes](https://example.com){#pandoc-link .external target="_blank"}

![Missing image with attributes](./assets/missing-pandoc.png){#pandoc-image width=160px height=90px}

---

<a id="ext-extra-mmd"></a>

### 15.5 Markdown Extra, MultiMarkdown and CriticMarkup

#### Markdown Extra attribute syntax

### Markdown Extra heading
{: #markdown-extra-heading .extra-class }

A paragraph with an attached attribute list.
{: .lead #extra-paragraph }

#### Extra-style definition list

Markdown Extra
: Historically popular extension set.

MultiMarkdown
: Adds metadata, cross references, citations and other publishing features.

#### Abbreviation-like definition

*[HTML]: Hyper Text Markup Language
*[UTF-8]: Unicode Transformation Format, 8-bit

HTML and UTF-8 appear here as abbreviation candidates.

#### MultiMarkdown cross-reference probes

[Renderer Architecture][renderer-architecture]

[renderer-architecture]: #section-3 "Architecture section"

Table reference candidate: [Table: Capability Matrix]

Figure reference candidate: [Figure 1][]

![Figure 1: Placeholder figure](./assets/missing-figure.svg)

#### MultiMarkdown citation-like probes

A publishing claim [#MarkdownCitation].

[#MarkdownCitation]: Doe, Jane. *Portable Technical Documentation*. 2026.

#### CriticMarkup

{++inserted text++}

{--deleted text--}

{~~old wording~>new wording~~}

{==highlighted text==}

{>>editorial comment: verify this renderer behavior<<}

---

<a id="ext-kramdown"></a>

### 15.6 kramdown and Jekyll-style Markdown

#### Inline Attribute Lists

This paragraph has a kramdown block IAL.
{: #kramdown-paragraph .notice data-test="ial" }

[Attributed link](https://example.com){: .external rel="nofollow" }

*Attributed emphasis*{: .emphasis-class }

#### kramdown extension tags

{::comment}
This text is inside a kramdown comment extension.
It may disappear in a supporting parser.
{:/comment}

{::options parse_block_html="true" /}

#### kramdown footnote

A kramdown-compatible footnote reference.[^kramdown-note]

[^kramdown-note]: kramdown footnote body.

#### Jekyll Liquid variables and tags

Site variable probe: {{ site.title }}

Page variable probe: {{ page.url }}

{% assign renderer = "mdvu" %}

{% if renderer == "mdvu" %}
Renderer-specific branch candidate.
{% endif %}

{% include navigation.md %}

{% highlight ruby linenos %}
puts "Hello from Jekyll/Liquid highlight"
{% endhighlight %}

#### Jekyll post/reference syntax probes

{% link docs/architecture.md %}

{% post_url 2026-09-05-renderer-benchmark %}

---

<a id="ext-mkdocs"></a>

### 15.7 Python-Markdown, PyMdown Extensions and Material for MkDocs

This subsection intentionally exercises the extension families commonly enabled together by Material for MkDocs.

#### Admonitions

!!! note "Python-Markdown admonition"
    Content under an `!!! note` block.

!!! warning
    Warning without a custom title.

??? info "Collapsible details-style admonition"
    This body is collapsible in supporting PyMdown configurations.

???+ success "Expanded collapsible admonition"
    Expanded by default in supporting configurations.

#### Content tabs

=== "Python"

    ```python
    print("tab: Python")
    ```

=== "Kotlin"

    ```kotlin
    println("tab: Kotlin")
    ```

=== "日本語"

    タブ内の日本語コンテンツ。

#### Attribute lists

A paragraph carrying Python-Markdown attributes.
{ #python-md-attrs .annotate data-mode="benchmark" }

#### Annotation

Annotated sentence with a marker. (1)
{ .annotate }

1.  Annotation body with `code`, **formatting**, 中文 and emoji 🧭.

#### Abbreviations

The API returns UTF-8 JSON.

*[API]: Application Programming Interface
*[JSON]: JavaScript Object Notation

#### Mark / Caret / Tilde

==highlight / mark==

^^underline candidate^^

^superscript candidate^

~subscript candidate~

~~strikethrough candidate~~

#### Keyboard keys

++ctrl+alt+del++ · ++cmd+shift+p++ · ++enter++

#### Emoji shortcodes and icon shortcodes

:smile: :rocket: :warning: :material-home: :material-language-markdown:

#### Smart symbols

(c) (tm) (r) --> <-- <--> =/= +/- 1/2 1/4 3/4

#### Highlighted fenced code with metadata

```python title="renderer.py" linenums="1" hl_lines="2 4"
def open_document(path):
    text = path.read_text(encoding="utf-8")
    blocks = parse_markdown(text)
    return render(blocks)
```

#### SuperFences custom-style block

```text
A SuperFences-capable parser can attach attributes, titles, annotations,
line numbers and other metadata to fenced blocks.
```

#### Snippets include syntax

--8<-- "includes/common.md"

--8<-- [start:renderer]
This region is between snippet markers.
--8<-- [end:renderer]

#### Markdown inside HTML

<div class="md-in-html" markdown>

### Heading inside HTML container

- Markdown list
- **Bold content**
- [Link](https://example.com)

</div>

#### Generic grid / card attributes

<div class="grid cards" markdown>

-   :material-file-document: **Markdown**

    Portable source.

-   :material-graph: **Diagrams**

    Mermaid and PlantUML.

</div>

---

<a id="ext-mdx"></a>

### 15.8 MDX and Docusaurus

MDX mixes Markdown with JSX and JavaScript expressions. A generic Markdown viewer may intentionally show these
constructs literally; an MDX-aware renderer may evaluate/transform them.

#### JSX-like component markup

<DocCard title="Renderer benchmark" status="active">
This child body contains **Markdown-like content** and Unicode: 中文 / العربية / 😀.
</DocCard>

#### JSX expression probes

The result expression is `{1 + 2}`.

A property-shaped expression: `{frontMatter.title}`.

A conditional-shaped expression: `{enabled ? "on" : "off"}`.

#### Docusaurus admonitions

:::note
Docusaurus note directive.
:::

:::tip[Custom title]
A **tip** with a custom title.
:::

:::warning
Compatibility warning.
:::

:::danger
Danger directive.
:::

#### Docusaurus nested admonition structure

::::info[Outer]
Outer content.

:::tip[Inner]
Nested directive.
:::
::::

#### Tabs-style MDX component

<Tabs groupId="language">
<TabItem value="js" label="JavaScript">

```javascript
console.log("MDX tab");
```

</TabItem>
<TabItem value="py" label="Python">

```python
print("MDX tab")
```

</TabItem>
</Tabs>

#### MDX ESM syntax shown as executable-source candidate

```mdx
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

export const answer = 42;

# MDX page

The answer is {answer}.
```

---

<a id="ext-hugo"></a>

### 15.9 Hugo / Goldmark

#### Hugo shortcodes

{{< figure src="/images/example.png" title="Example figure" >}}

{{< ref "architecture.md#deployment" >}}

{{< relref "security.md" >}}

{{% notice note %}}
Markdown-capable shortcode body.
{{% /notice %}}

#### Goldmark attribute-style probes

### Goldmark attributed heading {#goldmark-heading .goldmark-class}

A Goldmark/Pandoc-style attributed paragraph may be interpreted depending on renderer configuration.
{.goldmark-paragraph #goldmark-paragraph}

#### Hugo front matter alternatives

The file itself already uses YAML front matter. TOML and JSON front matter alternatives are document-level
constructs, so their syntax is preserved here without pretending they can become a second front matter block:

```toml
+++
title = "TOML Front Matter"
draft = false
tags = ["benchmark", "markdown"]
+++
```

```json
;;;
{
  "title": "JSON Front Matter",
  "draft": false
}
;;;
```

---

<a id="ext-myst"></a>

### 15.10 MyST Markdown / Sphinx-oriented Markdown

#### Colon-fenced directive

:::{note}
MyST note directive with **Markdown**, `code`, and Unicode 中文.
:::

#### Directive with options

:::{admonition} Renderer benchmark
:class: important
:name: myst-admonition

This directive has options and a named target.
:::

#### MyST figure directive

:::{figure} ./assets/missing-myst-figure.png
:name: fig-renderer
:width: 50%
:alt: Missing figure used as a renderer test

Figure caption with **Markdown**.
:::

#### MyST roles

Reference role: {ref}`fig-renderer`

Document role: {doc}`architecture`

Literal role: {literal}`renderer --safe`

Substitution-like role: {abbr}`UTF-8 (Unicode Transformation Format)`

#### MyST math directive

:::{math}
:label: eq-euler
e^{i\pi} + 1 = 0
:::

Equation reference: {eq}`eq-euler`

#### MyST code-cell style directive

```{code-block} python
:linenos:
:emphasize-lines: 2

def render(text):
    return parse(text)
```

---

<a id="ext-quarto"></a>

### 15.11 Quarto, R Markdown and bookdown

#### Quarto executable code cell

```{python}
#| label: fig-render-latency
#| fig-cap: "Illustrative render latency"
#| echo: true

values = [12, 18, 27, 31]
print(values)
```

#### Quarto cross references

See @fig-render-latency, @tbl-capabilities and @sec-quarto-target.

#### Quarto callout

::: {.callout-note}
## Quarto callout title

This is a Quarto fenced-div callout.
:::

#### Quarto panel/tabset-style fenced Div

::: {.panel-tabset}

## Linux

`mdvu test-complete-extensions.md`

## macOS

`open -a mdvu test-complete-extensions.md`

:::

#### Quarto target {#sec-quarto-target}

A section with an explicit cross-reference identifier.

#### Quarto table

| Capability | Status |
|---|---|
| Markdown | benchmark |
| Mermaid | benchmark |
| PlantUML | benchmark |

: Capability table {#tbl-capabilities}

#### R Markdown chunk

```{r renderer-summary, echo=TRUE}
sizes <- c(10, 20, 30)
mean(sizes)
```

#### bookdown references

Equation-style reference candidate: \@ref(eq:renderer)

Figure-style reference candidate: \@ref(fig:renderer)

Table-style reference candidate: \@ref(tab:capabilities)

---

<a id="ext-vitepress"></a>

### 15.12 VitePress and VuePress

#### Custom containers

::: info
Informational custom container.
:::

::: tip Custom title
Tip custom container.
:::

::: warning
Warning container.
:::

::: danger STOP
Danger container.
:::

::: details Click to expand
Details container with **Markdown** and `code`.
:::

#### Code group / tabs-style directives

::: code-group

```js [JavaScript]
console.log("VitePress");
```

```ts [TypeScript]
console.log("VitePress" as string);
```

:::

#### Line highlighting / code metadata probes

```js{2,4}
const parser = createParser();
const blocks = parser.parse(source);
const renderer = createRenderer();
renderer.render(blocks);
```

#### Vue-style custom component

<Badge type="tip" text="benchmark" />

---

<a id="ext-markdoc"></a>

### 15.13 Markdoc-style Tags and Variables

{% callout type="warning" %}
Markdoc-style tag body with **Markdown-like** content.
{% /callout %}

{% tabs %}
{% tab label="English" %}
Hello.
{% /tab %}
{% tab label="日本語" %}
こんにちは。
{% /tab %}
{% /tabs %}

Variable candidate: {% $frontmatter.title %}

Conditional candidate:

{% if $environment == "production" %}
Production content.
{% else %}
Development content.
{% /if %}

---

<a id="ext-generic"></a>

### 15.14 Generic Extension Syntax Matrix

These constructs appear across several Markdown engines with different semantics.

#### Generic fenced container

::: note
Generic colon-fenced note.
:::

#### Generic attributes

Paragraph with trailing attributes.
{#generic-id .class-one .class-two key="value"}

#### Generic highlighted text

==highlighted==

#### Generic underline / insert / delete

++inserted++ · ~~deleted~~ · ^^underlined^^

#### Generic subscript / superscript

H~2~O · x^2^

#### Generic emoji aliases

:rocket: :white_check_mark: :warning: :globe_with_meridians:

#### Generic TOC tokens

[TOC]

[[TOC]]

[[_TOC_]]

#### Generic wiki/link hybrids

[[Page Name]] · [[Page Name|Alias]] · [[Page#Heading]] · ![[Embedded Page]]

---

<a id="ext-docfx"></a>

### 15.15 DocFX / Markdig / Microsoft documentation syntax

#### Cross references

<xref:System.String>

[System.String](xref:System.String)

Shorthand UID candidate: @System.String

Quoted UID candidate: @"System.Collections.Generic.List`1"

#### DocFX includes

[!INCLUDE [shared renderer note](includes/renderer-note.md)]

Inline include candidate: text before [!INCLUDE [inline fragment](includes/inline.md)] text after.

#### DocFX code snippets

[!code-csharp[](Program.cs)]

[!code-csharp[](Program.cs#L12-L16)]

[!code-csharp[](Program.cs?highlight=2,5-7,9-)]

#### DocFX media extension

> [!Video https://example.invalid/embed/video]

#### Markdig emphasis-extra probes

++inserted text++ · ==marked text== · X^2^ · H~2~O

#### Markdig math

Inline: $\sqrt{3x-1}+(1+x)^2$

Block:

$$
\left(\sum_{k=1}^{n} a_k b_k\right)^2
\le
\left(\sum_{k=1}^{n} a_k^2\right)
\left(\sum_{k=1}^{n} b_k^2\right)
$$

---

<a id="ext-marp"></a>

### 15.16 Marp / Marpit Markdown

Marp is slide-oriented Markdown. In this ordinary document, horizontal rules remain normal Markdown separators,
while Marp-specific directives are tested through the same HTML comments Marpit recognizes.

<!--
theme: default
paginate: true
lang: en
header: '**mdvu** ecosystem benchmark'
footer: 'Marp / Marpit extension probe'
-->

<!-- _class: lead -->

#### Marp spot directive target

This section follows a `_class` spot-directive comment.

<!--
_backgroundColor: black
_color: white
_paginate: hold
-->

#### Marp local directive target

The comment above probes slide-local background/color/pagination syntax.

#### Marp fragmented list syntax

* Item one
* Item two
* Item three

#### Marp extended image syntax probes

![bg contain](./assets/missing-marp-background.png)

![w:320 h:180](./assets/missing-marp-sized.png)

![brightness:0.8](./assets/missing-marp-filtered.png)

#### Marp slide separator source example

Because `---` is also standard Markdown thematic-break syntax, this compact fenced source preserves the
explicit slide-deck interpretation without injecting dozens of artificial slides:

```markdown
# Slide one

Content

---

# Slide two

Content
```

---

<a id="ext-jupyter"></a>

### 15.17 Jupyter Notebook Markdown-cell conventions

#### Attachment URI

![Notebook attachment](attachment:renderer-diagram.png)

#### Rich math

Inline Jupyter-style MathJax: $\alpha + \beta = \gamma$.

$$
\mathbf{A}\mathbf{x}=\mathbf{b}
$$

#### HTML output-like content in a Markdown cell

<span style="border:1px solid currentColor;padding:0.2em 0.4em">Notebook HTML span</span>

#### Notebook-oriented fenced languages

```python
from IPython.display import Markdown
display(Markdown("**Rendered from a notebook cell**"))
```

```julia
println("Jupyter kernel language probe")
```

```r
cat("R kernel language probe\n")
```

<a id="section-16"></a>

## 16. Cross-Dialect Interaction Tests

These are compact combinations that are more useful than repeating isolated primitives.

### 16.1 Obsidian callout containing links, tasks, math and a Mermaid diagram

> [!example]+ Integrated Obsidian-style block
> - [x] [[Architecture Overview|Wikilink]]
> - [ ] Standard [Markdown link](#section-3)
> - Inline math $x^2+y^2=z^2$
>
> ```mermaid
> flowchart LR
>     A["Obsidian callout"] --> B["Markdown fence"]
>     B --> C["Mermaid"]
>     C --> D["SVG"]
> ```

### 16.2 MkDocs tabs containing Mermaid and PlantUML source blocks

=== "Mermaid"

    ```mermaid
    sequenceDiagram
        actor User
        User->>mdvu: Open extension fixture
        mdvu-->>User: Render Mermaid
    ```

=== "PlantUML"

    ```plantuml
    @startuml
    actor User
    User -> mdvu : Open extension fixture
    mdvu --> User : Render PlantUML
    @enduml
    ```

### 16.3 Pandoc fenced Div containing a GitHub alert

::: {.benchmark-container}

> [!IMPORTANT]
> Alert nested inside a Pandoc-style Div.

The same block also contains an explicit [link back to the top](#top).

:::

### 16.4 HTML/details containing dialect syntax

<details>
<summary>Mixed ecosystem content</summary>

Obsidian: [[Architecture Overview|Alias]]

GitLab: `#123`, `[[_TOC_]]`, `%{project_path}`

Pandoc: [citation candidate @doe2026]

MkDocs: ==highlight== and ++cmd+k++

</details>

### 16.5 RTL dialect mixture

<div dir="rtl">

> [!note] اختبار RTL
> رابط Markdown: [العمارة](#section-3)  
> رابط Obsidian: [[Architecture Overview|العمارة]]  
> وسم: #اختبار  
> رموز: ✅ 🚀

</div>

### 16.6 Multilingual extension-navigation targets

<a id="ext-nav-ru"></a>
#### Русский: расширения Markdown

Wikilinks `[[Документ]]`, предупреждения, таблицы, сноски и диаграммы должны оставаться читаемыми.

<a id="ext-nav-zh"></a>
#### 中文：Markdown 扩展

Wiki 链接 `[[文档]]`、提示框、表格、脚注和图表都应保持可读。

<a id="ext-nav-ja"></a>
#### 日本語：Markdown 拡張

Wikiリンク `[[ドキュメント]]`、コールアウト、表、脚注、図を確認します。

<a id="ext-nav-ar"></a>
#### العربية: امتدادات Markdown

يجب أن تبقى روابط الويكي `[[مستند]]` والتنبيهات والجداول والحواشي والرسوم قابلة للقراءة.

<a id="ext-nav-he"></a>
#### עברית: הרחבות Markdown

יש לבדוק קישורי ויקי `[[מסמך]]`, התראות, טבלאות, הערות שוליים ודיאגרמות.

---

<a id="section-17"></a>

## 17. Extension Coverage Matrix

| Ecosystem / dialect | Syntax covered in this fixture |
|---|---|
| CommonMark | headings, paragraphs, emphasis, code, links, images, lists, quotes, thematic breaks, raw HTML, escapes |
| GitHub / GFM | tables, tasks, strike, autolinks, alerts, footnotes, reference-like tokens, emoji aliases |
| Obsidian | wikilinks, aliases, heading links, block refs/IDs, embeds, tags, comments, properties, callouts, folding, nesting, math |
| GitLab | TOC tokens, description lists, three-state tasks, multiline quotes, inline diff, refs, color chips, includes, placeholders, JSON table, media dimensions, math |
| Pandoc | attributes, fenced Divs, bracketed spans, code attributes, raw blocks, citations, line blocks, definition lists, grid table, super/subscript |
| Markdown Extra | definition lists, footnotes, attributes, abbreviations |
| MultiMarkdown | cross-reference/citation-shaped syntax, figures, metadata-oriented conventions |
| CriticMarkup | insertion, deletion, substitution, highlight, comment |
| kramdown | IALs, extension tags, footnotes |
| Jekyll | Liquid variables, assign/if/include/highlight/link/post_url tags |
| Python-Markdown | abbreviations, admonitions, attributes, definition lists, footnotes, Markdown-in-HTML |
| PyMdown / MkDocs Material | details, tabs, annotations, mark/caret/tilde, keys, emoji/icons, smart symbols, code metadata, snippets, grids |
| MDX / Docusaurus | JSX-like components, expressions, directives/admonitions, nested directives, Tabs/TabItem, MDX fenced source |
| Hugo / Goldmark | shortcodes, ref/relref, Markdown shortcodes, attribute probes, alternate front matter source |
| MyST | colon directives, directive options, roles, figures, equation labels/references, code-block directives |
| Quarto | executable-cell options, crossrefs, fenced Div callouts, panel-tabset, captioned tables |
| R Markdown / bookdown | R chunks and `\\@ref(...)` cross-reference syntax |
| VitePress / VuePress | custom containers, details, code groups, line highlighting metadata, custom components |
| Markdoc | tags, nested tags, variables, conditions |
| DocFX / Markdig | xref links, UID shorthand, includes, code snippets, video alert, emphasis extras, math |
| Marp / Marpit | HTML-comment directives, spot/local directives, extended image syntax, slide-separator source |
| Jupyter Markdown | attachment URIs, MathJax, inline HTML, notebook-oriented fenced languages |
| Generic extensions | colon containers, attributes, highlights, insert/delete/underline, sub/superscript, emoji aliases, TOC tokens, wikilink hybrids |

### 17.1 Expected interpretation classes

A test runner can classify each construct as:

1. **Native render** — extension semantics are implemented.
2. **Graceful literal fallback** — syntax remains readable but untransformed.
3. **Block-local diagnostic** — unsupported executable/diagram construct reports a local error.
4. **Failure** — parser/render failure corrupts unrelated content, navigation, or later sections.

The benchmark treats classes 1–3 as observable implementation behavior. Class 4 is always a renderer defect.

<a id="section-18"></a>

## 18. Validation Checklist

A successful normal validation should confirm:

- [ ] File opens as UTF-8 without replacement characters.
- [ ] Table of contents and heading navigation remain usable.
- [ ] Common Markdown blocks render correctly.
- [ ] Major Markdown ecosystem dialects either render natively or degrade locally without corrupting subsequent content.
- [ ] Obsidian wikilinks, block IDs, embeds, tags, comments and callouts are distinguishable from ordinary Markdown.
- [ ] GitLab, Pandoc, kramdown/Jekyll, MkDocs/PyMdown, MDX/Docusaurus, MyST, Quarto and VuePress/VitePress probes remain navigable.
- [ ] Code fences retain indentation and punctuation.
- [ ] Every Mermaid 11.17.2 diagram family in this fixture renders or reports a block-local failure without corrupting the document.
- [ ] ZenUML diagrams render as part of the Mermaid target profile.
- [ ] Every PlantUML 1.2026.6 family in this fixture renders or reports a block-local failure without corrupting the document.
- [ ] Both `plantuml` and `puml` fenced-code routing behave as expected.
- [ ] RTL samples remain readable and do not corrupt neighboring LTR text.
- [ ] CJK, Cyrillic, Greek, Indic and Latin-extended scripts use usable fallback fonts.
- [ ] Emoji and combined graphemes remain intact.
- [ ] HTML details/table fragments behave according to the viewer security policy.
- [ ] Links and anchors are clickable where supported.
- [ ] Search finds `MDVU-COMPLETE-BEGIN`, `MDVU-COMPLETE-MIDDLE`, and `MDVU-COMPLETE-END`.
- [ ] Scrolling and navigation are responsive for an ordinary large document.

### 18.1 Expected Scope

| Dimension | This fixture intentionally includes | This fixture intentionally avoids |
|---|---|---|
| Markdown | Broad everyday syntax + compact probes for major public Markdown dialects/extensions | malformed fences and pathological nesting |
| Mermaid | full Mermaid 11.17.2 diagram-family coverage + compact grammar probes | hundreds of repeated diagrams and giant graphs |
| PlantUML | UML + non-UML families, current start tags and renderer features | mass repetition and oversized diagrams |
| Unicode | major scripts, RTL, emoji, graphemes | control-character matrices and exhaustive code-point ranges |
| Performance | realistic large document | maximum CPU/memory stress |
| Errors | normal compatibility differences | intentionally invalid parser inputs |

The document ends with an explicit marker so automated smoke tests can distinguish successful full-file
traversal from partial rendering. Reaching this section proves that the viewer remained usable through the entire functional validation corpus. Diagram failures are still reported separately and should be treated as benchmark gaps against the declared target versions.

`MDVU-COMPLETE-END`

