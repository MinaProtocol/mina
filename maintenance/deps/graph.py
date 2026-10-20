"""The dune dependency graph, built by parsing `dune` files.

Deliberately does *not* invoke dune: the whole point is that this runs in a few
seconds on every PR without a switch, without a build, and without any opam
package installed. The cost is that resolution is syntactic and therefore
approximate (see `KNOWN LIMITATIONS` in maintenance/README.md).

Layering: `read_dune_files` and `SourceIndex` touch the filesystem; everything
else is a pure function of what they return.
"""

from __future__ import annotations

import contextlib
import re
from collections import defaultdict, deque
from collections.abc import Iterable, Iterator, Mapping, Sequence
from dataclasses import dataclass
from enum import Enum
from itertools import pairwise
from pathlib import Path
from typing import NewType

from errors import DepsError, ErrorCode

# A node id looks like `<lib|exe>:<dir under root>:<name>`. It is a distinct
# type from a library *name* because confusing the two is a bug this tool has
# already shipped once: a check meant to match library names was matching node
# ids, whose directory component made it match far more than intended.
NodeId = NewType("NodeId", str)

Edge = tuple[NodeId, NodeId]

# A parsed s-expression: either an atom or a list of them.
type Sexp = str | list[Sexp]

# Directories that never contain first-party dune stanzas we care about.
#
# Three kinds. `_build`, `_opam` and `.git` sit outside dune's vocabulary --
# no dune file describes them. `node_modules` and `kimchi-stubs-vendors` mirror
# a declaration a dune file already makes: `(dirs :standard \ node_modules)` in
# snarky, and `(data_only_dirs src kimchi-stubs-vendors)` in the kimchi stubs.
# `docker-compose` mirrors nothing -- the three such directories under
# `src/app` hold only compose files, so pruning them is an optimisation.
#
# `kimchi-stubs-vendors` is the entry that earns its keep. It is a vendored
# Cargo registry -- ~140 third-party Rust crates, checked in so the stubs build
# offline -- and one of them, `ocaml-interop`, ships an OCaml test harness with
# its own `dune`. Walking into it adds `ocaml_rust_caller` to the entrypoints,
# which is what the dependency budget is pinned to, and registers the Rust test
# fixture `callable_rust` as an opam package, which trips the
# new-external-dependency check. Neither is Mina code.
#
# The match is on the bare directory name at any depth, which does not scale:
# it restates declarations the dune files already make, and misses the ones not
# listed here (`target`, from `(dirs :standard .cargo \ target)`). Reading
# `data_only_dirs` and `(dirs ...)` during the walk would subsume everything
# below `.git`.
PRUNED_DIRS = frozenset(
    {
        "_build",
        "_opam",
        ".git",
        "node_modules",
        "docker-compose",
        "kimchi-stubs-vendors",
    }
)

SOURCE_SUFFIXES = frozenset({".ml", ".mli", ".mll", ".mly"})

# Flag fields that can carry `-open Foo`, bringing `Foo` into scope without the
# source ever spelling it.
FLAG_FIELDS = ("flags", "ocamlopt_flags", "library_flags")


class StanzaKind(Enum):
    """The dune stanzas that produce a node in the graph."""

    LIBRARY = "library"
    EXECUTABLE = "executable"
    EXECUTABLES = "executables"
    TEST = "test"
    TESTS = "tests"

    @property
    def is_executable(self) -> bool:
        """Whether the dependency budget is pinned to this stanza.

        Narrower than `id_prefix`: `test`/`tests` are built like executables
        and share the `exe:` prefix, but they are not shipped, so they are not
        entrypoints.
        """
        return self in (StanzaKind.EXECUTABLE, StanzaKind.EXECUTABLES)

    @property
    def id_prefix(self) -> str:
        """The node id prefix. Everything that is not a library is `exe`."""
        return "lib" if self is StanzaKind.LIBRARY else "exe"


