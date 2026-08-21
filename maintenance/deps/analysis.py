"""Analyses over the parsed dune graph.

Everything here is a heuristic over source text; nothing is authoritative
until `dune build @check` agrees. The checks are therefore written as
*ratchets* over a committed baseline: they fail on change, not on absolute
state, so the existing debt does not have to be paid off before the gate can
be turned on.

Pure: these functions read a `DuneGraph` and a `SourceIndex` and return typed
findings. Rendering and I/O belong to the caller.
"""

from __future__ import annotations

import fnmatch
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from enum import Enum
from pathlib import PurePosixPath

from graph import DuneGraph, Edge, Node, NodeId, SourceIndex

# A dependency is "thin" if it is referenced this many times or fewer.
THIN_REFERENCE_LIMIT = 12

# Ignore edges below this closure impact; they are hygiene, not weight.
IMPACT_THRESHOLD = 5

# Directory segments that mark an executable as a test or benchmark rather
# than something we ship.
NON_SHIPPED_SEGMENTS = frozenset({"test", "tests", "bench", "benchmarks"})

SHIPPED_ROOT = "app"


class Metric(Enum):
    """The two numbers the dependency budget pins per executable."""

    LIBS = "libs"
    OPAM = "opam"

    @property
    def label(self) -> str:
        return "internal libraries" if self is Metric.LIBS else "opam packages"


@dataclass(frozen=True, slots=True)
class Budget:
    """Transitive weight of one entrypoint."""

    libs: int
    opam: int

    def get(self, metric: Metric) -> int:
        return self.libs if metric is Metric.LIBS else self.opam


@dataclass(frozen=True, slots=True)
class LayeringRule:
    """A `from` pattern that must not reach a `to` pattern."""

    from_pattern: str
    to_pattern: str
    why: str


@dataclass(frozen=True, slots=True)
class Impact:
    """What cutting an edge would save, and for which entrypoint."""

    reduction: int
    target: NodeId


@dataclass(frozen=True, slots=True)
class UnreferencedDep:
    """A declared dependency with no module reference in the source."""

    source: NodeId
    dep: NodeId


@dataclass(frozen=True, slots=True)
class ThinDep:
    """A heavy dependency pulled in for a very small amount of use."""

    reduction: int
    references: int
    source: NodeId
    dep: NodeId
    target: NodeId


@dataclass(frozen=True, slots=True)
class RuleViolation:
    """A layering rule that is currently broken, with a witness path."""

    rule: LayeringRule
    source: NodeId
    reached: NodeId
    path: tuple[NodeId, ...]


ImpactIndex = Mapping[Edge, Impact]


def generated_reference(graph: DuneGraph, source: NodeId, dep: Node) -> bool:
    """True when `source`'s preprocessor, not its source text, uses `dep`.

    A ppx's runtime support library (`ppx_version.runtime`,
    `ppx_inline_test.config`) is referenced only by code the preprocessor
    emits, so scanning the checked-in source can never find it and reporting
    it as unused would tell people to break their build.

    Decided from what the dependent's own stanza declares it runs -- so this
    holds only for a stanza that actually invokes the ppx, and says nothing
    about libraries whose *name* merely resembles one.
    """
    ppx = graph.nodes[source].ppx
    if not ppx:
        return False
    return any(name.split(".")[0] in ppx for name in dep.declared_names)


def entrypoints(graph: DuneGraph) -> list[NodeId]:
    """Every executable. These are what the dependency budget is pinned to."""
    return sorted(node_id for node_id, node in graph.nodes.items() if node.is_executable)


def shipped_entrypoints(graph: DuneGraph) -> list[NodeId]:
    """Executables we actually ship or run as tools, used to rank impact."""
    result: list[NodeId] = []
    for node_id in entrypoints(graph):
        # `parts` is empty for the tree root ("."); guard rather than index.
        segments = PurePosixPath(graph.nodes[node_id].directory).parts
        if not segments or segments[0] != SHIPPED_ROOT:
            continue
        if any(segment in NON_SHIPPED_SEGMENTS for segment in segments):
            continue
        result.append(node_id)
    return result


def budgets(graph: DuneGraph) -> dict[NodeId, Budget]:
    """Current transitive dependency counts per entrypoint."""
    return {
        node_id: Budget(
            libs=len(graph.closure(node_id)),
            opam=len(graph.external_closure(node_id)),
        )
        for node_id in entrypoints(graph)
    }


