---
name: mina-changelog
description: Use when the user asks to write, add, or fix a changelog entry for a MinaProtocol/mina PR, or when CI fails with "Missing changelog entry detected". Use this skill to produce a correctly named changes/<PR>.md written for end users, instead of pasting the PR description or commit message.
---

# Mina Changelog Entries

Use this skill when working in `MinaProtocol/mina` and the user asks for a changelog entry, a `changes/` file, or is fixing the `Lint: Changelog` CI job.

Entries feed the Release Notes for an upcoming release. The reader is a node operator, exchange integrator, or zkApp developer — someone who runs Mina but has never opened this repo. Write for them.

## Hard rules from CI

The `Lint: Changelog` job (`buildkite/scripts/changelog.sh`, wired up in `buildkite/src/Jobs/Lint/Changelog.dhall`) enforces:

- The file must be exactly `changes/<PR_NUMBER>.md` — no title slug, no other extension. `changes/19080.md`, never `changes/19080-fix-archive.md`.
- It is required whenever the PR touches anything under `src/`. PRs that only touch CI, docs, or scripts do not need one.
- The check only runs on the `mina-o-1-labs` PR pipeline, so it appears after `!ci-build-me`.
- An org member can bypass it by commenting `!ci-bypass-changelog` on the PR. Only suggest this for genuinely user-invisible `src/` changes (e.g. a test-only refactor); do not offer it as a shortcut around writing an entry.

## Writing the entry

Structure is a short title line, a blank line, then one or two short paragraphs. Many existing entries in `changes/` are messier than this — mimic the good short ones (`18789.md`, `18942.md`, `18774.md`), not the ones that paste in a whole PR description with `# Summary` / `## Changes` headers.

- **Title line**: plain sentence naming the user-visible outcome. Start with a verb — Fix, Add, Remove, Speed up. No `# PR 12345:` prefix; the filename already carries the number.
- **Body**: what changed from the operator's point of view. For a bug fix, say what went wrong and when they'd have hit it; for a feature, say what it lets them do; for a performance change, give the number if there is one.
- Length: usually 2–5 sentences total. Anything longer belongs in the PR description.

Keep out:

- Internal function, module, and helper names (`Mina_caqti.upsert_into_cols_returning`, `add_if_doesn't_exist`).
- File paths, SQL, table and column names, flag-by-flag implementation detail.
- Restating the diff. The PR description covers mechanism; the changelog covers effect.

Name a CLI flag, config field, GraphQL field, or metric when the user types or reads it — that is user-facing surface, not implementation detail. Link an issue only when it adds context an operator would look up.

## Procedure

1. Get the PR number: `gh pr view --repo MinaProtocol/mina --json number,title,body`, or ask if the branch has no PR yet.
2. Read the actual diff (`git diff origin/develop...HEAD --stat`), not just the PR description — the description is written for reviewers and usually over-explains mechanism.
3. Confirm the PR touches `src/`; if not, say the entry is optional before writing one.
4. Ask yourself what breaks or improves for someone running a node, and lead with that.
5. Write `changes/<PR>.md`.
6. Show the entry in the reply so the user can react to the wording without opening the file.

## Example

For PR #19080, which replaced select-then-insert archive dedup with `INSERT ... ON CONFLICT` upserts across eight tables:

```markdown
Fix archive node block insertion failing when blocks are processed in parallel

When two blocks were inserted at the same time and shared data such as a zkApp command, a public key, or a token, the archive node could fail with a database uniqueness error and abandon the whole block. Inserts now let the database resolve these collisions, so concurrent block insertion succeeds.
```

The table list, the new `Mina_caqti` helpers, and the `ON CONFLICT` clauses all stayed in the PR description. An operator only needs to know their archive node stops dropping blocks.