_BY_STANZA_NAME = {kind.value: kind for kind in StanzaKind}


# ------------------------------------------------------------------- parsing


def _strip_comments(text: str) -> str:
    """Remove `;`-to-end-of-line comments, respecting string literals."""
    out: list[str] = []
    index = 0
    size = len(text)
    in_string = False
    while index < size:
        char = text[index]
        if in_string:
            out.append(char)
            if char == "\\" and index + 1 < size:
                out.append(text[index + 1])
                index += 2
                continue
            if char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            out.append(char)
            index += 1
            continue
        if char == ";":
            while index < size and text[index] != "\n":
                index += 1
            continue
        out.append(char)
        index += 1
    return "".join(out)


_TOKEN_RE = re.compile(r'\(|\)|"(?:[^"\\]|\\.)*"|[^\s()]+')


def parse_sexps(text: str, source: Path | None = None) -> list[Sexp]:
    """Parse a dune file into a list of top-level s-expressions.

    Unbalanced parentheses raise. Returning what had been parsed so far would
    discard every complete stanza in the file and leave the graph quietly
    wrong: the libraries declared there become "removed opam package" and
    "missing entrypoint" failures blamed on whichever PR happens to run next.
    """
    tokens = _TOKEN_RE.findall(_strip_comments(text))
    stack: list[list[Sexp]] = []
    current: list[Sexp] = []
    for token in tokens:
        if token == "(":
            stack.append(current)
            current = []
        elif token == ")":
            if not stack:
                raise DepsError(
                    ErrorCode.DUNE_UNPARSEABLE,
                    f"{source or '<dune>'}: unbalanced `)`",
                    path=source,
                )
            parent = stack.pop()
            parent.append(current)
            current = parent
        else:
            current.append(token.strip('"'))
    if stack:
        raise DepsError(
            ErrorCode.DUNE_UNPARSEABLE,
            f"{source or '<dune>'}: {len(stack)} unclosed `(`",
            path=source,
        )
    return current


def field(sexp: Sequence[Sexp], key: str) -> list[Sexp] | None:
    """Return the arguments of the first `(key ...)` field, or None."""
    for item in sexp:
        if isinstance(item, list) and item and item[0] == key:
            return item[1:]
    return None


def _atoms(sexp: Sequence[Sexp]) -> list[str]:
    """Every atom in `sexp`, depth-first, discarding structure."""
    out: list[str] = []
    for item in sexp:
        if isinstance(item, str):
            out.append(item)
        else:
            out.extend(_atoms(item))
    return out


def _strings(items: Sequence[Sexp]) -> list[str]:
    return [item for item in items if isinstance(item, str)]


def flatten_libraries(items: Sequence[Sexp]) -> list[str]:
    """Flatten a `(libraries ...)` field into plain dependency names.

    Handles `(re_export foo)` and `(select ... from (dep -> impl))`; drops
    dune variables (`%{...}`) and `:standard`-style tokens, which we cannot
    resolve without dune itself.
    """
    out: list[str] = []
    for item in items:
        if isinstance(item, str):
            if item.startswith(("%{", ":")):
                continue
            out.append(item)
            continue
        if not item:
            continue
        head = item[0]
        if head == "re_export":
            out.extend(flatten_libraries(item[1:]))
        elif head == "select":
            for sub in item[1:]:
                if not isinstance(sub, list):
                    continue
                out.extend(
                    token for token in _strings(sub) if token != "->" and not token.endswith(".ml")
                )
        else:
            out.extend(flatten_libraries(item))
    return [dep for dep in out if dep and not dep.startswith("%{")]


def _ppx_package_names(args: Sequence[Sexp]) -> Iterator[str]:
    """The ppx packages in a `(pps ...)` / `(backend ...)` argument list.

    Everything after `--` is arguments for the ppx driver, not packages, and
    flags and dune variables can appear before it too. Taking them all would
    be harmless right now, but `(pps ppx_inline_test -- -inline-test-lib
    mina_base)` is ordinary dune, and it would put `mina_base` into this
    stanza's ppx set -- permanently hiding an unused dependency on it.
    """
    for name in _strings(args):
        if name == "--":
            return
        if name.startswith(("-", "%{")):
            continue
        yield name.split(".")[0]


