open Core_kernel
open Mina_base
open Mina_state
module Body = Staged_ledger_diff.Body
module Header = Header
module Validation = Validation
module Validated = Validated_block
module Precomputed = Precomputed_block
module Internal_transition = Internal_transition
module Legacy_format = Legacy_format

type fully_invalid_block = Validation.fully_invalid_with_block

type initial_valid_block = Validation.initial_valid_with_block

type initial_valid_header = Validation.initial_valid_with_header

type almost_valid_block = Validation.almost_valid_with_block

type almost_valid_header = Validation.almost_valid_with_header

type fully_valid_block = Validation.fully_valid_with_block

let genesis ~precomputed_values : Block.with_hash * Validation.fully_valid =
  let genesis_state =
    Precomputed_values.genesis_state_with_hashes precomputed_values
  in
  let protocol_state = With_hash.data genesis_state in
  let block_with_hash =
    let body = Staged_ledger_diff.Body.create Staged_ledger_diff.empty_diff in
    let header =
      Header.create ~protocol_state
        ~protocol_state_proof:(Lazy.force Proof.blockchain_dummy)
        ~delta_block_chain_proof:
          (Protocol_state.previous_state_hash protocol_state, [])
        ()
    in
    let block = Block.create ~header ~body in
    With_hash.map genesis_state ~f:(Fn.const block)
  in
  let validation =
    ( (`Time_received, Mina_stdlib.Truth.True ())
    , (`Genesis_state, Mina_stdlib.Truth.True ())
    , (`Proof, Mina_stdlib.Truth.True ())
    , ( `Delta_block_chain
      , Mina_stdlib.Truth.True
          ( Mina_stdlib.Nonempty_list.singleton
          @@ Protocol_state.previous_state_hash protocol_state ) )
    , (`Frontier_dependencies, Mina_stdlib.Truth.True ())
    , (`Staged_ledger_diff, Mina_stdlib.Truth.True ())
    , (`Protocol_versions, Mina_stdlib.Truth.True ()) )
  in
  (block_with_hash, validation)

let genesis_header ~precomputed_values =
  let b, v = genesis ~precomputed_values in
  (With_hash.map ~f:Block.header b, v)

let handle_dropped_transition ?pipe_name ?valid_cb ~logger block =
  [%log warn] "Dropping state_hash $state_hash from $pipe transition pipe"
    ~metadata:
      [ ("state_hash", State_hash.(to_yojson (State_hashes.state_hash block)))
      ; ("pipe", `String (Option.value pipe_name ~default:"an unknown"))
      ] ;
  Option.iter
    ~f:(Fn.flip Mina_net2.Validation_callback.fire_if_not_already_fired `Reject)
    valid_cb

let blockchain_length block = block |> Block.header |> Header.blockchain_length

let consensus_state =
  Fn.compose Protocol_state.consensus_state
    (Fn.compose Header.protocol_state Block.header)

include Block

module Proof_carrying = struct
  let to_header_data ~to_header
      { Proof_carrying_data.proof = merkle_list, root_unverified
      ; data = best_tip_unverified
      } =
    { Proof_carrying_data.proof = (merkle_list, to_header root_unverified)
    ; data = to_header best_tip_unverified
    }
end

let verify_on_header ~verify
    ( { Proof_carrying_data.proof = _, root_unverified
      ; data = best_tip_unverified
      } as pcd ) =
  let%map.Async_kernel.Deferred.Or_error ( `Root root_header
                                         , `Best_tip best_tip_header ) =
    verify (Proof_carrying.to_header_data ~to_header:header pcd)
  in
  let root = Validation.with_body root_header (body root_unverified) in
  let best_tip =
    Validation.with_body best_tip_header (body best_tip_unverified)
  in
  (`Root root, `Best_tip best_tip)
