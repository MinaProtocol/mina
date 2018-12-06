open Fold_lib

module Body = struct
  type t =
    {blockchain_state: Blockchain_state.t; consensus_state: Consensus_state.t}
  [@@deriving eq, bin_io, sexp]

  let fold {blockchain_state; consensus_state} =
    let open Fold in
    Blockchain_state.fold blockchain_state
    +> Consensus_state.fold consensus_state
end

type t = {previous_state_hash: Pedersen.Digest.t; body: Body.t}
[@@deriving eq, bin_io, sexp]

let fold ~fold_body {previous_state_hash; body} =
  let open Fold in
  State_hash.fold previous_state_hash +> fold_body body
