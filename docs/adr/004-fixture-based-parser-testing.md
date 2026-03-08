# ADR 004: Fixture-based parser regression testing

## Context
Live HTML is nondeterministic and unavailable in offline CI. Parsers need examples of missing and changed markup.

## Decision
Test resilient selector groups against committed standard, mobile, missing-snippet, changed-markup, empty, and knowledge-panel fixtures.

## Alternatives considered
Live requests would detect the newest markup but make tests flaky and may violate provider expectations. Large recorded browser sessions add noise. Mocking parser outputs would not test extraction.

## Consequences
CI is fast and repeatable. Fixtures must be deliberately updated when supported markup changes, and they do not claim to mirror any provider continuously.