def preprocessors(stanza: Sequence[Sexp]) -> frozenset[str]:
    """Ppx packages this stanza runs: `(preprocess (pps ...))`, `(instrumentation
    (backend ...))`.

    These are what makes a dependency legitimately invisible to `references`:
    the code that uses a ppx's runtime support library is emitted by the
    preprocessor, so it never appears in the source we scan. Names are reduced
    to their package (`ppx_deriving.show` -> `ppx_deriving`) because that is
    what a runtime sublibrary hangs off.
    """
    found: set[str] = set()

    def walk(node: Sexp) -> None:
        if not isinstance(node, list) or not node:
            return
        if node[0] in ("pps", "backend"):
            found.update(_ppx_package_names(node[1:]))
        for item in node:
            walk(item)

    walk(list(stanza))
    return frozenset(found)


def opened_modules(stanza: Sequence[Sexp]) -> frozenset[str]:
    """Modules brought into scope via `(flags ... -open Foo ...)`."""
    opened: set[str] = set()
    for key in FLAG_FIELDS:
        flags = field(stanza, key)
        if flags is None:
            continue
        for token, following in pairwise(_atoms(flags)):
            if token == "-open":
                opened.add(following.split(".")[0])
    return frozenset(opened)


def includes_subdirs(stanzas: Sequence[Sexp]) -> bool:
    """Whether `(include_subdirs ...)` extends this stanza's sources downward.

    `no` is the default and means what it says; any other mode (`unqualified`,
    `qualified`) pulls sources from subdirectories into the same stanza, so
    searching only the top directory would miss the code that references a
    dependency and report it as unused.
    """
    for stanza in stanzas:
        if not isinstance(stanza, list) or not stanza or stanza[0] != "include_subdirs":
            continue
        modes = _strings(stanza[1:])
        return bool(modes) and modes[0] != "no"
    return False


def generates_ml(stanzas: Sequence[Sexp]) -> bool:
    """Whether some `(rule)` here produces a `.ml`, which makes "is this
    dependency referenced?" unanswerable without a build."""
    for stanza in stanzas:
        if not isinstance(stanza, list) or not stanza or stanza[0] != "rule":
            continue
        targets = field(stanza, "targets") or field(stanza, "target") or []
        if any(name.endswith((".ml", ".mli")) for name in _strings(targets)):
            return True
    return False


# -------------------------------------------------------------------- model


@dataclass(frozen=True, slots=True)
class Node:
    """One `library`/`executable`-ish stanza."""

    id: NodeId
    kind: StanzaKind
    directory: str
    name: str
    public_names: tuple[str, ...]
    # True when a rule in this directory generates a `.ml`.
    generated: bool
    # Implementations of a virtual library (`(implements foo)`) are chosen by
    # linking them, so they are never named in the source of whatever depends
    # on them. They can never be reported as unused.
    implements: bool
    ppx: frozenset[str]
    opened: frozenset[str]

    @property
    def module_name(self) -> str:
        return self.name[:1].upper() + self.name[1:]

    @property
    def is_executable(self) -> bool:
        return self.kind.is_executable

    @property
    def declared_names(self) -> tuple[str, ...]:
        return (self.name, *self.public_names)


@dataclass(frozen=True, slots=True)
class DuneFile:
    """A parsed `dune`, with its directory relative to the scanned root."""

    directory: str
    stanzas: tuple[Sexp, ...]
    # `(include_subdirs unqualified|qualified)`: the stanzas here are compiled
    # from sources in subdirectories too, so that is where to look for
    # references.
    include_subdirs: bool = False


