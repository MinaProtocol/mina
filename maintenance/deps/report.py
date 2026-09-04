"""What `check` can complain about, and how each complaint reads.

The failures are a closed union so that adding a new kind of check is a
type error until it is also given a rendering: `render_failure` closes over
the union with `assert_never`.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import assert_never

from analysis import Budget, Metric, RuleViolation, format_path
from graph import DuneGraph, NodeId

BASELINE_HINT = "run `make deps-baseline` and commit maintenance/deps/baseline.json"


@dataclass(frozen=True, slots=True)
class NewEntrypoint:
    """An executable exists that the baseline has never seen."""

    entrypoint: NodeId
    budget: Budget


@dataclass(frozen=True, slots=True)
class MissingEntrypoint:
    """The baseline pins an executable that is no longer in the tree."""

    entrypoint: NodeId


@dataclass(frozen=True, slots=True)
class BudgetMoved:
    """An entrypoint got heavier or lighter than its pin."""

    entrypoint: NodeId
    metric: Metric
    was: int
    now: int

    @property
    def grew(self) -> bool:
        return self.now > self.was


@dataclass(frozen=True, slots=True)
class OpamPackageAdded:
    """A third-party package appeared in the tree for the first time."""

    package: str


@dataclass(frozen=True, slots=True)
class OpamPackageRemoved:
    """A pinned third-party package is no longer used anywhere."""

    package: str


@dataclass(frozen=True, slots=True)
class LayeringBroken:
    """An edge exists that a forbidden rule says must not."""

    violation: RuleViolation


@dataclass(frozen=True, slots=True)
class UnusedHeavyDep:
    """A dependency nothing references, whose removal would drop real weight."""

    source: NodeId
    dep: NodeId
    reduction: int


Failure = (
    NewEntrypoint
    | MissingEntrypoint
    | BudgetMoved
    | OpamPackageAdded
    | OpamPackageRemoved
    | LayeringBroken
    | UnusedHeavyDep
)


def render_failure(graph: DuneGraph, failure: Failure) -> str:
    """One human-readable paragraph per failure, ending in what to do."""
    match failure:
        case NewEntrypoint(entrypoint=entrypoint, budget=budget):
            return (
                f"new executable {entrypoint} ({budget.libs} libs, "
                f"{budget.opam} opam packages) is not in the baseline\n"
                f"    -> {BASELINE_HINT}"
            )
        case MissingEntrypoint(entrypoint=entrypoint):
            return f"executable {entrypoint} disappeared from the tree\n    -> {BASELINE_HINT}"
        case BudgetMoved(entrypoint=entrypoint, metric=metric, was=was, now=now) if failure.grew:
            return (
                f"{entrypoint} gained {now - was} {metric.label} ({was} -> {now})\n"
                "    -> a dune change made this executable heavier; drop the dependency,\n"
                f"       or if it is intended, {BASELINE_HINT}"
            )
        case BudgetMoved(entrypoint=entrypoint, metric=metric, was=was, now=now):
            return (
                f"{entrypoint} lost {was - now} {metric.label} ({was} -> {now}) "
                f"-- nice, but the baseline must record it\n    -> {BASELINE_HINT}"
            )
        case OpamPackageAdded(package=package):
            return (
                f"new opam dependency introduced: {package}\n"
                "    -> new third-party packages need a look from CODEOWNERS; "
                f"once agreed, {BASELINE_HINT}"
            )
        case OpamPackageRemoved(package=package):
            return f"opam dependency {package} is no longer used\n    -> {BASELINE_HINT}"
        case LayeringBroken(violation=violation):
            return (
                f"layering rule broken: {violation.rule.from_pattern} must not reach "
                f"{violation.rule.to_pattern}\n"
                f"    {violation.rule.why}\n"
                f"    via {format_path(graph, violation.path)}"
            )
        case UnusedHeavyDep(source=source, dep=dep, reduction=reduction):
            source_node = graph.nodes[source]
            dep_node = graph.nodes[dep]
            return (
                f"{source_node.name} declares {dep_node.name} but never references "
                f"{dep_node.module_name}, and it costs {reduction} libraries\n"
                f"    -> delete it from {source_node.directory}/dune, or if it is "
                f"linked for side effects, {BASELINE_HINT}"
            )
        case _ as unreachable:
            assert_never(unreachable)
