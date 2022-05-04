open Core_kernel
open Mina_base
open Mina_state
module Body = Body
module Body_reference = Body_reference
module Header = Header
module Validation = Validation
module Precomputed = Precomputed_block

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

module Validated : sig
  type t = Block.with_hash * State_hash.t Non_empty_list.t
  [@@deriving sexp, to_yojson, equal]

  val lift : Block.with_hash * Validation.fully_valid -> t

  val forget : t -> Block.with_hash

  val remember : t -> fully_valid_block

  val delta_block_chain_proof : t -> State_hash.t Non_empty_list.t

  val valid_commands : t -> User_command.Valid.t With_status.t list

  val unsafe_of_trusted_block :
       delta_block_chain_proof:State_hash.t Non_empty_list.t
    -> [ `This_block_is_trusted_to_be_safe of Block.with_hash ]
    -> t

  val state_hash : t -> State_hash.t

  val state_body_hash : t -> State_body_hash.t

  val header : t -> Header.t

  val body : t -> Body.t
end = struct
  type t =
    Block.t State_hash.With_state_hashes.t * State_hash.t Non_empty_list.t
  [@@deriving sexp, equal]

  let to_yojson (block_with_hashes, _) =
    State_hash.With_state_hashes.to_yojson Block.to_yojson block_with_hashes

  let lift (b, v) =
    match v with
    | _, _, _, (`Delta_block_chain, Truth.True delta_block_chain_proof), _, _, _
      ->
        (b, delta_block_chain_proof)

  let forget (b, _) = b

  let remember (b, delta_block_chain_proof) =
    ( b
    , ( (`Time_received, Truth.True ())
      , (`Genesis_state, Truth.True ())
      , (`Proof, Truth.True ())
      , (`Delta_block_chain, Truth.True delta_block_chain_proof)
      , (`Frontier_dependencies, Truth.True ())
      , (`Staged_ledger_diff, Truth.True ())
      , (`Protocol_versions, Truth.True ()) ) )

  let delta_block_chain_proof (_, d) = d

  let valid_commands (block, _) =
    block |> With_hash.data |> Block.body |> Body.staged_ledger_diff
    |> Staged_ledger_diff.commands
    |> List.map ~f:(fun cmd ->
           (* This is safe because at this point the stage ledger diff has been
                applied successfully. *)
           let (`If_this_is_used_it_should_have_a_comment_justifying_it data) =
             User_command.to_valid_unsafe cmd.data
           in
           { cmd with data })

  let unsafe_of_trusted_block ~delta_block_chain_proof
      (`This_block_is_trusted_to_be_safe b) =
    (b, delta_block_chain_proof)

  let state_hash (b, _) = State_hash.With_state_hashes.state_hash b

  let state_body_hash (t, _) =
    State_hash.With_state_hashes.state_body_hash t
      ~compute_hashes:
        (Fn.compose Protocol_state.hashes
           (Fn.compose Header.protocol_state Block.header))

  let header t = t |> forget |> With_hash.data |> Block.header

  let body t = t |> forget |> With_hash.data |> Block.body
end

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
