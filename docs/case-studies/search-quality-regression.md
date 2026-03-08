# Search quality regression: synthetic domain drift

## Problem
A search monitor expects results from `github.com`, but a later response contains unrelated domains while still returning HTTP 200. Availability monitoring would call this healthy.

## Baseline
The deterministic **GitHub Ruby Results** demo monitor runs `site:github.com "ruby scraper"`, requires at least five results, requires result domains to match `github.com`, and expects “ruby” in a title. Its baseline contains six matching results.

## Degraded result
The final synthetic snapshot retains six results but introduces several unexpected domains, removes a snippet, changes a price from string to object, moves a canonical URL, and increases latency. This is test data, not evidence of a real provider defect.

## Detection methodology
QueryPulse first compares schema hashes, then recursively diffs normalized data. Organic results are paired by canonical URL. Assertions compare the observed domain set to the configured required-domain allowlist. The relevance scorer awards domain points by the share of returned results that match.

## Result
The run records `FIELD_REMOVED`, `TYPE_CHANGED`, and `RESULT_ORDER_CHANGED`. The failed required-domain assertion produces a deduplicated `domain_mismatch` incident, and the relevance score falls because most returned domains no longer match. Slow recent samples can independently create `latency_regression`.

## Limitations
Domain rules are explicit configuration, not semantic truth. A legitimate provider change can still need acknowledgement. Relevance is deterministic and explainable but intentionally does not infer intent. Production thresholds should be tuned per query and locale.
