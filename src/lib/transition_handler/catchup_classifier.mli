(** Catchup's view of an incoming block or header: how it relates to the
    frontier's root, the anchor, and to the blocks above it. *)

open Mina_base

(** How a block or header relates to the blocks in the frontier.
    - [`Extends v]: its parent is in the frontier and it is selected over the
      root; [v] is it with its frontier dependencies validated.
    - [`Needs_ancestry]: it is selected over the root, but its parent is not in
      the frontier.
    - [`Not_better reason]: it is already in the frontier, or it is not
      selected over the root. *)
type 'extended relation =
  [ `Extends of 'extended
  | `Needs_ancestry
  | `Not_better of [ `Already_in_frontier | `Not_selected_over_root ] ]

(** How a block or header relates to the frontier, given that it does not
    orphan the anchor; see [classify]. *)
val relation :
     context:(module Consensus.Intf.CONTEXT)
  -> Transition_frontier.t
  -> to_header:('a -> Mina_block.Header.t)
  -> ('a, State_hash.State_hashes.t) With_hash.t
     * ( 'b
       , 'c
       , 'd
       , 'e
       , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.false_t
       , 'f
       , 'g )
       Mina_block.Validation.t
  -> ( ('a, State_hash.State_hashes.t) With_hash.t
     * ( 'b
       , 'c
       , 'd
       , 'e
       , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.true_t
       , 'f
       , 'g )
       Mina_block.Validation.t )
     relation

(** Whether a header shows the frontier is too far behind to catch up: its
    anchor, the root, is on a chain that is losing or too old, so the node
    should bootstrap instead. *)
val orphans_anchor :
     context:(module Consensus.Intf.CONTEXT)
  -> Transition_frontier.t
  -> Mina_block.Validation.initial_valid_with_header
  -> bool

(** Catchup's four outcomes for a header: it orphans the anchor, or else its
    [relation] to the frontier. *)
val classify :
     context:(module Consensus.Intf.CONTEXT)
  -> Transition_frontier.t
  -> Mina_block.Validation.initial_valid_with_header
  -> [ `Orphans_anchor
     | ( Mina_block.Header.with_hash
       * ( [ `Time_received ] * unit Mina_stdlib.Truth.true_t
         , [ `Genesis_state ] * unit Mina_stdlib.Truth.true_t
         , [ `Proof ] * unit Mina_stdlib.Truth.true_t
         , [ `Delta_block_chain ]
           * State_hash.t Mina_stdlib.Nonempty_list.t Mina_stdlib.Truth.true_t
         , [ `Frontier_dependencies ] * unit Mina_stdlib.Truth.true_t
         , [ `Staged_ledger_diff ] * unit Mina_stdlib.Truth.false_t
         , [ `Protocol_versions ] * unit Mina_stdlib.Truth.true_t )
         Mina_block.Validation.t )
       relation ]
