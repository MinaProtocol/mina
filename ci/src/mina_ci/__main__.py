"""Command-line entrypoint for the Mina CI layer, driven by Dagger.

There is one command per component (`minimina`, `trace-tool`, …), plus `all`.
Each component command runs that crate's job — a `cargo check` gate, then
`cargo test` if the crate has tests. Components act on the repo's crates at their
fixed locations, so there is no source path to pass. The repo root is
auto-detected from the cwd (run from the `ci/` dir or anywhere at/above
`src/app`); override it with `--repo-root` to point at another checkout.

This is the imperative shell. The cross-cutting effects — opening the Dagger
connection and turning a failed tool into a process exit code — live once in the
`app.meta` launcher that wraps every command. Each command is then a pure mapping
from CLI arguments to a job call, returning the tool's stdout; cyclopts prints
that return value. The jobs live in `mina_ci.jobs` (over helpers in `mina_ci.rust`).
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Annotated

import dagger
from cyclopts import App, Parameter

from . import jobs
from .rust import Job, RustToolchain, default_repo_root

app = App(
    name="mina-ci",
    help="Mina Protocol CI layer, driven by Dagger (library mode).",
)

# Shared default for command signatures. A module-level singleton (rather than a
# `RustToolchain()` call in each default) keeps the defaults immutable and
# B008-clean; cyclopts still exposes every field as an overridable
# `--toolchain.*` option.
_DEFAULT_RUST_TOOLCHAIN = RustToolchain()


def _register_component(component: Job) -> None:
    """Register a `mina-ci <component>` command running that job.

    A factory (rather than a loop body) so each command closes over its own
    `component` binding.
    """

    async def _cmd(*, toolchain: RustToolchain = _DEFAULT_RUST_TOOLCHAIN, repo_root: Path | None = None) -> str:
        return await component.run(toolchain, repo_root or default_repo_root())

    _cmd.__name__ = component.name
    _cmd.__doc__ = f"Run the `{component.name}` CI job."
    app.command(_cmd, name=component.name)


for _component in jobs.COMPONENTS:
    _register_component(_component)


@app.command(name="all")
async def all_cmd(*, toolchain: RustToolchain = _DEFAULT_RUST_TOOLCHAIN, repo_root: Path | None = None) -> str:
    """Run every component's job in order."""
    return await jobs.run_all(toolchain, repo_root or default_repo_root())


@app.meta.default
async def _launcher(
    *tokens: Annotated[str, Parameter(show=False, allow_leading_hyphen=True)],
) -> None:
    """Wrap every command with the Dagger connection and exit-code handling.

    Raises:
        SystemExit: with code 1 if the underlying tool exits non-zero (e.g. a
            failing check or test); the tool's output is surfaced first.
    """
    config = dagger.Config(log_output=sys.stderr)
    async with dagger.connection(config):
        try:
            print(await app.run_async(tokens, exit_on_error=False))
        except dagger.ExecError as err:
            if err.stdout:
                print(err.stdout)
            if err.stderr:
                print(err.stderr, file=sys.stderr)
            raise SystemExit(1) from err


def main() -> None:
    """Console-script entrypoint (see [project.scripts] in pyproject.toml)."""
    app.meta()


if __name__ == "__main__":
    main()
