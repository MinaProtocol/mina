"""
Lower a v2 constraint topology (``requirements``) into the concrete ``nodes`` map
the existing resolve/materialize pipeline consumes.

The v2 surface (see ``mln.constraints``) describes a network by *requirements* —
named fragments, a node budget, placement relations — rather than an explicit
node list. This module is the front-end that turns those requirements into a
concrete placement and emits the v1-shaped topology dict; everything downstream
(``normalize_topology`` → ``resolve_topology`` → materialize) is unchanged. v1 is
no longer an authoring format but survives as this lowering's output IR.

**How it works:** draw a node count in ``nodes.min..max`` and place every
fragment-replica constructively onto that many nodes, honouring per-node capability
capacity, one-replica-per-fragment-per-node, and separation rules. Nodes left empty
become bare gossip relays. A greedy corner (a replica with nowhere legal) resamples;
a wholly infeasible node budget raises.

Separation rules are resolved per attempt: hard ``separate``/``incompatible`` always
apply, and each soft ``avoid_colocate`` is promoted to a hard separation with
probability ``w/(w+1)`` (an independent coin, re-flipped on resample). The relation
set is exclusion-only — co-location is expressed by co-listing caps in one fragment
or a tight node budget, not a rule (see ``mln.constraints.PlacementRelation``).

Placement is random by default: an unpinned topology draws a fresh placement each
run (the RNG is seeded from OS entropy), so repeated lowerings explore different
valid networks — this is what lets CI exercise varied layouts rather than one fixed
shape. Pin ``requirements.seed`` to reproduce a chosen scenario; explicit seed
control from the CLI is future work. Manifest freeze of the sampled result is still
a later phase.
"""

from __future__ import annotations

from random import Random
from typing import Dict, List, Set, Tuple

from mln.amounts import parse_account_spec
from mln.constraints import (
    Fragment,
    PlacementRelation,
    Requirements,
    ServiceReq,
    parse_requirements,
)
from mln.errors import ErrorCode, TopologyError

# A greedy placement can paint itself into a corner; bound how many (node-count
# draw, placement) attempts we make before declaring the budget infeasible.
_MAX_PLACEMENT_ATTEMPTS = 200

# A fragment-replica: (fragment name, replica index).
FragmentReplica = Tuple[str, int]


def lower_topology(raw: dict) -> dict:
    """Return a v1-shaped topology dict for a v2 ``requirements`` document.

    A dict without a ``requirements`` block is returned unchanged, so this is safe
    to call on any loaded topology. The ``requirements`` block is replaced by a
    concrete ``nodes`` map and the schema version is set to the resolved (v1) form.
    """
    if "requirements" not in raw:
        return raw

    req = parse_requirements(raw["requirements"])
    # Random by default: Random(None) seeds from OS entropy, so an unpinned topology
    # samples a fresh valid layout each run. A pinned requirements.seed reproduces a
    # chosen placement (CLI seed control is future work).
    nodes = _sample_nodes(req, Random(req.seed), _tier_counts(raw))

    out = {k: v for k, v in raw.items() if k != "requirements"}
    out["schema_version"] = 1
    out["nodes"] = nodes
    if req.services:
        out["services"] = _lower_services(req.services)
    return out


def _lower_services(services: Dict[str, ServiceReq]) -> Dict[str, dict]:
    """Lower ``requirements.services`` to the v1 ``services`` map.

    Each service keeps its passthrough config (minus ``replica``); its intrinsic
    wiring is applied later by ``resolve_topology``. v1 has exactly one instance of
    each service type (keyed by name), so ``replica`` must be 1.
    """
    result: Dict[str, dict] = {}
    for name, svc in services.items():
        if svc.replica != 1:
            raise TopologyError(
                ErrorCode.REQUIREMENTS_VALIDATION,
                message=(
                    f"service '{name}' declares replica {svc.replica}, but exactly one "
                    f"instance per service type is supported."
                ),
                entity=name,
            )
        result[name] = svc.model_dump(exclude={"replica"})
    return result


def _tier_counts(raw: dict) -> Dict[str, int]:
    """The provisioned account count of each ledger tier, ``{}`` if none declared.

    A stake tier provisions ``count`` accounts (``whale-0`` … ``whale-<count-1>``);
    the sampler binds producers within that supply and fails if demand exceeds it.
    """
    tiers = raw.get("ledger_generation", {}).get("tiers", {})
    return {name: int(spec.get("count", 0)) for name, spec in tiers.items()}


