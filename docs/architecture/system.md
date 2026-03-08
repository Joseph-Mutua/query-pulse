# System architecture and execution lifecycle

```mermaid
flowchart LR
  User[Browser / API client] --> Rails
  Rails --> MongoDB[(MongoDB snapshots)]
  Rails --> Redis[(Redis)]
  Redis --> Sidekiq
  Sidekiq --> Search[Provider adapter]
  Search --> External[External provider]
  Rails --> Playwright[Isolated Playwright worker]
  Playwright --> External
```

```mermaid
sequenceDiagram
  participant S as Scheduler
  participant J as ExecuteMonitorJob
  participant P as Provider adapter
  participant N as Normalizer
  participant M as MongoDB
  participant D as Detection
  S->>J: due monitor + idempotency key
  J->>P: execute configured query
  P-->>J: Search::Result
  J->>N: normalize provider payload
  N-->>J: canonical search document
  J->>M: persist run and snapshot
  J->>D: compare, assert, score, detect
  D->>M: upsert or resolve incidents
```

The execution service deliberately owns one vertical transaction-like workflow. Persisted statuses and idempotency make partial execution observable without requiring a distributed workflow engine.
