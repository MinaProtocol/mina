"""CI jobs for Rust crates, driven by Dagger.

A `Job` is a named unit of CI work exposing a single `run` method. `RustApp`
implements it for one standalone Rust crate: `run` performs a `cargo check` gate
and then, if the crate has tests, `cargo test`. Those two steps are internal — a
crate exposes only `run`, not the individual cargo commands.

The concrete crates and the set that CI runs live in `mina_ci.jobs`; this module
is the reusable machinery: the container builder, the system-package installer,
and `RustApp` itself.

Container mechanics:
  - System packages install *before* the source is mounted, so the apk layer's
    Dagger cache key is (image, package list) only and survives source edits.
  - The cargo registry and each crate's `target/` dir are engine cache volumes,
    so compiled dependencies persist across runs.
  - Every cargo invocation redirects stderr into stdout (`2>&1`) so compile
    progress and the test harness's per-test results arrive faithfully ordered;
    a non-zero exit raises `dagger.ExecError` carrying that combined output.

Call `run` inside an open `dagger.connection()` (see `mina_ci.__main__`).
"""

from __future__ import annotations

from pathlib import Path
from typing import Protocol

import dagger
from dagger import dag
from pydantic import BaseModel


class RustToolchain(BaseModel, frozen=True):
    """Pinned Rust version and cache identity for a job's container.

    These values cross the CLI boundary — cyclopts exposes each field as a
    ``--toolchain.<field>`` option — so this is a Pydantic model.

    Attributes:
        rust_version: Tag for the ``rust:<v>-alpine`` base image.
        cargo_cache_volume: Cache volume backing the shared cargo registry.
        target_cache_prefix: Prefix for per-crate ``target/`` cache volumes.
    """

    rust_version: str = "1.92.0"
    cargo_cache_volume: str = "mina-ci-cargo"
    target_cache_prefix: str = "mina-ci-cargo-target"


class Job(Protocol):
    """A named unit of CI work that produces a textual log when run.

    The execution context (`toolchain`, `repo_root`) is supplied at run time
    rather than baked into the job, so the same job can run against a different
    toolchain or checkout.
    """

    @property
    def name(self) -> str:
        """Short identifier for the job (used to label output and CLI commands)."""
        ...

    async def run(self, toolchain: RustToolchain, repo_root: Path) -> str:
        """Run the job and return its combined, human-readable output."""
        ...


def default_repo_root() -> Path:
    """Best-effort repository root: the nearest ancestor of the cwd holding `src/app`.

    A convenience for callers that want to auto-detect the root from where the
    tool is run (typically the `ci/` dir or the repo root). It is *not* called
    implicitly — pass the result (or any other root) in as `repo_root`.

    Raises:
        RuntimeError: if no `src/app` directory is found at or above the cwd.
    """
    for directory in (Path.cwd(), *Path.cwd().parents):
        if (directory / "src" / "app").is_dir():
            return directory
    raise RuntimeError("could not locate the repository root (no `src/app` at or above the cwd)")


def base(toolchain: RustToolchain) -> dagger.Container:
    """Build the bare Rust image with the shared cargo registry cache — no source yet.

    Deliberately does *not* mount the source tree: system-package installs are
    layered on top of this, and keeping them upstream of the source mount means
    their Dagger cache key depends only on the image and package list, so they
    stay cached across every source edit.
    """
    return (
        dag.container()
        .from_(f"rust:{toolchain.rust_version}-alpine")
        # Share the registry index and downloaded crates across every run and crate.
        .with_mounted_cache("/usr/local/cargo/registry", dag.cache_volume(toolchain.cargo_cache_volume))
    )


def with_system_packages(container: dagger.Container, packages: tuple[str, ...]) -> dagger.Container:
    """Install `packages` via apk, or return `container` unchanged when the list is empty.

    The `rust:-alpine` base ships no `-dev` system libraries, so crates with
    C-FFI dependencies (e.g. ``openssl-sys``) must pull in their headers
    explicitly.
    """
    if not packages:
        return container
    return container.with_exec(["apk", "add", "--no-cache", *packages])


class RustApp(BaseModel, frozen=True):
    """A standalone Rust crate as a CI `Job`.

    Implements `Job`: `run` performs a `cargo check` gate and, if the crate has
    tests, a `cargo test`. The crate is standalone (its own `Cargo.toml`/
    `Cargo.lock`, no path dependencies), so its source is just its own directory.

    Attributes:
        name: Short identifier, used to label steps and name the target cache.
        path: Crate directory, relative to the repository root.
        system_packages: Alpine (apk) packages this crate needs to build — e.g.
            the OpenSSL headers for a crate depending on ``openssl-sys``. Empty
            for crates with no system build deps; installed only when non-empty.
        has_tests: Whether `run` should include a `cargo test` step.
    """

    name: str
    path: str
    system_packages: tuple[str, ...] = ()
    has_tests: bool = False

    def _crate_directory(self, repo_root: Path) -> dagger.Directory:
        """Mount the crate's own source tree (`repo_root / path`) from the host."""
        return dag.host().directory(str(repo_root / self.path))

    async def _cargo(self, toolchain: RustToolchain, repo_root: Path, subcommand: str) -> str:
        """Run `cargo <subcommand>` in this crate, returning stdout+stderr merged in order."""
        prepared = with_system_packages(base(toolchain), self.system_packages)
        return await (
            prepared.with_mounted_directory("/src", self._crate_directory(repo_root))
            # The crate's own `target/`, cached across runs (and shared between
            # check and test, so test reuses check's compiled dependencies).
            .with_mounted_cache("/src/target", dag.cache_volume(f"{toolchain.target_cache_prefix}-{self.name}"))
            .with_workdir("/src")
            .with_exec(["sh", "-c", f"cargo {subcommand} 2>&1"])
            .stdout()
        )

    async def run(self, toolchain: RustToolchain, repo_root: Path) -> str:
        """Run this crate's CI job: `cargo check`, then `cargo test` if it has tests.

        `cargo check` is a fast internal gate that fails on plain compile errors
        before the heavier test build.

        Args:
            toolchain: Pinned Rust version and cache identity.
            repo_root: Repository root this crate's `path` is resolved against.

        Returns:
            The concatenated, labelled output of each step.
        """
        sections = [
            f"=== cargo check: {self.name} ({self.path}) ===",
            await self._cargo(toolchain, repo_root, "check"),
        ]
        if self.has_tests:
            sections += [
                f"=== cargo test: {self.name} ({self.path}) ===",
                await self._cargo(toolchain, repo_root, "test"),
            ]
        return "\n".join(sections)
