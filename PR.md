## Summary

Replace the fragile substring-based replayer log validation in tests with structured JSON inspection. The replayer now emits structured `replayer_event` metadata, and `check_replayer_logs` is rewritten as a pure fold over JSONL output that validates internal consistency and verifies the block count falls within an expected range.

## Motivation

The existing `check_replayer_logs` relied on substring matches (e.g. `"Info"`, `"Error"`) against log lines, which is brittle—log format changes, message rephrasing, or `Error` appearing in non-error contexts could produce false positives or negatives.

Additionally, it enforced a hardcoded floor of 25 `Info` log lines, rejecting shorter outputs as `"suspiciously few Info logs"`. Several test integrations produce fewer than 25 blocks (e.g. `payments_test.ml` ~13–20, `zkapps.ml` ~10–15), so this threshold caused false failures even when the replayer ran correctly. This began failing CI after commit `3feb9cca2a` ("replayer: choose canonical target blocks by slot"), which changed block selection to canonical-only and surfaced the latent threshold bug on tests with short chains. There was also no validation that the replayer actually replayed a plausible number of blocks.

## Changes

### `src/app/replayer/replayer.ml`
- Added `blocks_replayed` counter, incremented on every successful `block_applied`
- Added `replayer_event` metadata to `block_applied` log entries for precise counting
- Added `replay_done` structured event with `blocks_replayed` field emitted at replay completion

### `src/app/test_executive/test_common.ml`
- Rewrote `check_replayer_logs` as a pure fold over JSONL lines:
  - Parses each line as JSON and inspects the `level` field to detect errors
  - Counts `block_applied` events via `replayer_event` metadata
  - Reads `blocks_replayed` from the `replay_done` event
  - Returns the `blocks_replayed` count on success
- Dropped all substring-based detection

### `src/app/test_executive/*.ml` (5 test files)
- Updated all callers to bind the returned block count and assert it falls within a reasonable range per test

## Test ranges

| Test | Expected blocks range | Rationale |
|---|---|---|
| `payments_test.ml` | 8–30 | 3 BPs, small txn capacity, 3 ledger proofs |
| `zkapps_timing.ml` | 5–40 | 3 BPs, no explicit proof wait, 7 zkapp commands |
| `zkapps.ml` | 5–25 | 2 BPs, small txn capacity, 1 explicit block + 1 proof |
| `zkapps_nonce_test.ml` | 8–30 | 2 BPs, medium txn capacity, 2 proofs |
| `post_hard_fork.ml` | 5–25 | 2 BPs, small txn capacity, 1 proof after fork |
