# Building a Regression Detection System for Dynamic Search APIs

Search APIs are difficult to regression-test because a changed response can be correct. New pages appear, rankings move, localized fields vary, and provider request identifiers change on every call. A useful detector cannot equate “different” with “broken.”

QueryPulse starts by separating transport from meaning. Adapters own HTTP, credentials, retries, and provider error classification. The rest of the application receives a small result object and a normalized document. We keep the raw response for diagnosis, but comparisons use consistent fields: search metadata, organic results, related questions, and related searches.

## Cheap structure before deep comparison

Schema extraction replaces leaves with types, recursively sorts keys, and merges array item shapes. SHA-256 over canonical JSON becomes a structural fingerprint. Matching hashes do not prove content equality, but they cheaply establish that fields and types are stable. A second content hash detects identical normalized documents.

When deeper work is needed, the comparator walks the union of object keys and pairs array elements. It reports additions, removals, type changes, value changes, and length changes with JSON paths. Ignored paths remove request IDs and timestamps that would otherwise drown useful evidence.

## Ranking without noise

Comparing array indexes naively makes one inserted result look like every result changed. QueryPulse identifies organic results by canonical URL—dropping tracking queries and fragments—with domain plus normalized title as fallback. It then calculates `abs(current_position - previous_position)`. Small movement stays diagnostic data; only movement meeting the configured threshold becomes a change.

## Expectations make changes actionable

Assertions express what matters for one query: a minimum result count, allowed domains, forbidden domains, required text or fields, and maximum latency. Their output includes expected and actual values. This is more honest than a universal anomaly model because the operator can see why a check failed.

The relevance score uses the same principle. Query-token coverage, expected-domain share, title/snippet expectations, and assertion health contribute fixed weights. There is no LLM and no opaque learned baseline.

## Incidents are state, not notifications

Every finding is fingerprinted by monitor, type, and path. If it remains active, a later occurrence updates its count and last-seen time. Healthy executions increment a streak; after three, active incidents resolve. This keeps a persistent problem from becoming a new row every five minutes.

## Deterministic parsing and background work

HTML parsers use small selector families and committed fixtures for standard, mobile, missing, changed, and empty layouts. CI never depends on a live search page. Sidekiq runs provider work outside web requests, and unique execution keys make retries safe. Transient transport problems get bounded backoff; authentication and malformed configuration do not loop.

## Performance considerations

Recursive comparison is linear in visited nodes, plus key sorting and result identity maps. The included benchmark constructs 10, 100, and 1,000-result documents and reports actual local timing. At higher volumes the next optimizations are content-hash short-circuiting, snapshot compression, retention tiers, and pre-aggregated metrics—not premature service decomposition.

The main lesson is that reliability tooling earns trust through evidence. Preserve the response, normalize deliberately, name every rule, suppress known volatility, and make every alert reproducible.
