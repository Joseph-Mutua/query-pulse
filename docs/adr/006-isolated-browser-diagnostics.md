# ADR 006: Isolated browser diagnostics

## Context
Chromium has large dependencies, executes hostile content, and has a distinct network threat model.

## Decision
Run a small TypeScript/Playwright worker in a separate container. Accept only allowlisted hosts, resolve every navigation and subresource, block private/special addresses, and classify challenge pages without evasion.

## Alternatives considered
Embedding Playwright in Rails increases image size and blast radius. Allowing arbitrary URLs enables SSRF. Omitting browser diagnostics loses layout-level evidence.

## Consequences
Browser failures cannot crash Rails and the worker can have stricter network policy. It adds one deployable unit and needs artifact retention. The Rails-to-worker trigger is future work.
