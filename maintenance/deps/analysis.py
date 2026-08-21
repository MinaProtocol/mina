"""Analyses layered on top of the parsed dune graph.

Everything here is a heuristic over source text; nothing is authoritative
until `dune build @check` agrees. The checks are therefore written as
*ratchets* over a committed baseline: they fail on change, not on absolute
state, so the existing debt does not have to be paid off before the gate can
be turned on.
"""

import fnmatch
import re
from pathlib import PurePosixPath

# Dependencies that legitimately never appear as a module reference: ppx
# runtimes, C stub packages and instrumentation backends are linked for their
# side effects.
INVISIBLE_DEP_RE = re.compile(
    r"(ppx|runtime|config|stubs|bindings|bisect|instrument)", re.IGNORECASE
)

# A dependency is "thin" if it is referenced this many times or fewer.
THIN_REFERENCE_LIMIT = 12

# Ignore edges below this closure impact; they are hygiene, not weight.
IMPACT_THRESHOLD = 5


def entrypoints(graph):
    """Every executable. These are what the dependency budget is pinned to."""
    return sorted(nid for nid, node in graph.nodes.items() if node.is_executable)


def shipped_entrypoints(graph):
    """Executables we actually ship or run as tools, used to rank impact."""
    result = []
    for nid in entrypoints(graph):
        directory = graph.nodes[nid].directory
        # `parts` is empty for the tree root ("."), which `split("/")` used to
        # render as ["."]; guard rather than index blindly.
        segments = PurePosixPath(directory).parts
        if not segments or segments[0] != "app":
            continue
        if any(s in ("test", "tests", "bench", "benchmarks") for s in segments):
            continue
        result.append(nid)
    return result


def budget(graph):
    """Current transitive dependency counts per entrypoint."""
    return {
        nid: {
            "libs": len(graph.closure(nid)),
            "opam": len(graph.external_closure(nid)),
        }
        for nid in entrypoints(graph)
    }


def external_packages(graph):
    """Every opam package name referenced anywhere in the repo."""
    names = set()
    for deps in graph.external.values():
        for dep in deps:
            names.add(dep.split(".")[0])
    return sorted(names)


def impact_index(graph, targets=None):
    """Map each cuttable edge to its worst-case closure impact.

    Only bridge edges can have a non-zero impact, so we ask the graph for
    those first instead of sweeping all ~5800 edges per entrypoint.
    """
    if targets is None:
        targets = shipped_entrypoints(graph)
    index = {}
    for target in targets:
        for edge in graph.bridge_edges(target):
            reduction = graph.cut_impact(target, edge)
            if reduction <= 0:
                continue
            previous = index.get(edge)
            if previous is None or reduction > previous[0]:
                index[edge] = (reduction, target)
    return index


def unreferenced_deps(graph):
    """Declared internal dependencies with no module reference in the source.

    Skipped when the directory has no OCaml sources, when a rule generates a
    `.ml` there (we cannot see the generated text), or when the dependency is
    the kind that is linked for side effects only.
    """
    findings = []
    for nid in sorted(graph.edges):
        node = graph.nodes[nid]
        if node.generated:
            continue
        if not graph.sources(node.directory):
            continue
        for dep in graph.edges[nid]:
            dep_node = graph.nodes[dep]
            if dep_node.implements:
                continue
            if INVISIBLE_DEP_RE.search(dep_node.name) or INVISIBLE_DEP_RE.search(dep):
                continue
            if graph.references(nid, dep_node.module_name) == 0:
                findings.append((nid, dep))
    return findings


def used_symbols(graph, nid, dep):
    """Which submodules of `dep` the dependent actually touches."""
    module = graph.nodes[dep].module_name
    text = graph.sources(graph.nodes[nid].directory)
    pattern = r"\b%s\.([A-Z][A-Za-z0-9_']*)" % re.escape(module)
    return sorted(set(re.findall(pattern, text)))


def thin_deps(graph, index):
    """Heavy dependencies pulled in for a very small amount of use."""
    findings = []
    for edge, (reduction, target) in index.items():
        source, dep = edge
        source_node = graph.nodes[source]
        dep_node = graph.nodes[dep]
        if source_node.generated or not graph.sources(source_node.directory):
            continue
        if dep_node.implements or INVISIBLE_DEP_RE.search(dep_node.name):
            continue
        # A thin wrapper executable over its own library is not a finding.
        # (Path-relative check, not a string prefix: `app/archive` must not
        # swallow the sibling `app/archive_blocks`.)
        if source_node.is_executable and PurePosixPath(
            dep_node.directory
        ).is_relative_to(source_node.directory):
            continue
        count = graph.references(source, dep_node.module_name)
        if count == 0 or count > THIN_REFERENCE_LIMIT:
            continue
        findings.append((reduction, count, source, dep, target))
    findings.sort(key=lambda row: (-row[0], row[1]))
    return findings


def rule_violations(graph, rules):
    """Layering rules that are currently broken, with a witness path."""
    violations = []
    for rule in rules:
        for nid in sorted(graph.nodes):
            if not fnmatch.fnmatch(nid, rule["from"]):
                continue
            for reached in sorted(graph.closure(nid)):
                if not fnmatch.fnmatch(reached, rule["to"]):
                    continue
                path = graph.shortest_path(nid, reached)
                violations.append((rule, nid, reached, path))
                break
    return violations


def format_path(graph, path):
    return " -> ".join(graph.nodes[n].name for n in path)