@dataclass(frozen=True, slots=True)
class _RawStanza:
    """A stanza's fields, before dependency names are resolved to node ids."""

    node: Node
    dependencies: tuple[str, ...]


# ---------------------------------------------------------------------- I/O


def _walk_dune_dirs(root: Path) -> Iterator[Path]:
    # Pruning relies on `Path.walk` being top-down, so that dropping names from
    # `dirnames` in place stops it descending into them.
    for directory, dirnames, filenames in root.walk():
        dirnames[:] = sorted(name for name in dirnames if name not in PRUNED_DIRS)
        if "dune" in filenames:
            yield directory


def read_dune_files(root: Path) -> list[DuneFile]:
    """Every `dune` under `root`, parsed, in a deterministic order.

    Sorted on the posix string rather than the `Path`: name resolution is
    first-writer-wins, so iteration order decides which stanza claims an
    ambiguous library name, and `PurePath` ordering compares parts (and does so
    differently across versions), which would make the graph depend on the
    interpreter.
    """
    files: list[DuneFile] = []
    for directory in sorted(_walk_dune_dirs(root), key=Path.as_posix):
        path = directory / "dune"
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError as error:
            # Skipping an unreadable dune silently loses every library it
            # declares, which surfaces later as unrelated baseline failures.
            raise DepsError(
                ErrorCode.DUNE_UNREADABLE, f"cannot read {path}: {error}", path=path
            ) from error
        stanzas = tuple(parse_sexps(text, source=path))
        files.append(
            DuneFile(
                # `.as_posix()` keeps node ids stable strings for baseline.json.
                directory=directory.relative_to(root).as_posix(),
                stanzas=stanzas,
                include_subdirs=includes_subdirs(stanzas),
            )
        )
    return files


class SourceIndex:
    """OCaml source text per directory, read on demand and cached."""

    def __init__(self, root: Path, recursive: frozenset[str] = frozenset()) -> None:
        self._root = root
        self._recursive = recursive
        self._cache: dict[str, str] = {}

    def text(self, directory: str) -> str:
        cached = self._cache.get(directory)
        if cached is not None:
            return cached
        chunks: list[str] = []
        base = self._root / directory
        try:
            entries = (
                sorted(path for path in base.rglob("*") if path.is_file())
                if directory in self._recursive
                else sorted(base.iterdir())
            )
        except OSError:
            entries = []
        for entry in entries:
            if entry.suffix not in SOURCE_SUFFIXES:
                continue
            with contextlib.suppress(OSError):
                chunks.append(entry.read_text(encoding="utf-8", errors="replace"))
        text = "\n".join(chunks)
        self._cache[directory] = text
        return text

    def has_sources(self, directory: str) -> bool:
        return bool(self.text(directory))

    def references(self, node: Node, module_name: str) -> int:
        """Count references to `module_name` from `node`'s directory.

        Over-approximates on purpose: it scans every source file in the
        directory rather than only the stanza's `(modules ...)`, so a shared
        directory can mask an unused dependency. Under-reporting is the safe
        direction for a check that tells people to delete things.
        """
        if module_name in node.opened:
            return 1
        text = self.text(node.directory)
        if not text:
            return 0
        return len(re.findall(rf"\b{re.escape(module_name)}\b", text))

    def used_symbols(self, node: Node, module_name: str) -> list[str]:
        """Which submodules of `module_name` the dependent actually touches."""
        pattern = rf"\b{re.escape(module_name)}\.([A-Z][A-Za-z0-9_']*)"
        return sorted(set(re.findall(pattern, self.text(node.directory))))


# -------------------------------------------------------------------- build


def _derived_name(public_name: str) -> str:
    """The private name dune infers from a public one.

    Dots become underscores, matching how the tree spells it by hand -- e.g.
    `(public_name pasta_bindings.backend.native)` is `(name
    pasta_bindings_backend_native)`.
    """
    return public_name.replace(".", "_")


