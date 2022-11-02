(* TODO: refactor
   - validations need to be simplified and merged
     - also need to think if data-carrying validations makes sense or not
   - initial validation properties should all be combined, with different validation entrypoints for each use case
   - frontier validation needs re-thought
*)

open Async_kernel
open Core_kernel
open Mina_base
open Mina_state
open Consensus.Data
include Validation_types

module type CONTEXT = sig
  val logger : Logger.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

let validation (_, v) = v

let block_with_hash (b, _) = b

let block (b, _) = With_hash.data b

let wrap t : fully_invalid_with_block = (t, fully_invalid)

module Unsafe = struct
  let set_valid_time_received :
         ( [ `Time_received ] * unit Truth.false_t
         , 'genesis_state
         , 'proof
         , 'delta_block_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff
         , 'protocol_versions )
         t
      -> ( [ `Time_received ] * unit Truth.true_t
         , 'genesis_state
         , 'proof
         , 'delta_block_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff
         , 'protocol_versions )
         t = function
    | ( (`Time_received, Truth.False)
      , genesis_state
      , proof
      , delta_block_chain
      , frontier_dependencies
      , staged_ledger_diff
      , protocol_versions ) ->
        ( (`Time_received, Truth.True ())
        , genesis_state
        , proof
        , delta_block_chain
        , frontier_dependencies
        , staged_ledger_diff
        , protocol_versions )

  let set_valid_proof :
         ( 'time_received
         , 'genesis_state
         , [ `Proof ] * unit Truth.false_t
         , 'delta_block_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff
         , 'protocol_versions )
         t
      -> ( 'time_received
         , 'genesis_state
         , [ `Proof ] * unit Truth.true_t
         , 'delta_block_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff
         , 'protocol_versions )
         t = function
    | ( time_received
      , genesis_state
      , (`Proof, Truth.False)
      , delta_block_chain
      , frontier_dependencies
      , staged_ledger_diff
      , protocol_versions ) ->
        ( time_received
        , genesis_state
        , (`Proof, Truth.True ())
        , delta_block_chain
        , frontier_dependencies
        , staged_ledger_diff
        , protocol_versions )

  let set_valid_genesis_state :
         ( 'time_received
         , [ `Genesis_state ] * unit Truth.false_t
         , 'proof
         , 'delta_block_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff
         , 'protocol_versions )
         t
      -> ( 'time_received
         , [ `Genesis_state ] * unit Truth.true_t
         , 'proof
         , 'delta_block_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff
         , 'protocol_versions )
         t = function
    | ( time_received
      , (`Genesis_state, Truth.False)
      , proof
      , delta_block_chain
      , frontier_dependencies
      , staged_ledger_diff
      , protocol_versions ) ->
        ( time_received
        , (`Genesis_state, Truth.True ())
        , proof
        , delta_block_chain
        , frontier_dependencies
        , staged_ledger_diff
        , protocol_versions )

  let set_valid_delta_block_chain :
         ( 'time_received
         , 'genesis_state
         , 'proof
         , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.false_t
         , 'frontier_dependencies
         , 'staged_ledger_diff
         , 'protocol_versions )
         t
      -> State_hash.t Non_empty_list.t
      -> ( 'time_received
         , 'genesis_state
         , 'proof
         , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.true_t
         , 'frontier_dependencies
         , 'staged_ledger_diff
         , 'protocol_versions )
         t =
   fun validation hashes ->
    match validation with
    | ( time_received
      , genesis_state
      , proof
      , (`Delta_block_chain, Truth.False)
      , frontier_dependencies
      , staged_ledger_diff
      , protocol_versions ) ->
        ( time_received
        , genesis_state
        , proof
        , (`Delta_block_chain, Truth.True hashes)
        , frontier_dependencies
        , staged_ledger_diff
        , protocol_versions )

  let set_valid_frontier_dependencies :
         ( 'time_received
         , 'genesis_state
         , 'proof
         , 'delta_block_chain
         , [ `Frontier_dependencies ] * unit Truth.false_t
         , 'staged_ledger_diff
         , 'protocol_versions )
         t
      -> ( 'time_received
         , 'genesis_state
         , 'proof
         , 'delta_block_chain
         , [ `Frontier_dependencies ] * unit Truth.true_t
         , 'staged_ledger_diff
         , 'protocol_versions )
         t = function
    | ( time_received
      , genesis_state
      , proof
      , delta_block_chain
      , (`Frontier_dependencies, Truth.False)
      , staged_ledger_diff
      , protocol_versions ) ->
        ( time_received
        , genesis_state
        , proof
        , delta_block_chain
        , (`Frontier_dependencies, Truth.True ())
        , staged_ledger_diff
        , protocol_versions )

  let set_valid_staged_ledger_diff :
         ( 'time_received
         , 'genesis_state
         , 'proof
         , 'delta_block_chain
         , 'frontier_dependencies
         , [ `Staged_ledger_diff ] * unit Truth.false_t
         , 'protocol_versions )
         t
      -> ( 'time_received
         , 'genesis_state
         , 'proof
         , 'delta_block_chain
         , 'frontier_dependencies
         , [ `Staged_ledger_diff ] * unit Truth.true_t
         , 'protocol_versions )
         t = function
    | ( time_received
      , genesis_state
      , proof
      , delta_block_chain
      , frontier_dependencies
      , (`Staged_ledger_diff, Truth.False)
      , protocol_versions ) ->
        ( time_received
        , genesis_state
        , proof
        , delta_block_chain
        , frontier_dependencies
        , (`Staged_ledger_diff, Truth.True ())
        , protocol_versions )

  let set_valid_protocol_versions :
         ( 'time_received
         , 'genesis_state
         , 'proof
         , 'delta_block_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff
         , [ `Protocol_versions ] * unit Truth.false_t )
         t
      -> ( 'time_received
         , 'genesis_state
         , 'proof
         , 'delta_block_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff
         , [ `Protocol_versions ] * unit Truth.true_t )
         t = function
    | ( time_received
      , genesis_state
      , proof
      , delta_block_chain
      , frontier_dependencies
      , staged_ledger_diff
      , (`Protocol_versions, Truth.False) ) ->
        ( time_received
        , genesis_state
        , proof
        , delta_block_chain
        , frontier_dependencies
        , staged_ledger_diff
        , (`Protocol_versions, Truth.True ()) )
end

let validate_time_received ~(precomputed_values : Precomputed_values.t)
    ~time_received (t, validation) =
  let consensus_state =
    t |> With_hash.data |> Block.header |> Header.protocol_state
    |> Protocol_state.consensus_state
  in
  let constants = precomputed_values.consensus_constants in
  let received_unix_timestamp =
    Block_time.to_span_since_epoch time_received |> Block_time.Span.to_ms
  in
  match
    Consensus.Hooks.received_at_valid_time ~constants consensus_state
      ~time_received:received_unix_timestamp
  with
  | Ok () ->
      Ok (t, Unsafe.set_valid_time_received validation)
  | Error err ->
      Error (`Invalid_time_received err)

let skip_time_received_validation `This_block_was_not_received_via_gossip
    (t, validation) =
  (t, Unsafe.set_valid_time_received validation)

let validate_genesis_protocol_state ~genesis_state_hash (t, validation) =
  let state = t |> With_hash.data |> Block.header |> Header.protocol_state in
  if
    State_hash.equal
      (Protocol_state.genesis_state_hash state)
      genesis_state_hash
  then Ok (t, Unsafe.set_valid_genesis_state validation)
  else Error `Invalid_genesis_protocol_state

let skip_genesis_protocol_state_validation `This_block_was_generated_internally
    (t, validation) =
  (t, Unsafe.set_valid_genesis_state validation)

let reset_genesis_protocol_state_validation (block_with_hash, validation) =
  match validation with
  | ( time_received
    , (`Genesis_state, Truth.True ())
    , proof
    , delta_block_chain
    , frontier_dependencies
    , staged_ledger_diff
    , protocol_versions ) ->
      ( block_with_hash
      , ( time_received
        , (`Genesis_state, Truth.False)
        , proof
        , delta_block_chain
        , frontier_dependencies
        , staged_ledger_diff
        , protocol_versions ) )
  | _ ->
      failwith "why can't this be refuted?"

let validate_proofs ~verifier ~genesis_state_hash tvs =
  let to_verify =
    List.filter_map tvs ~f:(fun (t, _validation) ->
        if
          State_hash.equal
            (State_hash.With_state_hashes.state_hash t)
            genesis_state_hash
        then
          (* Don't require a valid proof for the genesis block, since the
             peer may not have one.
          *)
          None
        else
          let header = Block.header @@ With_hash.data t in
          Some
            (Blockchain_snark.Blockchain.create
               ~state:(Header.protocol_state header)
               ~proof:(Header.protocol_state_proof header) ) )
  in
  match%map.Deferred
    match to_verify with
    | [] ->
        (* Skip calling the verifier, nothing here to verify. *)
        return (Ok true)
    | _ ->
        Verifier.verify_blockchain_snarks verifier to_verify
  with
  | Ok verified ->
      if verified then
        Ok
          (List.map tvs ~f:(fun (t, validation) ->
               (t, Unsafe.set_valid_proof validation) ) )
      else Error `Invalid_proof
  | Error e ->
      Error (`Verifier_error e)

let validate_single_proof ~verifier ~genesis_state_hash t =
  let open Deferred.Result.Let_syntax in
  let%map res = validate_proofs ~verifier ~genesis_state_hash [ t ] in
  List.hd_exn res

let skip_proof_validation `This_block_was_generated_internally (t, validation) =
  (t, Unsafe.set_valid_proof validation)

let extract_delta_block_chain_witness = function
  | _, _, _, (`Delta_block_chain, Truth.True delta_block_chain_witness), _, _, _
    ->
      delta_block_chain_witness
  | _ ->
      failwith "why can't this be refuted?"

let validate_delta_block_chain (t, validation) =
  let header = t |> With_hash.data |> Block.header in
  match
    Transition_chain_verifier.verify
      ~target_hash:
        (header |> Header.protocol_state |> Protocol_state.previous_state_hash)
      ~transition_chain_proof:(Header.delta_block_chain_proof header)
  with
  | Some hashes ->
      Ok (t, Unsafe.set_valid_delta_block_chain validation hashes)
  | None ->
      Error `Invalid_delta_block_chain_proof

let skip_delta_block_chain_validation `This_block_was_not_received_via_gossip
    (t, validation) =
  let previous_protocol_state_hash =
    t |> With_hash.data |> Block.header |> Header.protocol_state
    |> Protocol_state.previous_state_hash
  in
  ( t
  , Unsafe.set_valid_delta_block_chain validation
      (Non_empty_list.singleton previous_protocol_state_hash) )

let validate_frontier_dependencies ~context:(module Context : CONTEXT)
    ~root_block ~get_block_by_hash (t, validation) =
  let module Context = struct
    include Context

    let logger =
      Logger.extend logger
        [ ( "selection_context"
          , `String "Mina_block.Validation.validate_frontier_dependencies" )
        ]
  end in
  let open Result.Let_syntax in
  let hash = State_hash.With_state_hashes.state_hash t in
  let protocol_state = Fn.compose Header.protocol_state Block.header in
  let parent_hash =
    Protocol_state.previous_state_hash (protocol_state @@ With_hash.data t)
  in
  let consensus_state =
    Fn.compose Protocol_state.consensus_state protocol_state
  in
  let%bind () =
    Result.ok_if_true
      (hash |> get_block_by_hash |> Option.is_none)
      ~error:`Already_in_frontier
  in
  let%bind () =
    (* need pervasive (=) in scope for comparing polymorphic variant *)
    let ( = ) = Stdlib.( = ) in
    Result.ok_if_true
      ( `Take
      = Consensus.Hooks.select
          ~context:(module Context)
          ~existing:(With_hash.map ~f:consensus_state root_block)
          ~candidate:(With_hash.map ~f:consensus_state t) )
      ~error:`Not_selected_over_frontier_root
  in
  let%map () =
    Result.ok_if_true
      (parent_hash |> get_block_by_hash |> Option.is_some)
      ~error:`Parent_missing_from_frontier
  in
  (t, Unsafe.set_valid_frontier_dependencies validation)

let skip_frontier_dependencies_validation
    (_ :
      [ `This_block_belongs_to_a_detached_subtree
      | `This_block_was_loaded_from_persistence ] ) (t, validation) =
  (t, Unsafe.set_valid_frontier_dependencies validation)

let reset_frontier_dependencies_validation (transition_with_hash, validation) =
  match validation with
  | ( time_received
    , genesis_state
    , proof
    , delta_block_chain
    , (`Frontier_dependencies, Truth.True ())
    , staged_ledger_diff
    , protocol_versions ) ->
      ( transition_with_hash
      , ( time_received
        , genesis_state
        , proof
        , delta_block_chain
        , (`Frontier_dependencies, Truth.False)
        , staged_ledger_diff
        , protocol_versions ) )
  | _ ->
      failwith "why can't this be refuted?"

let validate_staged_ledger_diff ?skip_staged_ledger_verification ~logger
    ~precomputed_values ~verifier ~parent_staged_ledger ~parent_protocol_state
    (t, validation) =
  let target_hash_of_ledger_proof =
    Fn.compose Registers.second_pass_ledger
    @@ Fn.compose Ledger_proof.statement_target Ledger_proof.statement
  in
  let block = With_hash.data t in
  let header = Block.header block in
  let protocol_state = Header.protocol_state header in
  let blockchain_state = Protocol_state.blockchain_state protocol_state in
  let consensus_state = Protocol_state.consensus_state protocol_state in
  let body = Block.body block in
  let apply_start_time = Core.Time.now () in
  let body_ref_from_header = Blockchain_state.body_reference blockchain_state in
  let body_ref_computed = Staged_ledger_diff.Body.compute_reference body in
  let%bind.Deferred.Result () =
    if Blake2.equal body_ref_computed body_ref_from_header then
      Deferred.Result.return ()
    else Deferred.Result.fail `Invalid_body_reference
  in
  let%bind.Deferred.Result ( `Hash_after_applying staged_ledger_hash
                           , `Ledger_proof proof_opt
                           , `Staged_ledger transitioned_staged_ledger
                           , `Pending_coinbase_update _ ) =
    Staged_ledger.apply ?skip_verification:skip_staged_ledger_verification
      ~constraint_constants:
        precomputed_values.Precomputed_values.constraint_constants ~logger
      ~verifier parent_staged_ledger
      (Staged_ledger_diff.Body.staged_ledger_diff body)
      ~current_state_view:
        Mina_state.Protocol_state.(Body.view @@ body parent_protocol_state)
      ~state_and_body_hash:
        (let body_hash =
           Protocol_state.(Body.hash @@ body parent_protocol_state)
         in
         ( (Protocol_state.hashes_with_body parent_protocol_state ~body_hash)
             .state_hash
         , body_hash ) )
      ~coinbase_receiver:(Consensus_state.coinbase_receiver consensus_state)
      ~supercharge_coinbase:
        (Consensus_state.supercharge_coinbase consensus_state)
    |> Deferred.Result.map_error ~f:(fun e ->
           `Staged_ledger_application_failed e )
  in
  [%log debug]
    ~metadata:
      [ ( "time_elapsed"
        , `Float Core.Time.(Span.to_ms @@ diff (now ()) apply_start_time) )
      ]
    "Staged_ledger.apply takes $time_elapsed" ;
  let target_ledger_hash =
    match proof_opt with
    | None ->
        Option.value_map
          (Staged_ledger.current_ledger_proof transitioned_staged_ledger)
          ~f:target_hash_of_ledger_proof
          ~default:
            ( Precomputed_values.genesis_ledger precomputed_values
            |> Lazy.force |> Mina_ledger.Ledger.merkle_root
            |> Frozen_ledger_hash.of_ledger_hash )
    | Some (proof, _) ->
        target_hash_of_ledger_proof proof
  in
  let maybe_errors =
    Option.all
      [ Option.some_if
          (not
             (Staged_ledger_hash.equal staged_ledger_hash
                (Blockchain_state.staged_ledger_hash blockchain_state) ) )
          `Incorrect_target_staged_ledger_hash
      ; Option.some_if
          (not
             (Frozen_ledger_hash.equal target_ledger_hash
                (Blockchain_state.snarked_ledger_hash blockchain_state) ) )
          `Incorrect_target_snarked_ledger_hash
      ]
  in
  Deferred.return
    ( match maybe_errors with
    | Some errors ->
        Error (`Invalid_staged_ledger_diff errors)
    | None ->
        Ok
          ( `Just_emitted_a_proof (Option.is_some proof_opt)
          , `Block_with_validation
              (t, Unsafe.set_valid_staged_ledger_diff validation)
          , `Staged_ledger transitioned_staged_ledger ) )

let validate_staged_ledger_hash
    (`Staged_ledger_already_materialized staged_ledger_hash) (t, validation) =
  let state =
    t |> With_hash.data |> Block.header |> Header.protocol_state
    |> Protocol_state.blockchain_state
  in
  if
    Staged_ledger_hash.equal staged_ledger_hash
      (Blockchain_state.staged_ledger_hash state)
  then Ok (t, Unsafe.set_valid_staged_ledger_diff validation)
  else Error `Staged_ledger_hash_mismatch

let skip_staged_ledger_diff_validation `This_block_has_a_trusted_staged_ledger
    (t, validation) =
  (t, Unsafe.set_valid_staged_ledger_diff validation)

let reset_staged_ledger_diff_validation (transition_with_hash, validation) =
  match validation with
  | ( time_received
    , genesis_state
    , proof
    , delta_block_chain
    , frontier_dependencies
    , (`Staged_ledger_diff, Truth.True ())
    , protocol_versions ) ->
      ( transition_with_hash
      , ( time_received
        , genesis_state
        , proof
        , delta_block_chain
        , frontier_dependencies
        , (`Staged_ledger_diff, Truth.False)
        , protocol_versions ) )
  | _ ->
      failwith "why can't this be refuted?"

let validate_protocol_versions (t, validation) =
  let { Header.valid_current; valid_next; matches_daemon } =
    t |> With_hash.data |> Block.header |> Header.protocol_version_status
  in
  if not (valid_current && valid_next) then Error `Invalid_protocol_version
  else if not matches_daemon then Error `Mismatched_protocol_version
  else Ok (t, Unsafe.set_valid_protocol_versions validation)

let skip_protocol_versions_validation `This_block_has_valid_protocol_versions
    (t, validation) =
  (t, Unsafe.set_valid_protocol_versions validation)
