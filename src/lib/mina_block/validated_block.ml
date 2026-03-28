open Core_kernel
open Mina_base

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      Block.Stable.V2.t State_hash.With_state_hashes.Stable.V1.t
      * State_hash.Stable.V1.t Mina_stdlib.Nonempty_list.Stable.V1.t
    [@@deriving equal]

    let to_latest = ident

    let hashes (t, _) = With_hash.hash t
  end
end]

module Serializable_type = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        Block.Serializable_type.Stable.V2.t
        State_hash.With_state_hashes.Stable.V1.t
        * State_hash.Stable.V1.t Mina_stdlib.Nonempty_list.Stable.V1.t

      let to_latest = ident

      let hashes (t, _) = With_hash.hash t
    end
  end]
end

type t =
  Block.t State_hash.With_state_hashes.t
  * State_hash.t Mina_stdlib.Nonempty_list.t

let to_yojson (block_with_hashes, _) =
  State_hash.With_state_hashes.to_yojson
    (Fn.compose Block.to_logging_yojson Block.header)
    block_with_hashes

let lift (b, v) =
  match v with
  | ( _
    , _
    , _
    , (`Delta_block_chain, Mina_stdlib.Truth.True delta_block_chain_proof)
    , _
    , _
    , _ ) ->
      (b, delta_block_chain_proof)

let forget (b, _) = b

let remember (b, delta_block_chain_proof) =
  ( b
  , ( (`Time_received, Mina_stdlib.Truth.True ())
    , (`Genesis_state, Mina_stdlib.Truth.True ())
    , (`Proof, Mina_stdlib.Truth.True ())
    , (`Delta_block_chain, Mina_stdlib.Truth.True delta_block_chain_proof)
    , (`Frontier_dependencies, Mina_stdlib.Truth.True ())
    , (`Staged_ledger_diff, Mina_stdlib.Truth.True ())
    , (`Protocol_versions, Mina_stdlib.Truth.True ()) ) )

let delta_block_chain_proof (_, d) = d

let valid_commands (block, _) =
  block |> With_hash.data |> Block.body
  |> Staged_ledger_diff.Body.staged_ledger_diff |> Staged_ledger_diff.commands
  |> List.map ~f:(fun cmd ->
         (* This is safe because at this point the stage ledger diff has been
              applied successfully. *)
         let (`If_this_is_used_it_should_have_a_comment_justifying_it data) =
           User_command.to_valid_unsafe cmd.data
         in
         { cmd with data } )

let unsafe_of_trusted_block ~delta_block_chain_proof
    (`This_block_is_trusted_to_be_safe b) =
  (b, delta_block_chain_proof)

let state_hash (b, _) = State_hash.With_state_hashes.state_hash b

let state_body_hash (t, _) =
  State_hash.With_state_hashes.state_body_hash t
    ~compute_hashes:
      (Fn.compose Mina_state.Protocol_state.hashes
         (Fn.compose Header.protocol_state Block.header) )

let header t = t |> forget |> With_hash.data |> Block.header

let body t = t |> forget |> With_hash.data |> Block.body

let is_genesis t =
  header t |> Header.protocol_state |> Mina_state.Protocol_state.consensus_state
  |> Consensus.Data.Consensus_state.is_genesis_state

let read_all_proofs_from_disk ((b, v) : t) : Stable.Latest.t =
  (With_hash.map ~f:Block.read_all_proofs_from_disk b, v)

let to_serializable_type ((b, v) : t) : Serializable_type.t =
  (With_hash.map ~f:Block.to_serializable_type b, v)
