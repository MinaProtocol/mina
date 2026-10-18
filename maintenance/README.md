# Maintenance Utilities

## Dependency checks (CI)

`maintenance/deps` holds a dependency gate and advisor for the OCaml tree. It
parses `dune` files directly, so it needs no opam switch, no build and no
third-party package — only `python3` (3.12 or newer). A full scan of `src/`
takes a few seconds, which is what makes it affordable on every PR.

The CI job runs in the **Noble** toolchain image rather than the default
Bullseye one, whose Python 3.9 cannot parse this code. That cannot be recorded
as a comment next to the job: `dhall lint` strips comments, so the reason lives
here instead. If the job is ever moved back to a Bullseye-era image it will
fail at import, not silently misbehave.

```
make check-deps      # the CI gate: fails when the graph regresses
make deps-advice     # human report: which dependencies look removable
make deps-baseline   # re-pin the baseline after an intended change
```

`make check-deps` runs four checks, all of them *ratchets* against
`maintenance/deps/baseline.json`. They fail on change, not on absolute state,
so the debt that already exists does not have to be paid off first.

1. **Dependency budget.** Every executable's transitive internal library count
   and opam package count is pinned. Growth fails. Shrinkage also fails, so
   that improvements get recorded rather than silently reabsorbed.
2. **New opam dependencies.** Any third-party package that appears anywhere in
   the tree for the first time fails, to force a look from CODEOWNERS.
3. **Layering rules.** `maintenance/deps/rules.json` lists edges that must not
   exist (for example, nothing under `src/lib/crypto` may reach `mina_lib`).
   Failures print the shortest offending path, so the report says *why* the
   edge exists rather than just that it does.
4. **Unused dependencies with real weight.** A declared dependency whose module
   is never referenced in the dependent's source, and whose removal would drop
   at least five libraries from some shipped executable.

When a failure is legitimate — the dependency really is needed, or the growth
is intended — run `make deps-baseline` and commit the diff. The point is that
the number moves in a reviewable commit instead of drifting.

### Working on the checker itself

The code is laid out as a functional core with a thin imperative shell:

- `graph.py` — parsing and the graph model. `read_dune_files` and `SourceIndex`
  touch the filesystem; everything else is a pure function of what they return.
- `analysis.py` — pure analyses returning typed findings.
- `report.py` — the closed set of things `check` can complain about, and how
  each one reads. `render_failure` closes over the union with `assert_never`,
  so adding a failure kind without a rendering is a type error.
- `main.py` — the shell: argument parsing, file I/O, printing, exit codes.

Lint and type-check it with:

```
ruff check maintenance/deps && ruff format --check maintenance/deps
ty check maintenance/deps
```

Configuration lives in `maintenance/deps/pyproject.toml` and is scoped to this
directory; the rest of the repository's Python is not held to these rules yet.
Neither tool is in the CI image, so this is a local gate for now.

Behaviour is pinned by `baseline.json`: after any change here, regenerate it
with `make deps-baseline` and confirm the diff is empty. That is the fastest
way to prove a refactor changed nothing.

### Adding a layering rule

`rules.json` has two lists. `forbidden` is enforced; every rule in it holds
today. `pending` is for rules we want but that are currently violated: they are
printed by `make deps-advice` and ignored by `make check-deps`. Move a rule
from `pending` to `forbidden` in the same PR that fixes it.

### Known limitations

Resolution is syntactic, so it is an approximation of what dune actually does:

- `(select ... from ...)` is treated as depending on every alternative, and
  `%{...}` variables are dropped, because neither can be resolved without dune.
- `pkg.sublib` dependencies fall back to the containing package when the
  sublibrary is not declared in-tree.
- "Is this dependency referenced?" is answered by scanning every source file in
  the stanza's directory for the dependency's module name. A directory holding
  several stanzas can therefore hide an unused dependency — the check
  under-reports rather than over-reports, which is the safe direction for
  something that tells people to delete code.
- Dependencies that are never named in source are excluded rather than
  reported: implementations of virtual libraries (`(implements ...)`, chosen by
  linking) and ppx runtime support libraries. The latter is decided from the
  dependent's own `(preprocess (pps ...))` and `(instrumentation (backend ...))`
  -- a stanza that runs `ppx_version` may depend on `ppx_version.runtime`
  without ever naming it, because the preprocessor emits the code that uses it.
  Nothing is excluded by name pattern, so an ordinary library is still reported
  even when it is called `runtime_config` or lives under a `stubs/` directory.
- Directories where a `(rule)` generates a `.ml` are skipped entirely for the
  unused-dependency check, since the generated text is not there to grep.

Everything `make deps-advice` prints is a candidate, not a verdict. Confirm
each removal with `dune build @check` before pushing it.

## Dependency graph rendering

`make deps-dot` writes the graph in DOT to `maintenance/deps.dot`; render it
with graphviz:

```
make deps-dot && dot -Tpng maintenance/deps.dot > maintenance/deps.png
```

To look at one library or executable rather than all 546 stanzas, pass a node
id and get that node, everything it reaches, and everything that reaches it:

```
python3 maintenance/deps/main.py dot --around exe:app/cli/src:mina > mina.dot
```

Node ids are the same `<lib|exe>:<dir under src>:<name>` used everywhere else
in this directory — by `rules.json`, by `baseline.json` and by the advice
output. Passing a bare library name reports the id you probably meant.

This replaces the older `gen_deps.sh`/`narrow_deps.sh` pair, which needed
`dune-deps` from opam plus graphviz's `gvpr`, and which spoke a different node
id vocabulary (`exe:./src/app/cli/src/dune:0`) from the rest of the tooling.
Only the rendering step needs graphviz now; producing the DOT needs nothing but
`python3`.

