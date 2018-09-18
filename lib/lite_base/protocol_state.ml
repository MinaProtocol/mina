open Fold_lib

type t =
  { previous_state_hash: Pedersen.Digest.t
  ; blockchain_state: Blockchain_state.t
  ; consensus_state: Consensus_state.t }
[@@deriving eq, bin_io, sexp]

let fold {previous_state_hash; blockchain_state; consensus_state} =
  let open Fold in
  State_hash.fold previous_state_hash
  +> Blockchain_state.fold blockchain_state
  +> Consensus_state.fold consensus_state