def external_packages(graph: DuneGraph) -> list[str]:
    """Every opam package name referenced anywhere in the repo."""
    names: set[str] = set()
    for deps in graph.external.values():
        names.update(dep.split(".")[0] for dep in deps)
    return sorted(names)


def impact_index(graph: DuneGraph, targets: Sequence[NodeId] | None = None) -> ImpactIndex:
    """Map each cuttable edge to its worst-case closure impact.

    Only bridge edges can have a non-zero impact, so we ask the graph for
    those first instead of sweeping all ~5800 edges per entrypoint.
    """
    if targets is None:
        targets = shipped_entrypoints(graph)
    index: dict[Edge, Impact] = {}
    for target in targets:
        for edge in graph.bridge_edges(target):
            reduction = graph.cut_impact(target, edge)
            if reduction <= 0:
                continue
            previous = index.get(edge)
            if previous is None or reduction > previous.reduction:
                index[edge] = Impact(reduction=reduction, target=target)
    return index


def impact_of(index: ImpactIndex, edge: Edge) -> int:
    found = index.get(edge)
    return 0 if found is None else found.reduction


def _is_own_library(source: Node, dep: Node) -> bool:
    """A thin wrapper executable over its own library is not a finding.

    Path-relative rather than a string prefix: `app/archive` must not swallow
    the sibling `app/archive_blocks`.
    """
    if not source.is_executable:
        return False
    return PurePosixPath(dep.directory).is_relative_to(source.directory)


def unreferenced_deps(graph: DuneGraph, sources: SourceIndex) -> list[UnreferencedDep]:
    """Declared internal dependencies with no module reference in the source.

    Skipped when the directory has no OCaml sources, when a rule generates a
    `.ml` there (we cannot see the generated text), or when the dependency is
    the kind that only generated code names.
    """
    findings: list[UnreferencedDep] = []
    for source_id in sorted(graph.edges):
        source = graph.nodes[source_id]
        if source.generated or not sources.has_sources(source.directory):
            continue
        for dep_id in graph.successors(source_id):
            dep = graph.nodes[dep_id]
            if dep.implements or generated_reference(graph, source_id, dep):
                continue
            if sources.references(source, dep.module_name) == 0:
                findings.append(UnreferencedDep(source=source_id, dep=dep_id))
    return findings


def thin_deps(graph: DuneGraph, sources: SourceIndex, index: ImpactIndex) -> list[ThinDep]:
    """Heavy dependencies pulled in for a very small amount of use."""
    findings: list[ThinDep] = []
    for edge, impact in index.items():
        source_id, dep_id = edge
        source = graph.nodes[source_id]
        dep = graph.nodes[dep_id]
        if source.generated or not sources.has_sources(source.directory):
            continue
        if dep.implements or generated_reference(graph, source_id, dep):
            continue
        if _is_own_library(source, dep):
            continue
        count = sources.references(source, dep.module_name)
        if count == 0 or count > THIN_REFERENCE_LIMIT:
            continue
        findings.append(
            ThinDep(
                reduction=impact.reduction,
                references=count,
                source=source_id,
                dep=dep_id,
                target=impact.target,
            )
        )
    findings.sort(key=lambda found: (-found.reduction, found.references))
    return findings


def rule_violations(graph: DuneGraph, rules: Sequence[LayeringRule]) -> list[RuleViolation]:
    """Layering rules that are currently broken, with a witness path."""
    violations: list[RuleViolation] = []
    for rule in rules:
        for node_id in sorted(graph.nodes):
            if not fnmatch.fnmatch(node_id, rule.from_pattern):
                continue
            for reached in sorted(graph.closure(node_id)):
                if not fnmatch.fnmatch(reached, rule.to_pattern):
                    continue
                path = graph.shortest_path(node_id, reached)
                violations.append(
                    RuleViolation(
                        rule=rule,
                        source=node_id,
                        reached=reached,
                        path=() if path is None else path,
                    )
                )
                break
    return violations


def format_path(graph: DuneGraph, path: Sequence[NodeId]) -> str:
    return " -> ".join(graph.nodes[node_id].name for node_id in path)
