"""Build the dune dependency graph by parsing `dune` files.

Deliberately does *not* invoke dune: the whole point is that this runs in a few
seconds on every PR without a switch, without a build, and without any opam
package installed. The cost is that resolution is syntactic and therefore
approximate (see `KNOWN LIMITATIONS` in maintenance/README.md).
"""

import os
import re
from collections import deque
from pathlib import Path

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
# its own `dune`. Walking into it adds `ocaml_rust_caller` to `entrypoints()`,
# which is what the dependency budget is pinned to, and registers the Rust test
# fixture `callable_rust` as an opam package, which trips the
# new-external-dependency check. Neither is Mina code.
#
# The match is on the bare directory name at any depth, which does not scale:
# it restates declarations the dune files already make, and misses the ones not
# listed here (`target`, from `(dirs :standard .cargo \ target)`). Reading
# `data_only_dirs` and `(dirs ...)` during the walk would subsume everything
# below `.git`.
PRUNED_DIRS = {
    "_build",
    "_opam",
    ".git",
    "node_modules",
    "docker-compose",
    "kimchi-stubs-vendors",
}

STANZA_KINDS = ("library", "executable", "executables", "test", "tests")


def _strip_comments(text):
    """Remove `;`-to-end-of-line comments, respecting string literals."""
    out = []
    i = 0
    n = len(text)
    in_string = False
    while i < n:
        c = text[i]
        if in_string:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_string = False
            i += 1
            continue
        if c == '"':
            in_string = True
            out.append(c)
            i += 1
            continue
        if c == ";":
            while i < n and text[i] != "\n":
                i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


_TOKEN_RE = re.compile(r'\(|\)|"(?:[^"\\]|\\.)*"|[^\s()]+')


def parse_sexps(text):
    """Parse a dune file into a list of top-level s-expressions."""
    tokens = _TOKEN_RE.findall(_strip_comments(text))
    stack = []
    current = []
    for tok in tokens:
        if tok == "(":
            stack.append(current)
            current = []
        elif tok == ")":
            if not stack:
                # Unbalanced; give back what we have rather than crashing CI.
                return current
            parent = stack.pop()
            parent.append(current)
            current = parent
        else:
            current.append(tok.strip('"'))
    return current


def field(sexp, key):
    """Return the arguments of the first `(key ...)` field, or None."""
    for item in sexp:
        if isinstance(item, list) and item and item[0] == key:
            return item[1:]
    return None


def _flatten_libs(items):
    """Flatten a `(libraries ...)` field into plain dependency names.

    Handles `(re_export foo)` and `(select ... from (dep -> impl))`; drops
    dune variables (`%{...}`) and `:standard`-style tokens, which we cannot
    resolve without dune itself.
    """
    out = []
    for item in items:
        if isinstance(item, str):
            if item.startswith("%{") or item.startswith(":"):
                continue
            out.append(item)
            continue
        if not item:
            continue
        head = item[0]
        if head == "re_export":
            out.extend(_flatten_libs(item[1:]))
        elif head == "select":
            for sub in item[1:]:
                if not isinstance(sub, list):
                    continue
                for tok in sub:
                    if isinstance(tok, str) and tok != "->" and not tok.endswith(".ml"):
                        out.append(tok)
        else:
            out.extend(_flatten_libs(item))
    return [d for d in out if d and not d.startswith("%{")]


class Node:
    __slots__ = ("id", "kind", "directory", "name", "public_names", "generated",
                 "implements", "ppx")

    def __init__(self, nid, kind, directory, name, public_names, generated,
                 implements, ppx):
        self.id = nid
        self.kind = kind
        self.directory = directory
        self.name = name
        self.public_names = public_names
        # True when some rule in this directory generates a `.ml`, which makes
        # "is this dependency referenced?" unanswerable without a build.
        self.generated = generated
        # Implementations of a virtual library (`(implements foo)`) are chosen
        # by linking them, so they are never named in the source of whatever
        # depends on them. They can never be reported as unused.
        self.implements = implements
        # Ppx packages this stanza runs; see `_preprocessors`.
        self.ppx = ppx

    @property
    def module_name(self):
        return self.name[:1].upper() + self.name[1:]

    @property
    def is_executable(self):
        return self.kind in ("executable", "executables")


