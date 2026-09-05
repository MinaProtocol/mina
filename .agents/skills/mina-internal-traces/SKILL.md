---
name: mina-internal-traces
description: Use when working in the Mina repo with internal traces, internal-tracing, interal-traces typos, internal-trace.jsonl, prover-internal-trace.jsonl, verifier-internal-trace.jsonl, Mina daemon start-internal-tracing/stop-internal-tracing, or proof-system/Kimchi internal_tracing. Helps distinguish Mina OCaml node internal tracing, O1Trace/WebKit tracing, and Rust proof-system internal-tracing before inspecting files or changing code.
---

# Mina Internal Traces

Use this skill for Mina-specific trace inspection, diagnosis, and code changes involving internal tracing. Start by classifying which tracing system the user means; Mina has several similarly named systems that are easy to conflate.

## First classify the trace system

1. Mina OCaml node internal tracing
   - User clues: `--internal-tracing`, `start-internal-tracing`, `stop-internal-tracing`, `internal-trace.jsonl`, `prover-internal-trace.jsonl`, `verifier-internal-trace.jsonl`, `[%log internal]`, `src/lib/internal_tracing`.
   - Main implementation: `src/lib/internal_tracing/internal_tracing.ml` and `.mli`.
   - Output directory: `$config-directory/internal-tracing/`.
   - Main files: `internal-trace.jsonl`, `prover-internal-trace.jsonl`, `verifier-internal-trace.jsonl`.

2. Mina O1Trace/WebKit tracing
   - User clues: `--tracing`, `trace/$pid.trace`, Chrome trace viewer, `trace-tool`, `Mina_tracing`, `O1trace`.
   - Main implementation: `src/app/cli/src/init/mina_tracing.ml`, `src/lib/o1trace/`, `src/lib/webkit_trace_event/`, `src/app/trace-tool/`.
   - Output directory: `$config-directory/trace/`.
   - Output files: binary `*.trace` files converted by `src/app/trace-tool`.
   - Do not treat these as JSONL internal traces.

3. Rust proof-system/Kimchi internal-tracing
   - User clues: `internal_tracing` Cargo feature, `internal-tracing` crate, `internal_tracing::checkpoint!`, `decl_traces!`, Kimchi prover checkpoints.
   - Main implementation: `src/lib/crypto/proof-systems/internal-tracing/src/lib.rs` and `src/lib/crypto/proof-systems/kimchi/src/prover.rs`.
   - Current repo evidence: the Rust crate defines thread-local trace storage and Kimchi checkpoints, and `kimchi` exposes `CamlProverTraces` only behind the Rust `internal_tracing` plus `ocaml_types` features. There is no current repo usage of `internal_traces::start_tracing()` or `internal_traces::take_traces()` outside tests, and Mina daemon `start-internal-tracing`/`stop-internal-tracing` toggles the OCaml `Internal_tracing` logger system, not the Rust Kimchi trace store.

When uncertain, inspect all three and report the distinction explicitly before editing.

## Key Repo Map

Use these entry points before broad searches:

- `src/lib/internal_tracing/internal_tracing.mli`: OCaml node internal trace semantics, control commands, JSONL output format.
- `src/lib/internal_tracing/internal_tracing.ml`: logger processor, enabled flag, toggle callbacks, JSON conversion.
- `src/lib/internal_tracing/context_call/internal_tracing_context_call.ml`: concurrent call IDs and optional call tags.
- `src/app/cli/src/cli_entrypoint/mina_cli_entrypoint.ml`: daemon flags `--internal-tracing` and `--tracing`; logger consumer registration.
- `src/app/cli/src/init/client.ml`: client commands `start-internal-tracing` and `stop-internal-tracing`.
- `src/app/cli/src/init/mina_run.ml`: daemon RPC handlers for start/stop internal tracing.
- `src/lib/mina_lib/mina_lib.ml`: creates prover/verifier subprocesses with `prover-internal-trace.jsonl` and `verifier-internal-trace.jsonl`; registers toggle callbacks.
- `src/lib/prover/prover.ml`: prover subprocess logger registration and internal checkpoints around `B.step`/verification.
- `src/lib/verifier/prod.ml`: verifier subprocess logger registration and internal checkpoints around verification calls.
- `src/lib/crypto/proof-systems/internal-tracing/src/lib.rs`: Rust trace macros and thread-local storage.
- `src/lib/crypto/proof-systems/kimchi/src/prover.rs`: Kimchi prover checkpoints declared by `decl_traces!`.
- `src/app/trace-tool/README.md`: binary WebKit/O1Trace conversion, not JSONL internal tracing.

## OCaml Node Internal Tracing

How it is enabled:

- At daemon startup: run the daemon with `--internal-tracing`.
- Dynamically: use the client commands `mina client start-internal-tracing` and `mina client stop-internal-tracing` against a running daemon.
- Internally: those commands dispatch `Daemon_rpcs.Start_internal_tracing`/`Stop_internal_tracing`, whose handlers call `Internal_tracing.toggle`.

How output is produced:

- `cli_entrypoint` always registers a consumer for `[%log internal]`, but `Internal_tracing.For_logger.processor` only emits while `Internal_tracing.is_enabled ()` is true.
- `Internal_tracing.toggle` logs enable/disable events and calls registered callbacks.
- `mina_lib` registers callbacks that toggle internal tracing in the verifier and prover subprocesses.
- Prover and verifier subprocesses each register their own logger transport when `internal_trace_filename` is supplied.

JSONL shape:

