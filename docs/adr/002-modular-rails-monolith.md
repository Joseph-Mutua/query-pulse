# ADR 002: Modular Rails monolith

## Context
The UI, API, scheduler, comparison logic, and incident lifecycle share one domain and deployment cadence.

## Decision
Keep them in one Rails application with explicit service namespaces. Sidekiq provides asynchronous execution but loads the same application code.

## Alternatives considered
Microservices would isolate scaling but introduce contracts, distributed tracing, deployment coordination, and partial-failure modes before measured need. A single undifferentiated Rails layer would be simpler initially but obscure domain boundaries.

## Consequences
Local development and changes remain coherent. Services can later be extracted at demonstrated scaling or security boundaries. Engineers must preserve module boundaries during review.
