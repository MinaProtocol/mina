"""The concrete Rust components — the instantiation layer.

This module only *declares* the repo's crates (each a `Job`) and runs the set.
How a component's job actually runs — its `cargo check` gate followed by
`cargo test` — is the `RustApp.run` implementation in `mina_ci.rust`.

This mirrors CI, where each component is scoped to its own job (the Buildkite
pipeline has a `minimina` unit-test job and checks `trace-tool`/`minimina`).
"""

from __future__ import annotations

from pathlib import Path

from .rust import Job, RustApp, RustToolchain

TRACE_TOOL = RustApp(name="trace-tool", path="src/app/trace-tool")

# `minimina`'s `openssl-sys` dependency needs the OpenSSL headers and pkgconfig
# to locate them; the musl `rust:-alpine` image ships neither. `cargo test`
# additionally *links* a test binary, and musl builds it static-pie, so it needs
# the static libssl.a/libcrypto.a from `openssl-libs-static` (the `-dev` package
# provides only the shared libs).
MINIMINA = RustApp(
    name="minimina",
    path="src/app/minimina",
    system_packages=("pkgconfig", "openssl-dev", "openssl-libs-static", "musl-dev"),
    has_tests=True,
)

# Every component with a job, in the order CI runs them.
COMPONENTS: tuple[Job, ...] = (TRACE_TOOL, MINIMINA)


async def run_all(toolchain: RustToolchain, repo_root: Path) -> str:
    """Run every component's job in order."""
    sections: list[str] = []
    for component in COMPONENTS:
        sections.append(await component.run(toolchain, repo_root))
    return "\n".join(sections)