- Checkpoint line: `["Checkpoint_name", 1677161355.688698]`.
- Control line: `{ "current_block": "..." }`, `{ "current_call_id": 3, "current_call_tag": "..." }`, `{ "metadata": { ... } }`, `{ "block_metadata": { ... } }`, `{ "internal_tracing_enabled": 1677161355.0 }`, etc.
- Metadata logged with a checkpoint often appears as a separate `{ "metadata": ... }` line after the checkpoint.
- Current block and current call ID are context-setting events. Preserve stream order when reconstructing context.

Important control commands from the interface:

- User-facing: `@metadata`, `@block_metadata`, `@produced_block_state_hash`.
- Internal: `@current_block`, `@current_call_id`, `@internal_tracing_enabled`, `@internal_tracing_disabled`, `@mina_node_metadata`, rotated-log notifications.

## Rust Proof-System Internal-Tracing

Treat this as a separate feature unless code proves it is wired into Mina node tracing.

Facts to verify when working on it:

- `src/lib/crypto/proof-systems/internal-tracing/src/lib.rs` defines `decl_traces!` and `checkpoint!` macros.
- With the `enabled` feature, traces are thread-local and store one timestamp plus metadata per declared checkpoint name.
- `start_tracing()` clears old thread-local traces by calling `take_traces()`.
- `take_traces()` returns the accumulated trace struct for the current thread.
- Display/string conversion sorts checkpoints by timestamp and writes JSON lines using the same checkpoint array shape as the OCaml JSONL format, followed by metadata object lines when metadata is non-null.
- With no `enabled` feature, the macros compile to no-ops.
- In `kimchi/Cargo.toml`, feature `internal_tracing` enables `internal-tracing/enabled`; `ocaml_types` enables `internal-tracing/ocaml_types`.
- In `kimchi/src/prover.rs`, `CamlProverTraces` is exported only under `#[cfg(feature = "internal_tracing")]` inside the `caml` module.
- Current repo searches show no production calls to `internal_traces::start_tracing()` or `internal_traces::take_traces()`. If the task requires collecting Kimchi traces, expect to add both build-feature plumbing and an explicit collection/export call path.

## Investigation Workflow

1. Classify the trace system from filenames, flags, and paths.
2. If it is OCaml node internal tracing, read `internal_tracing.mli` first, then follow CLI/RPC/toggle/subprocess flow.
3. If inspecting a JSONL trace file, use the bundled summarizer before hand-reading large files.
4. If looking for checkpoint producers, search for `[%log internal]` for OCaml node traces and `internal_tracing::checkpoint!` for Rust proof-system traces.
5. If changing behavior, preserve the distinction between logging context controls and timing checkpoints.
6. If adding new OCaml checkpoints, put work under `Internal_tracing.with_state_hash` or `Internal_tracing.with_slot` when the events must be associated with a block.
7. If adding new prover/verifier checkpoints, use `Internal_tracing.Context_call.with_call_id` around concurrent calls so interleaved subprocess logs can be reconstructed.
8. If adding Rust Kimchi trace collection, confirm cargo features, generated OCaml bindings, thread locality, and where the resulting `CamlProverTraces` string should be logged or returned.

## Inspecting JSONL Trace Files

Use the bundled script for quick structure and gap summaries:

```bash
python .opencode/skills/mina-internal-traces/scripts/summarize_internal_trace.py \
  ~/.mina-config/internal-tracing/internal-trace.jsonl \
  ~/.mina-config/internal-tracing/prover-internal-trace.jsonl \
  ~/.mina-config/internal-tracing/verifier-internal-trace.jsonl
```

Useful options:

```bash
python .opencode/skills/mina-internal-traces/scripts/summarize_internal_trace.py --top-gaps 30 FILE.jsonl
python .opencode/skills/mina-internal-traces/scripts/summarize_internal_trace.py --context block FILE.jsonl
python .opencode/skills/mina-internal-traces/scripts/summarize_internal_trace.py --context call FILE.jsonl
```

Interpreting the summary:

- `checkpoint count` identifies the most common checkpoint tags.
- `top adjacent gaps` reports time gaps between adjacent checkpoints after grouping by selected context.
- `controls` shows whether context events and metadata are present.
- `malformed lines` usually means a rotated/truncated file, non-JSON logs, or the wrong tracing system.

For precise reconstruction, read nearby JSONL lines manually after identifying interesting tags or gaps.

## Common Pitfalls

- Do not use `trace-tool` on `internal-trace.jsonl`; `trace-tool` is for binary `trace/$pid.trace` files from `--tracing`/O1Trace.
- Do not assume `mina client start-internal-tracing` enables Rust Kimchi `internal_tracing`; current code toggles OCaml `Internal_tracing` and its prover/verifier subprocess logger callbacks.
- Do not ignore `prover-internal-trace.jsonl` and `verifier-internal-trace.jsonl`; daemon-level `internal-trace.jsonl` will miss subprocess-local checkpoints.
- Do not reorder JSONL lines before interpreting context. `current_block` and `current_call_id` are stream context events.
- Do not add backward-compatible trace handling unless persisted external trace consumers require it; otherwise keep trace format changes minimal and documented.

## Verification

For code changes, prefer the smallest targeted check that exercises the touched layer:

- OCaml type check for tracing/library changes: `dune build @check`.
- Specific internal tracing library check: `dune build src/lib/internal_tracing`.
- CLI command changes: build the CLI target if feasible, e.g. `dune build src/app/cli/src/mina.exe`.
- Rust proof-system changes: use cargo only in the relevant proof-systems/stubs context, and be mindful of repo offline/vendor setup.

For trace-file analysis only, no build is needed; summarize the file and report the trace system, files inspected, notable checkpoints/gaps, and any malformed/truncated lines.