def _read_stanza(
    kind: StanzaKind, stanza: Sequence[Sexp], directory: str, generated: bool
) -> list[_RawStanza]:
    """Every node a single stanza declares, with its raw dependency names."""
    publics = field(stanza, "public_name") or field(stanza, "public_names") or []
    names = field(stanza, "name") or field(stanza, "names")
    if not names:
        # `(library (public_name foo))` is legal: dune derives the private name
        # from the public one. Dropping such a stanza does not merely lose a
        # node -- dependents' edges to it then fail to resolve and it gets
        # recorded as an *opam package*, which is what the new-third-party-
        # dependency check exists to notice.
        names = [_derived_name(public) for public in _strings(publics)]
    if not names:
        return []
    dependencies = tuple(flatten_libraries(field(stanza, "libraries") or []))
    public_names = tuple(_strings(publics))
    implements = field(stanza, "implements") is not None
    ppx = preprocessors(stanza)
    opened = opened_modules(stanza)
    return [
        _RawStanza(
            node=Node(
                id=NodeId(f"{kind.id_prefix}:{directory}:{name}"),
                kind=kind,
                directory=directory,
                name=name,
                public_names=public_names,
                generated=generated,
                implements=implements,
                ppx=ppx,
                opened=opened,
            ),
            dependencies=dependencies,
        )
        for name in _strings(names)
    ]


def _read_all(dune_files: Iterable[DuneFile]) -> list[_RawStanza]:
    raw: list[_RawStanza] = []
    for dune_file in dune_files:
        generated = generates_ml(dune_file.stanzas)
        for stanza in dune_file.stanzas:
            if not isinstance(stanza, list) or not stanza:
                continue
            head = stanza[0]
            kind = _BY_STANZA_NAME.get(head) if isinstance(head, str) else None
            if kind is None:
                continue
            raw.extend(_read_stanza(kind, stanza, dune_file.directory, generated))
    return raw


@dataclass(frozen=True, slots=True)
class NameCollision:
    """Two stanzas declared the same name; the first one sorted wins."""

    name: str
    winner: NodeId
    losers: tuple[NodeId, ...]


def _build_alias(
    raw: Sequence[_RawStanza],
) -> tuple[dict[str, NodeId], tuple[NameCollision, ...]]:
    """Map every declared name to the first stanza that claimed it.

    First-writer-wins is what dune-less resolution can offer, but it is silent:
    `(libraries test)` would bind to whichever stanza sorted first out of the
    several that call themselves `test`. Report the collisions so the choice is
    at least visible.
    """
    alias: dict[str, NodeId] = {}
    contested: defaultdict[str, list[NodeId]] = defaultdict(list)
    for entry in raw:
        for name in entry.node.declared_names:
            claimed = alias.get(name)
            if claimed is None:
                alias[name] = entry.node.id
            elif claimed != entry.node.id:
                # A stanza naming itself twice (`name` == `public_name`) is not
                # a clash; only a *different* stanza wanting the name is.
                contested[name].append(entry.node.id)
    collisions = tuple(
        NameCollision(name=name, winner=alias[name], losers=tuple(losers))
        for name, losers in sorted(contested.items())
    )
    return alias, collisions


def _resolve(
    entry: _RawStanza, alias: Mapping[str, NodeId]
) -> tuple[tuple[NodeId, ...], tuple[str, ...]]:
    """Split a stanza's dependencies into in-tree edges and opam packages."""
    internal: set[NodeId] = set()
    external: set[str] = set()
    for dep in entry.dependencies:
        target = alias.get(dep)
        if target is None and "." in dep:
            # `pkg.sublib` shorthand: fall back to the containing package.
            target = alias.get(dep.split(".")[0])
        if target is None:
            external.add(dep)
        elif target != entry.node.id:
            internal.add(target)
    return tuple(sorted(internal)), tuple(sorted(external))


