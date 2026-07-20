"""
Typed models for the v2 *constraint-oriented* topology surface.

A v2 topology replaces the explicit ``nodes`` map with a ``requirements`` block:
named **fragments** (capability bundles that must share a node), external
**services**, a **node budget** (a merge↔spread dial), and **placement**
relations between fragments. A later *sampler* lowers this into the v1
``nodes`` map; this module only defines and parses the surface — no sampling.

Parsing is the single boundary between the raw JSON dict and typed models:
:func:`parse_requirements` is the only place a ``requirements`` dict becomes a
:class:`Requirements`. Everything downstream consumes the typed model.

See ``MLN_CONSTRAINT_PLAN_DESIGN.md`` for the design rationale.
"""

from __future__ import annotations

from enum import Enum
from typing import Dict, List, Optional

from pydantic import BaseModel, ConfigDict, ValidationError, model_validator

from mln.errors import ErrorCode, TopologyError

# ── Capabilities ────────────────────────────────────────────────────────────
#
# Every non-``replica`` key of a fragment is a capability: a daemon CLI flag with
# its config. The set is closed (``extra="forbid"``) so a typo is caught at parse
# rather than silently ignored. Each capability has a fixed per-node capacity —
# that is an intrinsic fact of Mina (see the design note), not modeled here.


class SeedCap(BaseModel):
    """The ``--seed`` capability. Carries no config (``{}``)."""

    model_config = ConfigDict(frozen=True, extra="forbid")


class BlockProducerCap(BaseModel):
    """The ``--block-producer-key`` capability.

    Exactly one of ``stake_tier`` (abstract — the sampler picks a distinct
    online-tier key) or ``account`` (concrete — a pin) must be given.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    stake_tier: Optional[str] = None
    account: Optional[str] = None

    @model_validator(mode="after")
    def _exactly_one_binding(self) -> "BlockProducerCap":
        has_tier = self.stake_tier is not None
        has_account = self.account is not None
        if has_tier == has_account:
            raise ValueError(
                "block_producer needs exactly one of 'stake_tier' or 'account', "
                f"got {'both' if has_tier else 'neither'}"
            )
        return self


class SnarkCoordinatorCap(BaseModel):
    """The ``--snark-coordinator`` capability.

    ``workers`` prover nodes are wired to this coordinator (they live outside the
    daemon node budget); ``fee_receiver`` names the account fees are paid to.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    workers: int = 0
    fee_receiver: str

    @model_validator(mode="after")
    def _workers_non_negative(self) -> "SnarkCoordinatorCap":
        if self.workers < 0:
            raise ValueError(f"snark_coordinator.workers must be >= 0, got {self.workers}")
        return self


class Fragment(BaseModel):
    """A named bundle of capabilities that must share a node.

    ``replica`` copies are placed on that many *distinct* nodes. Every other
    field is an optional typed capability; at least one must be present (a
    fragment with no capabilities is meaningless — bare relay nodes come from the
    node budget, not from empty fragments).
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    replica: int = 1
    seed: Optional[SeedCap] = None
    block_producer: Optional[BlockProducerCap] = None
    snark_coordinator: Optional[SnarkCoordinatorCap] = None

    @model_validator(mode="after")
    def _has_a_capability(self) -> "Fragment":
        if self.replica < 1:
            raise ValueError(f"fragment replica must be >= 1, got {self.replica}")
        if not (self.seed or self.block_producer or self.snark_coordinator):
            raise ValueError("fragment must declare at least one capability")
        return self

    def capability_names(self) -> List[str]:
        """The capability keys present, in a stable order (for names/logging)."""
        present: List[str] = []
        if self.seed is not None:
            present.append("seed")
        if self.block_producer is not None:
            present.append("block_producer")
        if self.snark_coordinator is not None:
            present.append("snark_coordinator")
        return present


# ── Services ─────────────────────────────────────────────────────────────────


class ServiceReq(BaseModel):
    """An external service declared by existence.

    Its mandatory wiring (archive fed by a daemon; rosetta to a consistent
    archive+daemon pair) is intrinsic to the component model, not authored here —
    so the minimal form is just ``{ replica: 1 }``. Any extra fields (archive
    ``postgres``, ``port``, ``binary``; rosetta ``max_db_pool_size``) pass through
    to the resolved service config unchanged, an explicit extension boundary for
    environment specifics; they are validated downstream against the service schema.
    """

    model_config = ConfigDict(frozen=True, extra="allow")

    replica: int = 1

    @model_validator(mode="after")
    def _replica_positive(self) -> "ServiceReq":
        if self.replica < 1:
            raise ValueError(f"service replica must be >= 1, got {self.replica}")
        return self


# ── Placement ────────────────────────────────────────────────────────────────


class PlacementRelation(str, Enum):
    """How two fragments relate on the physical node map — exclusion only.

    ``separate``/``incompatible`` are HARD (no weight); ``avoid_colocate`` is SOFT —
    a ``weight`` biases the odds the two fragments land on different nodes.

    There is intentionally no ``together``/``prefer_colocate``: co-location is
    already expressed by co-listing capabilities in one fragment (they then share a
    node by definition) or by a low node budget that merges fragments
    opportunistically, and the propagation goal wants spreading, not concentrating.
    Forcing two *distinct* fragments together buys nothing and has ambiguous
    replica semantics, so the relation set stays exclusion-only.
    """

    SEPARATE = "separate"
    INCOMPATIBLE = "incompatible"
    AVOID_COLOCATE = "avoid_colocate"

    def is_soft(self) -> bool:
        return self is PlacementRelation.AVOID_COLOCATE


class PlacementRule(BaseModel):
    """A typed relation between two fragments, referenced by name.

    ``of`` is exactly two fragment names (a self-rule repeats the name). A soft
    relation requires ``weight`` (a positive int); a hard relation forbids it.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    relation: PlacementRelation
    of: List[str]
    weight: Optional[int] = None

    @model_validator(mode="after")
    def _shape(self) -> "PlacementRule":
        if len(self.of) != 2:
            raise ValueError(
                f"placement '{self.relation.value}' needs exactly 2 fragments in "
                f"'of', got {len(self.of)}"
            )
        if self.relation.is_soft():
            if self.weight is None:
                raise ValueError(
                    f"soft relation '{self.relation.value}' requires a 'weight'"
                )
            if self.weight < 1:
                raise ValueError(
                    f"weight must be >= 1, got {self.weight}"
                )
        elif self.weight is not None:
            raise ValueError(
                f"hard relation '{self.relation.value}' must not carry a 'weight'"
            )
        return self


