open Core_kernel
open Mina_base
open Mina_state

include Block

module Body = Body

module Body_reference = Body_reference

module Header = Header

module Validation = Validation

module Precomputed = Precomputed

type fully_invalid_block = Validation.fully_invalid_with_block

type initial_valid_block = Validation.initial_valid_with_block

type almost_valid_block = Validation.almost_valid_with_block

type fully_valid_block = Validation.fully_valid_with_block

let genesis ~precomputed_values : fully_valid_block =
  let genesis_state = Precomputed_values.genesis_state_with_hash precomputed_values in
  let protocol_state = With_hash.data genesis_state in
  let block_with_hash = 
    let body = Body.create Staged_ledger_diff.empty_diff in
    let body_reference = Body_reference.of_body body in
    let header =
      Header.create
        ~body_reference
        ~protocol_state
        ~protocol_state_proof:Proof.blockchain_dummy
        ~delta_block_chain_proof:(Protocol_state.previous_state_hash protocol_state, [])
        ()
    in
    let block = create ~header ~body in
    With_hash.map genesis_state ~f:(Fn.const block)
  in
  let validation : Validation.fully_valid =
    ( (`Time_received, Truth.True ())
    , (`Genesis_state, Truth.True ())
    , (`Proof, Truth.True ())
    , (`Delta_block_chain, Truth.True (Non_empty_list.init (Protocol_state.previous_state_hash protocol_state) []))
    , (`Frontier_dependencies, Truth.True ())
    , (`Staged_ledger_diff, Truth.True ())
    , (`Protocol_versions, Truth.True ()) )
  in
  (block_with_hash, validation)

module Validated : sig
  type t [@@deriving sexp, to_yojson]

  val lift : fully_valid_block -> t

  val forget : t -> with_hash

  val remember : t -> fully_valid_block

  val delta_block_chain_proof : t -> State_hash.t Non_empty_list.t

  val valid_commands : t -> User_command.Valid.t With_status.t list

  val unsafe_of_trusted_block : delta_block_chain_proof:State_hash.t Non_empty_list.t -> [`This_block_is_trusted_to_be_safe of with_hash] -> t

  val state_hash : t -> State_hash.t

  val header : t -> Header.t

  val body : t -> Body.t
end = struct
  type t = with_hash * State_hash.t Non_empty_list.t [@@deriving sexp, to_yojson]

  let lift ((b, v) : fully_valid_block) =
    match v with
    | (_, _ ,_, (`Delta_block_chain, Truth.True delta_block_chain_proof), _, _, _) ->
        (b, delta_block_chain_proof)
    | _ -> failwith "this case should be refutable, but isn't for some reason"

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
    block
    |> With_hash.data
    |> Block.body
    |> Body.staged_ledger_diff
    |> Staged_ledger_diff.commands
    |> List.map ~f:(fun cmd ->
        (* This is safe because at this point the stage ledger diff has been
             applied successfully. *)
        let (`If_this_is_used_it_should_have_a_comment_justifying_it data) =
          User_command.to_valid_unsafe cmd.data
        in
        { cmd with data })


  let unsafe_of_trusted_block ~delta_block_chain_proof (`This_block_is_trusted_to_be_safe b) = (b, delta_block_chain_proof)

  let state_hash (b, _) = With_hash.hash b

  let header t = t |> forget |> With_hash.data |> header

  let body t = t |> forget |> With_hash.data |> body
end