@dataclass(frozen=True, slots=True)
class DuneGraph:
    """Nodes and resolved edges. Pure data: every method is a query over it."""

    root: Path
    nodes: Mapping[NodeId, Node]
    edges: Mapping[NodeId, tuple[NodeId, ...]]
    external: Mapping[NodeId, tuple[str, ...]]
    # Names more than one stanza claims. Not fatal, but worth printing.
    collisions: tuple[NameCollision, ...] = ()

    def successors(self, node_id: NodeId) -> tuple[NodeId, ...]:
        return self.edges.get(node_id, ())

    def closure(self, start: NodeId, banned_edge: Edge | None = None) -> set[NodeId]:
        """Transitive internal dependencies of `start`, excluding `start`."""
        seen: set[NodeId] = set()
        queue = deque([start])
        while queue:
            node_id = queue.popleft()
            for nxt in self.successors(node_id):
                if banned_edge is not None and (node_id, nxt) == banned_edge:
                    continue
                if nxt not in seen:
                    seen.add(nxt)
                    queue.append(nxt)
        return seen

    def external_closure(self, start: NodeId) -> set[str]:
        """Opam packages reachable from `start`, normalised to package names."""
        names = set(self.external.get(start, ()))
        for node_id in self.closure(start):
            names.update(self.external.get(node_id, ()))
        return {name.split(".")[0] for name in names}

    def shortest_path(self, start: NodeId, target: NodeId) -> tuple[NodeId, ...] | None:
        previous: dict[NodeId, NodeId | None] = {start: None}
        queue = deque([start])
        while queue:
            node_id = queue.popleft()
            if node_id == target:
                path: list[NodeId] = []
                step: NodeId | None = node_id
                while step is not None:
                    path.append(step)
                    step = previous[step]
                return tuple(reversed(path))
            for nxt in self.successors(node_id):
                if nxt not in previous:
                    previous[nxt] = node_id
                    queue.append(nxt)
        return None

    def bridge_edges(self, start: NodeId) -> list[Edge]:
        """Edges whose removal would actually shrink `start`'s closure.

        Cutting `(a, b)` can only drop nodes if it makes `b` itself
        unreachable, which requires `(a, b)` to be the sole in-edge to `b`
        inside the closure. Filtering on that first turns an O(edges) sweep of
        BFS runs into a handful, which is what keeps this usable on every PR.
        """
        reachable = self.closure(start)
        reachable.add(start)
        incoming: defaultdict[NodeId, list[NodeId]] = defaultdict(list)
        for node_id in reachable:
            for nxt in self.successors(node_id):
                if nxt in reachable:
                    incoming[nxt].append(node_id)
        return sorted(
            (sources[0], node_id) for node_id, sources in incoming.items() if len(sources) == 1
        )

    def cut_impact(self, start: NodeId, edge: Edge) -> int:
        """How many libraries drop out of `start`'s closure if `edge` is cut."""
        return len(self.closure(start)) - len(self.closure(start, banned_edge=edge))


def build_graph(root: Path, dune_files: Iterable[DuneFile]) -> DuneGraph:
    """Resolve parsed dune files into a graph. Pure."""
    raw = _read_all(dune_files)
    alias, collisions = _build_alias(raw)
    nodes: dict[NodeId, Node] = {}
    edges: dict[NodeId, tuple[NodeId, ...]] = {}
    external: dict[NodeId, tuple[str, ...]] = {}
    for entry in raw:
        nodes[entry.node.id] = entry.node
        edges[entry.node.id], external[entry.node.id] = _resolve(entry, alias)
    return DuneGraph(root=root, nodes=nodes, edges=edges, external=external, collisions=collisions)


def load(root: Path) -> tuple[DuneGraph, SourceIndex]:
    """Read `root` from disk. The one I/O entrypoint.

    The graph and the source index are built together so they cannot disagree
    about which directories carry their sources in subdirectories.
    """
    dune_files = read_dune_files(root)
    recursive = frozenset(f.directory for f in dune_files if f.include_subdirs)
    return build_graph(root, dune_files), SourceIndex(root, recursive)