# ── Placement ────────────────────────────────────────────────────────────────


def _sample_nodes(
    req: Requirements, rng: Random, tier_counts: Dict[str, int]
) -> Dict[str, dict]:
    """Draw a node count and place fragments constructively (hard constraints only).

    Each attempt draws ``N`` in ``[nodes.min, nodes.max]`` and places every
    fragment-replica onto ``N`` nodes; nodes left empty become bare relays. A
    corner (a replica with nowhere legal) is discarded and the next attempt drawn.
    """
    caps_by_replica = _bind_and_translate(req, tier_counts)
    replicas = sorted(caps_by_replica, key=_placement_priority(req))

    for _attempt in range(_MAX_PLACEMENT_ATTEMPTS):
        # Outside-in: resolve soft rules first, then draw a count, then place. Each
        # soft rule is an independent per-attempt coin, so a corner can escape by
        # re-flipping the softs as well as by re-drawing the node count.
        separated = _resolve_separations(req, rng)
        node_count = rng.randint(req.nodes.min, req.nodes.max)
        assignment = _try_place(replicas, node_count, req, separated, rng)
        if assignment is not None:
            return _build_nodes(assignment, node_count, caps_by_replica)

    raise TopologyError(
        ErrorCode.REQUIREMENTS_VALIDATION,
        message=(
            f"could not place fragments within nodes.min..max "
            f"({req.nodes.min}..{req.nodes.max}) after {_MAX_PLACEMENT_ATTEMPTS} "
            f"attempts: the node budget is too tight for the fragments' per-node "
            f"capacity and separation rules."
        ),
    )


def _placement_priority(req: Requirements):
    """Order replicas most-constrained-first so greedy placement corners less often.

    Fragments carrying more capabilities merge with fewer others, so place them
    first; ties break on name/index for a stable order.
    """

    def key(fr: FragmentReplica):
        name, index = fr
        return (-len(req.fragments[name].capability_names()), name, index)

    return key


def _resolve_separations(req: Requirements, rng: Random) -> Set[frozenset]:
    """The unordered fragment pairs that must not share a node on THIS draw.

    Hard ``separate``/``incompatible`` rules always apply. Each soft
    ``avoid_colocate`` rule is promoted to a hard separation with probability
    ``q(w) = w / (w + 1)`` (odds in favour: weight 1 → 50%, 9 → 90%, 99 → 99%), by
    an independent coin flipped every attempt, or dropped for this draw otherwise.
    """
    pairs: Set[frozenset] = set()
    for rule in req.placement:
        if rule.relation in (PlacementRelation.SEPARATE, PlacementRelation.INCOMPATIBLE):
            pairs.add(frozenset(rule.of))
        elif rule.relation is PlacementRelation.AVOID_COLOCATE:
            weight = rule.weight  # soft rules are validated to carry a weight >= 1
            if rng.random() < weight / (weight + 1):
                pairs.add(frozenset(rule.of))
    return pairs


def _try_place(
    replicas: List[FragmentReplica],
    node_count: int,
    req: Requirements,
    separated: Set[frozenset],
    rng: Random,
) -> Dict[FragmentReplica, int] | None:
    """Greedily assign each replica to a legal node, or ``None`` on a corner."""
    node_fragments: List[Set[str]] = [set() for _ in range(node_count)]
    node_caps: List[Set[str]] = [set() for _ in range(node_count)]
    assignment: Dict[FragmentReplica, int] = {}

    for name, index in replicas:
        caps = set(req.fragments[name].capability_names())
        legal = [
            node
            for node in range(node_count)
            if _can_place(node, name, caps, node_fragments, node_caps, separated)
        ]
        if not legal:
            return None
        chosen = rng.choice(legal)
        node_fragments[chosen].add(name)
        node_caps[chosen] |= caps
        assignment[(name, index)] = chosen

    return assignment


def _can_place(
    node: int,
    name: str,
    caps: Set[str],
    node_fragments: List[Set[str]],
    node_caps: List[Set[str]],
    separated: Set[frozenset],
) -> bool:
    """Whether *name*'s replica may join *node* under the hard constraints.

    Every fragment capability has a per-node capacity of one, so a node may host
    two fragments only if their capability sets are disjoint — which also enforces
    one-replica-per-fragment (replicas share caps). Plus: no hard-separated pair.
    """
    if name in node_fragments[node]:
        return False
    if caps & node_caps[node]:
        return False
    for other in node_fragments[node]:
        if frozenset({name, other}) in separated:
            return False
    return True