class DuneGraph:
    def __init__(self, root):
        self.root = root
        self.nodes = {}
        self.edges = {}  # node id -> sorted list of internal node ids
        self.external = {}  # node id -> sorted list of unresolved (opam) names
        self._sources = {}
        self._build()

    # ---------------------------------------------------------------- build

    def _walk(self):
        # `os.walk` rather than `Path.walk`: the latter is Python 3.12+, and the
        # CI toolchain image is bullseye (3.9). Pruning needs the in-place
        # `dirnames[:]` assignment either way.
        for dirpath, dirnames, filenames in os.walk(self.root):
            dirnames[:] = sorted(d for d in dirnames if d not in PRUNED_DIRS)
            if "dune" in filenames:
                yield Path(dirpath)

    def _build(self):
        alias = {}
        raw = {}
        # Sort on the posix string, not the Path: `alias.setdefault` below is
        # first-writer-wins, so iteration order decides which stanza claims an
        # ambiguous library name. Path ordering compares parts (and does so
        # differently before 3.12), which would make the baseline depend on the
        # interpreter version.
        for dirpath in sorted(self._walk(), key=Path.as_posix):
            path = dirpath / "dune"
            try:
                with open(path, encoding="utf-8", errors="replace") as handle:
                    text = handle.read()
            except OSError:
                continue
            stanzas = parse_sexps(text)
            generated = self._generates_ml(stanzas)
            # `.as_posix()` keeps node ids stable strings for baseline.json.
            relative = dirpath.relative_to(self.root).as_posix()
            for stanza in stanzas:
                if not isinstance(stanza, list) or not stanza:
                    continue
                kind = stanza[0]
                if kind not in STANZA_KINDS:
                    continue
                names = field(stanza, "name") or field(stanza, "names")
                if not names:
                    continue
                names = [n for n in names if isinstance(n, str)]
                publics = field(stanza, "public_name") or field(stanza, "public_names") or []
                publics = [p for p in publics if isinstance(p, str)]
                deps = _flatten_libs(field(stanza, "libraries") or [])
                opened = self._opened_modules(stanza)
                implements = bool(field(stanza, "implements"))
                ppx = self._preprocessors(stanza)
                for name in names:
                    prefix = "lib" if kind == "library" else "exe"
                    nid = "%s:%s:%s" % (prefix, relative, name)
                    self.nodes[nid] = Node(
                        nid, kind, relative, name, publics, generated,
                        implements, ppx
                    )
                    raw[nid] = (deps, opened)
                    alias.setdefault(name, nid)
                    for public in publics:
                        alias.setdefault(public, nid)

        self.alias = alias
        self._opened = {}
        for nid, (deps, opened) in raw.items():
            internal = set()
            external = set()
            for dep in deps:
                target = alias.get(dep)
                if target is None and "." in dep:
                    # `pkg.sublib` shorthand: fall back to the containing package.
                    target = alias.get(dep.split(".")[0])
                if target is not None and target != nid:
                    internal.add(target)
                elif target is None:
                    external.add(dep)
            self.edges[nid] = sorted(internal)
            self.external[nid] = sorted(external)
            self._opened[nid] = opened

    @staticmethod
    def _generates_ml(stanzas):
        for stanza in stanzas:
            if not isinstance(stanza, list) or not stanza or stanza[0] != "rule":
                continue
            targets = field(stanza, "targets") or field(stanza, "target") or []
            for target in targets:
                if isinstance(target, str) and target.endswith((".ml", ".mli")):
                    return True
        return False

    @staticmethod
    def _preprocessors(stanza):
        """Ppx packages this stanza runs, from `(preprocess (pps ...))` and
        `(instrumentation (backend ...))`.

        These are what makes a dependency legitimately invisible to
        `references()`: the code that uses a ppx's runtime support library is
        emitted by the preprocessor, so it never appears in the source we scan.
        Names are reduced to their package (`ppx_deriving.show` -> `ppx_deriving`)
        because that is what a runtime sublibrary hangs off.
        """
        found = set()

        def walk(node):
            if not isinstance(node, list) or not node:
                return
            if node[0] in ("pps", "backend"):
                found.update(
                    item.split(".")[0] for item in node[1:] if isinstance(item, str)
                )
            for item in node:
                walk(item)

        walk(stanza)
        return found

    @staticmethod
    def _opened_modules(stanza):
        """Modules brought into scope via `(flags ... -open Foo ...)`."""
        opened = set()
        for key in ("flags", "ocamlopt_flags", "library_flags"):
            flags = field(stanza, key)
            if not flags:
                continue
            flat = []

            def walk(items):
                for item in items:
                    if isinstance(item, str):
                        flat.append(item)
                    elif isinstance(item, list):
                        walk(item)

            walk(flags)
            for index, token in enumerate(flat):
                if token == "-open" and index + 1 < len(flat):
                    opened.add(flat[index + 1].split(".")[0])
        return opened

    # ---------------------------------------------------------------- query

    def closure(self, start, banned_edge=None):
        """Transitive internal dependencies of `start`, excluding `start`."""
        seen = set()
        queue = deque([start])
        while queue:
            node = queue.popleft()
            for nxt in self.edges.get(node, ()):
                if banned_edge is not None and (node, nxt) == banned_edge:
                    continue
                if nxt not in seen:
                    seen.add(nxt)
                    queue.append(nxt)
        return seen

    def external_closure(self, start):
        """Opam packages reachable from `start`, normalised to package names."""
        names = set(self.external.get(start, ()))
        for node in self.closure(start):
            names.update(self.external.get(node, ()))
        return {n.split(".")[0] for n in names}

    def shortest_path(self, start, target):
        previous = {start: None}
        queue = deque([start])
        while queue:
            node = queue.popleft()
            if node == target:
                path = []
                while node is not None:
                    path.append(node)
                    node = previous[node]
                return path[::-1]
            for nxt in self.edges.get(node, ()):
                if nxt not in previous:
                    previous[nxt] = node
                    queue.append(nxt)
        return None

    def bridge_edges(self, start):
        """Edges whose removal would actually shrink `start`'s closure.

        Cutting `(a, b)` can only drop nodes if it makes `b` itself
        unreachable, which requires `(a, b)` to be the sole in-edge to `b`
        inside the closure. Filtering on that first turns an O(edges) sweep of
        BFS runs into a handful, which is what keeps this usable on every PR.
        """
        reachable = self.closure(start)
        reachable.add(start)
        incoming = {}
        for node in reachable:
            for nxt in self.edges.get(node, ()):
                if nxt in reachable:
                    incoming.setdefault(nxt, []).append(node)
        bridges = []
        for node, sources in incoming.items():
            if len(sources) == 1:
                bridges.append((sources[0], node))
        return sorted(bridges)

    def cut_impact(self, start, edge):
        """How many libraries drop out of `start`'s closure if `edge` is cut."""
        return len(self.closure(start)) - len(self.closure(start, banned_edge=edge))

    # -------------------------------------------------------- source lookup

    def sources(self, directory):
        """Concatenated OCaml sources in a directory (cached)."""
        if directory in self._sources:
            return self._sources[directory]
        chunks = []
        full = Path(self.root) / directory
        try:
            entries = sorted(full.iterdir())
        except OSError:
            entries = []
        for entry in entries:
            if entry.suffix not in (".ml", ".mli", ".mll", ".mly"):
                continue
            try:
                with open(entry, encoding="utf-8", errors="replace") as handle:
                    chunks.append(handle.read())
            except OSError:
                pass
        text = "\n".join(chunks)
        self._sources[directory] = text
        return text

    def references(self, node_id, module_name):
        """Count references to `module_name` from `node_id`'s directory.

        Over-approximates on purpose: it scans every source file in the
        directory rather than only the stanza's `(modules ...)`, so a shared
        directory can mask an unused dependency. Under-reporting is the safe
        direction for a check that tells people to delete things.
        """
        if module_name in self._opened.get(node_id, ()):
            return 1
        text = self.sources(self.nodes[node_id].directory)
        if not text:
            return 0
        return len(re.findall(r"\b%s\b" % re.escape(module_name), text))
