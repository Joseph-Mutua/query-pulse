# ADR 003: Normalized search result model

## Context
Provider schemas differ, while comparison and assertions need stable semantics.

## Decision
Adapters return transport-neutral `Search::Result` objects. `SearchResultNormalizer` maps organic results, questions, searches, and metadata into one documented structure while retaining provider data.

## Alternatives considered
Comparing raw JSON preserves everything but produces provider-specific noise. Discarding raw data makes failures harder to reproduce. Per-provider domain models multiply downstream logic.

## Consequences
Comparison is portable and tests are deterministic. Normalizer evolution must be version-aware in future migrations; current snapshots preserve enough raw evidence for reprocessing.