def _build_nodes(
    assignment: Dict[FragmentReplica, int],
    node_count: int,
    caps_by_replica: Dict[FragmentReplica, dict],
) -> Dict[str, dict]:
    """Turn a replica→node assignment into the v1 ``nodes`` map.

    A node's capabilities are the union of its fragment-replicas' (disjoint by
    construction). Its name is the ``+``-join of the distinct fragment names it
    hosts plus a global id; an empty node is a bare relay named ``node-<id>``.
    """
    members: List[List[FragmentReplica]] = [[] for _ in range(node_count)]
    for replica, node in assignment.items():
        members[node].append(replica)

    nodes: Dict[str, dict] = {}
    for node_id in range(node_count):
        fragment_names = sorted({name for name, _index in members[node_id]})
        merged_caps: dict = {}
        for replica in sorted(members[node_id]):
            merged_caps.update(caps_by_replica[replica])
        name = f"{'+'.join(fragment_names)}-{node_id}" if fragment_names else f"node-{node_id}"
        nodes[name] = {"capabilities": merged_caps}
    return nodes


# ── Account binding + capability translation ─────────────────────────────────


def _bind_and_translate(
    req: Requirements, tier_counts: Dict[str, int]
) -> Dict[FragmentReplica, dict]:
    """Bind accounts and translate every fragment-replica's caps to the v1 shape.

    Done before placement, in sorted ``(name, index)`` order, so binding is
    deterministic and independent of where a replica lands. Raises if producer
    demand outruns the ledger tier's provisioned supply.
    """
    tier_counters: Dict[str, int] = {}
    result: Dict[FragmentReplica, dict] = {}
    for name in sorted(req.fragments):
        fragment = req.fragments[name]
        for index in range(fragment.replica):
            result[(name, index)] = _translate_caps(fragment, tier_counters, tier_counts)
    return result


def _translate_caps(
    fragment: Fragment, tier_counters: Dict[str, int], tier_counts: Dict[str, int]
) -> dict:
    """Translate a fragment's typed capabilities into the v1 ``capabilities`` dict.

    Abstract ``block_producer: { stake_tier }`` is bound to a distinct account by
    consuming the next index of that tier (``whale-0``, ``whale-1``, …); a concrete
    ``{ account }`` passes through. ``tier_counters`` threads the per-tier index
    across the whole placement so no two producers share a key; every bound account
    is checked against the tier's provisioned supply.
    """
    caps: dict = {}
    if fragment.seed is not None:
        caps["p2p_seed"] = {}
    if fragment.block_producer is not None:
        bp = fragment.block_producer
        if bp.account is not None:
            tier, index = parse_account_spec(bp.account)
            _require_provisioned(tier, index, tier_counts, f"pinned account '{bp.account}'")
            account = bp.account
        else:
            tier = bp.stake_tier
            index = tier_counters.get(tier, 0)
            _require_provisioned(tier, index, tier_counts, f"stake_tier '{tier}'")
            account = f"{tier}-{index}"
            tier_counters[tier] = index + 1
        caps["block_producer"] = {"account": account}
    if fragment.snark_coordinator is not None:
        sc = fragment.snark_coordinator
        caps["snark_coordinator"] = {
            "fee_receiver": sc.fee_receiver,
            "worker_pools": {"default": {"count": sc.workers}},
        }
    return caps


def _require_provisioned(
    tier: str, index: int, tier_counts: Dict[str, int], what: str
) -> None:
    """Raise unless account ``<tier>-<index>`` is within the tier's provisioned supply.

    Provisioning is explicit: the ledger tier ``count`` is authoritative, so demand
    beyond it is a feasibility error naming the shortfall rather than a confusing
    missing-key failure downstream.
    """
    count = tier_counts.get(tier)
    if count is None:
        raise TopologyError(
            ErrorCode.REQUIREMENTS_VALIDATION,
            message=(
                f"block_producer {what} draws from ledger tier '{tier}', which "
                f"ledger_generation.tiers does not define."
            ),
            entity=tier,
        )
    if index >= count:
        raise TopologyError(
            ErrorCode.REQUIREMENTS_VALIDATION,
            message=(
                f"block_producer demand exceeds supply for tier '{tier}': it needs "
                f"account '{tier}-{index}' but the tier provisions only {count} "
                f"({tier}-0..{tier}-{count - 1}). Raise "
                f"ledger_generation.tiers.{tier}.count."
            ),
            entity=tier,
        )
