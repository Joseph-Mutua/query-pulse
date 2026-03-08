# QueryPulse engineering notes

These notes describe the implementation that exists in this repository.

1. **Why MongoDB?** Search snapshots are nested, sparse, append-mostly documents read back as a whole. Mongoid preserves those shapes while top-level fields and compound indexes serve operational queries.
2. **Why a Rails modular monolith?** Web, API, jobs, and detection share one cohesive domain. Service namespaces provide boundaries without distributed deployment overhead.
3. **How does recursive comparison work?** `ResultComparator` walks the union of sorted hash keys, checks runtime JSON types, recursively pairs arrays, and emits structured path/type/before/after/severity records.
4. **How are normal changes distinguished?** Volatile paths are ignored, ranking has a movement threshold, incidents are driven by selected structural changes and explicit assertions, and operators can acknowledge issues.
5. **Why are search responses hard to test?** Results, rankings, optional features, locales, and provider metadata can legitimately change independently of application releases.
6. **How does fingerprinting work?** `SchemaExtractor` maps leaves to types and merges array shapes; `CanonicalJson` sorts object keys and hashes JSON with SHA-256.
7. **How are duplicates avoided?** `Detector` hashes monitor ID, incident type, and path, then updates an active matching incident’s occurrence and last-seen values.
8. **How is ranking movement calculated?** Organic results are identity-mapped by canonical URL or domain/title fallback; absolute previous/current position difference is compared with a threshold.
9. **Why are retries safe?** Scheduled/manual runs have unique keys. Faraday retries bounded transient failures; permanent authentication errors return classified failures. Jobs have finite attempts.
10. **How are rate limits handled?** Provider 429 responses receive bounded adapter backoff, execution endpoints have Rack::Attack throttles, and errors preserve classification. Quota-aware queue budgets are future scale work.
11. **How are credentials protected?** Keys come from environment variables, upstream endpoints are fixed, parameter filtering and structured-log sanitization cover key/token/secret names, and errors never include request URLs.
12. **Why no live calls in tests?** WebMock and `FakeAdapter` make CI deterministic, fast, cost-free, and independent of provider availability.
13. **How does fixture parser testing work?** Local HTML files exercise selector fallbacks, mobile markup, absent snippets, changed structure, empty results, and unrelated panels.
14. **How can the system scale?** Partition Sidekiq queues by provider and priority, add scheduler claims/backpressure, roll up metrics, and tier snapshots before considering service extraction.
15. **How were indexes selected?** They correspond to due-monitor scans, per-monitor run/snapshot timelines, unique snapshot/run and idempotency constraints, and active incident filters.
16. **How can snapshots be archived?** Retain normalized summaries/hashes in MongoDB, compress raw payloads to object storage, and use age/severity-based retention. This is documented but not implemented.
17. **Why isolate browser diagnostics?** Chromium’s dependency size, hostile page execution, and egress policy differ from Rails. A separate container limits blast radius and scales separately.
18. **How is SSRF prevented?** The worker accepts exact allowlisted hosts, resolves destinations for every request and redirect, and rejects loopback, private, link-local, metadata, reserved, and unique-local ranges.
19. **How is latency regression identified?** `LatencyRegression` compares recent and prior p95 values only when each sample contains at least ten points and requires a 50% default increase.
20. **What changes at much larger scale?** Shard MongoDB by monitor, use atomic distributed scheduler leases, reserve provider concurrency pools, introduce quota-aware job priorities, pre-aggregate metrics, and move old raw snapshots to cold storage.

## Index rationale

- `monitors(enabled, next_execution_at)` supports the scheduler’s bounded due scan.
- `search_runs(monitor_id, started_at desc)` supports monitor history, diffs, and latency windows.
- `snapshots(monitor_id, captured_at desc)` finds the previous snapshot; unique `search_run_id` enforces one snapshot per run.
- `incidents(monitor_id, status, last_seen_at desc)` supports monitor/UI active issue lists.
- `incidents(incident_type, status)` supports operational incident filtering.
- sparse unique `search_runs(idempotency_key)` prevents duplicate logical executions.

Indexes are declared next to the models and created with `bin/rails db:mongoid:create_indexes`.