# ── Node budget ──────────────────────────────────────────────────────────────


class NodeBudget(BaseModel):
    """The daemon count range — a merge↔spread dial, not an absolute headcount.

    A low draw forces fragments to merge; a high draw spreads them and fills the
    surplus with bare gossip relays.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    min: int
    max: int

    @model_validator(mode="after")
    def _ordered(self) -> "NodeBudget":
        if self.min < 1:
            raise ValueError(f"nodes.min must be >= 1, got {self.min}")
        if self.max < self.min:
            raise ValueError(
                f"nodes.max ({self.max}) must be >= nodes.min ({self.min})"
            )
        return self


# ── The requirements block ───────────────────────────────────────────────────


class Requirements(BaseModel):
    """The ``requirements`` block of a v2 topology — the sampler's whole input."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    fragments: Dict[str, Fragment]
    nodes: NodeBudget
    services: Dict[str, ServiceReq] = {}
    placement: List[PlacementRule] = []
    # Sampler seed. When set, the placement (node count + soft-rule coin flips +
    # node choices) is a pure function of it, so a scenario is reproducible and
    # dialling it explores different networks. When omitted, placement is random —
    # a fresh valid layout each run (the RNG seeds from OS entropy).
    seed: Optional[int] = None

    @model_validator(mode="after")
    def _cross_references(self) -> "Requirements":
        if not self.fragments:
            raise ValueError("requirements.fragments must not be empty")
        names = set(self.fragments)
        for rule in self.placement:
            for frag in rule.of:
                if frag not in names:
                    raise ValueError(
                        f"placement '{rule.relation.value}' references unknown "
                        f"fragment '{frag}'"
                    )
        return self


def parse_requirements(raw: dict) -> Requirements:
    """Parse a raw ``requirements`` dict into a typed :class:`Requirements`.

    The single coercion boundary from the JSON edge to the typed model. Pydantic
    validation errors are rewrapped as a structural :class:`TopologyError` so the
    CLI shell renders them uniformly.
    """
    try:
        return Requirements.model_validate(raw)
    except ValidationError as exc:
        raise TopologyError(
            ErrorCode.REQUIREMENTS_VALIDATION,
            message=f"invalid requirements block: {exc.error_count()} error(s)",
            hint=str(exc),
        ) from exc


def requirements_json_schema() -> dict:
    """Emit the JSON Schema for the ``requirements`` block, derived from the model.

    The pydantic model is the single source of truth; this projects it to a JSON
    Schema for tooling/editors and a coarse structural gate. The model is
    deliberately *stricter* than the emitted schema — invariants JSON Schema can't
    state (block_producer exactly-one-of, weight-required-iff-soft, placement
    cross-refs) live in the model's validators, not here. Regenerate the checked-in
    file with ``mina-local-network schema regen``; a drift test guards it.
    """
    return Requirements.model_json_schema()
