# ADR 005: Background monitor execution

## Context
Provider calls are slow and may fail transiently. Web requests should not own scheduled work.

## Decision
Use Sidekiq/Redis with a minute scheduler, bounded queue selection, persisted pending runs, and unique idempotency keys. The execution service owns the vertical workflow; auxiliary jobs are explicit recovery entry points rather than a mandatory chain.

## Alternatives considered
In-process timers lose work on restart. Cron invoking synchronous Rails commands has weak concurrency and visibility. A workflow engine is unnecessary at current scale.

## Consequences
Execution survives web restarts and can scale independently. Redis is an operational dependency. Multiple schedulers will require an atomic distributed claim before horizontal scaling.
