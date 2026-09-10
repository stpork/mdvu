# Cache identity and instance separation

Inline $x^2+1$, display:

$$
x^2+1
$$

First graph:

```mermaid
flowchart LR
    A[Input] --> B[Result v1]
```

Second, identical source, independent rendered instance:

```mermaid
flowchart LR
    A[Input] --> B[Result v1]
```

```plantuml
@startuml
Alice -> Bob : result v1
@enduml
```

MDVU-CACHE-END
