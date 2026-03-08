# ADR 001: Document database for search snapshots

## Context
Search providers return nested, sparse JSON whose optional fields and shapes change over time. QueryPulse reads snapshots as complete diagnostic records and rarely updates them.

## Decision
Use MongoDB through Mongoid. Keep raw and normalized response documents intact while indexing operational top-level fields and foreign keys.

## Alternatives considered
PostgreSQL JSONB would provide excellent JSON support and transactions but adds relational mapping without a current join-heavy need. Fully normalized SQL tables would make provider evolution and complete-response reconstruction expensive. Object storage alone would make operational queries awkward.

## Consequences
Snapshot writes and historical retrieval remain simple, and schema drift is representable. Document size and retention must be monitored; the 16 MB BSON limit means very large raw payloads require object storage. Cross-document workflows use idempotency rather than multi-record transactional assumptions.
