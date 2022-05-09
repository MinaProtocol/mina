open Core_kernel
open Mina_base
open Mina_state
module Body = Body
module Body_reference = Body_reference
module Header = Header
module Validation = Validation
module Validated = Validated_block
module Precomputed = Precomputed_block
module Internal_transition = Internal_transition

type fully_invalid_block = Validation.fully_invalid_with_block

type initial_valid_block = Validation.initial_valid_with_block

type almost_valid_block = Validation.almost_valid_with_block

type fully_valid_block = Validation.fully_valid_with_block

let genesis ~precomputed_values : Block.with_hash * Validation.fully_valid =
  let genesis_state =
    Precomputed_values.genesis_state_with_hashes precomputed_values
  in
  let protocol_state = With_hash.data genesis_state in
  let block_with_hash =
    let body = Body.create Staged_ledger_diff.empty_diff in
    let body_reference = Body_reference.of_body body in
    let header =
      Header.create ~body_reference ~protocol_state
        ~protocol_state_proof:Proof.blockchain_dummy
        ~delta_block_chain_proof:
          (Protocol_state.previous_state_hash protocol_state, [])
        ()
    in
    let block = Block.create ~header ~body in
    With_hash.map genesis_state ~f:(Fn.const block)
  in
  let validation =
    ( (`Time_received, Truth.True ())
    , (`Genesis_state, Truth.True ())
    , (`Proof, Truth.True ())
    , ( `Delta_block_chain
      , Truth.True
          ( Non_empty_list.singleton
          @@ Protocol_state.previous_state_hash protocol_state ) )
    , (`Frontier_dependencies, Truth.True ())
    , (`Staged_ledger_diff, Truth.True ())
    , (`Protocol_versions, Truth.True ()) )
  in
  (block_with_hash, validation)

let handle_dropped_transition ?pipe_name ?valid_cb ~logger block =
  [%log warn] "Dropping state_hash $state_hash from $pipe transition pipe"
    ~metadata:
      [ ("state_hash", State_hash.(to_yojson (State_hashes.state_hash block)))
      ; ("pipe", `String (Option.value pipe_name ~default:"an unknown"))
      ] ;
  Option.iter
    ~f:(Fn.flip Mina_net2.Validation_callback.fire_if_not_already_fired `Reject)
    valid_cb

let blockchain_length block =
  block |> Block.header |> Header.protocol_state
  |> Mina_state.Protocol_state.consensus_state
  |> Consensus.Data.Consensus_state.blockchain_length

let consensus_state =
  Fn.compose Protocol_state.consensus_state
    (Fn.compose Header.protocol_state Block.header)

include Block
