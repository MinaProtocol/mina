open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Coda_base
open Consensus.Mechanism

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module State_proof :
    Proof_intf
    with type input := Consensus.Mechanism.Protocol_state.value
     and type t := Proof.t

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type ledger_database := Ledger.Db.t
     and type staged_ledger := Staged_ledger.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type masked_ledger := Coda_base.Ledger.t
end

module Make (Inputs : Inputs_intf) :
  External_transition_validation_intf
  with type state_hash := State_hash.t
   and type external_transition := Inputs.External_transition.t
   and type staged_ledger := Inputs.Staged_ledger.t
   and type staged_ledger_error := Inputs.Staged_ledger.Staged_ledger_error.t
   and type transition_frontier := Inputs.Transition_frontier.t = struct
  open Inputs

  type ('time_received, 'proof, 'frontier_dependencies, 'staged_ledger_diff) t =
    'time_received * 'proof * 'frontier_dependencies * 'staged_ledger_diff
    constraint 'time_received = [`Time_received] * _ Truth.t
    constraint 'proof = [`Proof] * _ Truth.t
    constraint 'frontier_dependencies = [`Frontier_dependencies] * _ Truth.t
    constraint 'staged_ledger_diff = [`Staged_ledger_diff] * _ Truth.t

  type 'a all =
    ( [`Time_received] * 'a
    , [`Proof] * 'a
    , [`Frontier_dependencies] * 'a
    , [`Staged_ledger_diff] * 'a )
    t
    constraint 'a = _ Truth.t

  type fully_invalid = Truth.false_t all

  type fully_valid = Truth.true_t all

  type ('time_received, 'proof, 'frontier_dependencies, 'staged_ledger_diff) with_transition =
    (External_transition.t, State_hash.t) With_hash.t
    * ('time_received, 'proof, 'frontier_dependencies, 'staged_ledger_diff) t

  let all t =
    ( (`Time_received, t)
    , (`Proof, t)
    , (`Frontier_dependencies, t)
    , (`Staged_ledger_diff, t) )

  let fully_invalid = all Truth.False

  let fully_valid = all Truth.True

  module Unsafe = struct
    let set_valid_time_received :
           ( [`Time_received] * Truth.false_t
           , 'proof
           , 'frontier_dependencies
           , 'staged_ledger_diff )
           t
        -> ( [`Time_received] * Truth.true_t
           , 'proof
           , 'frontier_dependencies
           , 'staged_ledger_diff )
           t = function
      | ( (`Time_received, Truth.False)
        , proof
        , frontier_dependencies
        , staged_ledger_diff ) ->
          ( (`Time_received, Truth.True)
          , proof
          , frontier_dependencies
          , staged_ledger_diff )
      | _ -> failwith "why can't this be refuted?"

    let set_valid_proof :
           ( 'time_received
           , [`Proof] * Truth.false_t
           , 'frontier_dependencies
           , 'staged_ledger_diff )
           t
        -> ( 'time_received
           , [`Proof] * Truth.true_t
           , 'frontier_dependencies
           , 'staged_ledger_diff )
           t = function
      | ( time_received
        , (`Proof, Truth.False)
        , frontier_dependencies
        , staged_ledger_diff ) ->
          ( time_received
          , (`Proof, Truth.True)
          , frontier_dependencies
          , staged_ledger_diff )
      | _ -> failwith "why can't this be refuted?"

    let set_valid_frontier_dependencies :
           ( 'time_received
           , 'proof
           , [`Frontier_dependencies] * Truth.false_t
           , 'staged_ledger_diff )
           t
        -> ( 'time_received
           , 'proof
           , [`Frontier_dependencies] * Truth.true_t
           , 'staged_ledger_diff )
           t = function
      | ( time_received
        , proof
        , (`Frontier_dependencies, Truth.False)
        , staged_ledger_diff ) ->
          ( time_received
          , proof
          , (`Frontier_dependencies, Truth.True)
          , staged_ledger_diff )
      | _ -> failwith "why can't this be refuted?"

    let set_valid_staged_ledger_diff :
           ( 'time_received
           , 'proof
           , 'frontier_dependencies
           , [`Staged_ledger_diff] * Truth.false_t )
           t
        -> ( 'time_received
           , 'proof
           , 'frontier_dependencies
           , [`Staged_ledger_diff] * Truth.true_t )
           t = function
      | ( time_received
        , proof
        , frontier_dependencies
        , (`Staged_ledger_diff, Truth.False) ) ->
          ( time_received
          , proof
          , frontier_dependencies
          , (`Staged_ledger_diff, Truth.True) )
      | _ -> failwith "why can't this be refuted?"
  end

  let validate_time_received (t, validation) ~time_received =
    let consensus_state =
      With_hash.data t |> External_transition.protocol_state
      |> Protocol_state.consensus_state
    in
    if
      Consensus.Mechanism.received_at_valid_time consensus_state ~time_received
    then Ok (t, Unsafe.set_valid_time_received validation)
    else Error `Invalid_time_received

  let validate_proof (t, validation) =
    let open External_transition in
    let open Deferred.Let_syntax in
    let transition = With_hash.data t in
    if%map
      State_proof.verify
        (protocol_state_proof transition)
        (protocol_state transition)
    then Ok (t, Unsafe.set_valid_proof validation)
    else Error `Invalid_proof

  let validate_frontier_dependencies (t, validation) ~logger ~frontier =
    let open Result.Let_syntax in
    let hash = With_hash.hash t in
    let protocol_state =
      External_transition.protocol_state (With_hash.data t)
    in
    let root_protocol_state =
      Transition_frontier.root frontier
      |> Transition_frontier.Breadcrumb.transition_with_hash |> With_hash.data
      (* TODO: remove verified when this is plugged in *)
      |> External_transition.Verified.protocol_state
    in
    let%bind () =
      Result.ok_if_true
        (Transition_frontier.find frontier hash |> Option.is_none)
        ~error:`Already_in_frontier
    in
    let%map () =
      Result.ok_if_true
        ( `Take
        = Consensus.Mechanism.select ~logger
            ~existing:(Protocol_state.consensus_state root_protocol_state)
            ~candidate:(Protocol_state.consensus_state protocol_state) )
        ~error:`Not_selected_over_frontier_root
    in
    (t, Unsafe.set_valid_frontier_dependencies validation)

  let target_hash_of_ledger_proof =
    let open Ledger_proof in
    Fn.compose statement_target statement

  let validate_staged_ledger_diff :
         ( 'time_received
         , 'proof
         , 'frontier_dependencies
         , [`Staged_ledger_diff] * Truth.false_t )
         with_transition
      -> logger:Logger.t
      -> parent_staged_ledger:Staged_ledger.t
      -> ( ( 'time_received
           , 'proof
           , 'frontier_dependencies
           , [`Staged_ledger_diff] * Truth.true_t )
           with_transition
           * Staged_ledger.t
         , [ `Invalid_ledger_hash_after_staged_ledger_application
           | `Staged_ledger_application_failed of Staged_ledger
                                                  .Staged_ledger_error
                                                  .t ] )
         Deferred.Result.t =
   fun (t, validation) ~logger ~parent_staged_ledger ->
    let open Deferred.Result.Let_syntax in
    let transition = With_hash.data t in
    let blockchain_state =
      Protocol_state.blockchain_state
        (External_transition.protocol_state transition)
    in
    let staged_ledger_diff =
      External_transition.staged_ledger_diff transition
    in
    let%bind ( `Hash_after_applying staged_ledger_hash
             , `Ledger_proof proof_opt
             , `Staged_ledger transitioned_staged_ledger ) =
      Staged_ledger.apply ~logger parent_staged_ledger staged_ledger_diff
      |> Deferred.Result.map_error ~f:(fun e ->
             `Staged_ledger_application_failed e )
    in
    let target_ledger_hash =
      match proof_opt with
      | None ->
          Option.value_map
            (Inputs.Staged_ledger.current_ledger_proof
               transitioned_staged_ledger)
            ~f:target_hash_of_ledger_proof
            ~default:
              (Frozen_ledger_hash.of_ledger_hash
                 (Ledger.merkle_root Genesis_ledger.t))
      | Some proof -> target_hash_of_ledger_proof proof
    in
    Deferred.return
      ( if
        Frozen_ledger_hash.equal target_ledger_hash
          (Blockchain_state.ledger_hash blockchain_state)
        && Staged_ledger_hash.equal staged_ledger_hash
             (Blockchain_state.staged_ledger_hash blockchain_state)
      then
        Ok
          ( (t, Unsafe.set_valid_staged_ledger_diff validation)
          , transitioned_staged_ledger )
      else Error `Invalid_ledger_hash_after_staged_ledger_application )
end
