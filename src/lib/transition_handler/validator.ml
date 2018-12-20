open Async_kernel
open Core_kernel
open Pipe_lib.Strict_pipe
open Coda_base
open Protocols.Coda_transition_frontier

module Make (Inputs : Inputs.S) :
  Transition_handler_validator_intf
  with type time := Inputs.Time.t
   and type state_hash := State_hash.t
   and type external_transition_with_valid_protocol_state :=
              Inputs.External_transition.With_valid_protocol_state.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type staged_ledger := Inputs.Staged_ledger.t = struct
  open Inputs
  open Consensus.Mechanism
  open Deferred.Let_syntax

  let is_in_frontier ~logger ~frontier transition =
    let psh =
      Protocol_state.hash
        (External_transition.With_valid_protocol_state.protocol_state
           transition)
    in
    if Transition_frontier.find frontier psh |> Option.is_some then (
      Logger.info logger
        !"we've already seen protocol state %{sexp:State_hash.t}"
        psh ;
      `Duplicate )
    else `Valid

  let validate_transition ~logger ~frontier ~time_received t_env =
    (* it's like bool option but with names (`Duplicate is None). *)
    let ( && ) a b =
      match (a, b) with
      | _, `Duplicate -> `Duplicate
      | `Duplicate, _ -> `Duplicate
      | _, `Reject -> `Reject
      | `Reject, _ -> `Reject
      | `Valid, `Valid -> `Valid
    in
    let transition : External_transition.With_valid_protocol_state.t =
      Envelope.Incoming.data t_env
    in
    let time_received =
      Time.to_span_since_epoch time_received
      |> Time.Span.to_ms |> Unix_timestamp.of_int64
    in
    let log_assert condition error_msg =
      let log () =
        Logger.info logger "transition rejected: %s" error_msg ;
        `Reject
      in
      if condition then `Valid else log ()
    in
    let consensus_state =
      Fn.compose Protocol_state.consensus_state
        External_transition.protocol_state
    in
    let consensus_state_verified =
      Fn.compose Protocol_state.consensus_state
        External_transition.protocol_state
    in
    let root =
      With_hash.data
        (Transition_frontier.Breadcrumb.transition_with_hash
           (Transition_frontier.root frontier))
      |> External_transition.Verified.forget
    in
    let valid_protocol_state_root = root in
    is_in_frontier ~logger ~frontier transition
    && log_assert
         ( Consensus.Mechanism.select ~logger
             ~existing:(consensus_state_verified valid_protocol_state_root)
             ~candidate:(consensus_state valid_protocol_state_root)
             ~time_received
         = `Take )
         "was not better than root"

  let verify_transition ~staged_ledger
      ~(transition : External_transition.With_valid_protocol_state.t) :
      External_transition.Verified.t Or_error.t Deferred.t =
    let open Deferred.Or_error.Let_syntax in
    let diff =
      External_transition.With_valid_protocol_state.staged_ledger_diff
        transition
    in
    let%bind verified_diff =
      Staged_ledger.verified_diff_of_diff staged_ledger diff
    in
    return
      (External_transition.Verified.create
         ~protocol_state:
           (External_transition.With_valid_protocol_state.protocol_state
              transition)
         ~protocol_state_proof:
           (External_transition.With_valid_protocol_state.protocol_state_proof
              transition)
         ~staged_ledger_diff:verified_diff)

  let warn_invalid_transition ~logger transition_env =
    Logger.warn logger
      !"failed to verify transition from the network! sent by %{sexp: \
        Host_and_port.t}"
      (Envelope.Incoming.sender transition_env)

  let run ~logger ~frontier ~transition_reader ~valid_transition_writer =
    let logger =
      Logger.child logger "transition_handler_validator_and_verifier"
    in
    don't_wait_for
      (Reader.iter transition_reader
         ~f:(fun (`Transition transition_env, `Time_received time_received) ->
           let (transition : External_transition.With_valid_protocol_state.t) =
             Envelope.Incoming.data transition_env
           in
           match
             validate_transition ~logger ~frontier ~time_received
               transition_env
           with
           | `Valid -> (
               (* TODO: staged_ledger_diff verification should be done in the processor #1344 *)
               let tip = Transition_frontier.best_tip frontier in
               let staged_ledger =
                 Transition_frontier.Breadcrumb.staged_ledger tip
               in
               let%map maybe_verified_transaction =
                 verify_transition ~staged_ledger ~transition
               in
               match maybe_verified_transaction with
               | Ok verified_transition ->
                   Writer.write valid_transition_writer
                     (With_hash.of_data verified_transition
                        ~hash_data:
                          (Fn.compose Protocol_state.hash
                             External_transition.Verified.protocol_state))
               | Error _ ->
                   (* TODO: Punish *)
                   warn_invalid_transition ~logger transition_env )
           | `Duplicate -> return ()
           | `Reject ->
               return @@ warn_invalid_transition ~logger transition_env ))
end

(*
let%test_module "Validator tests" = (module struct
  module Inputs = struct
    module External_transition = struct
      include Test_stubs.External_transition.Full(struct
        type t = int
      end)

      let is_valid n = n >= 0
      (* let select n = n > *)
    end

    module Consensus_mechanism = Consensus_mechanism.Proof_of_stake
    module Transition_frontier = Test_stubs.Transition_frontier.Constant_root (struct
      let root = Consensus_mechanism.genesis
    end)
  end
  module Transition_handler = Make (Inputs)

  open Inputs
  open Consensus_mechanism

  let%test "validate_transition" =
    let test ~inputs ~expectations =
      let result = Ivar.create () in
      let (in_r, in_w) = Linear_pipe.create () in
      let (out_r, out_w) = Linear_pipe.create () in
      run ~transition_reader:in_r ~valid_transition_writer:out_w frontier;
      don't_wait_for (Linear_pipe.flush inputs in_w);
      don't_wait_for (Linear_pipe.fold_maybe out_r ~init:expectations ~f:(fun expect result ->
          let open Option.Let_syntax in
          let%bind expect = match expect with
            | h :: t ->
                if External_transition.equal result expect then
                  Some t
                else (
                  Ivar.fill result false;
                  None)
            | [] ->
                failwith "read more transitions than expected"
          in
          if expect = [] then (
            Ivar.fill result true;
            None)
          else
            Some expect));
      assert (Ivar.wait result)
    in
    Quickcheck.test (List.gen Int.gen) ~f:(fun inputs ->
      let expectations = List.map inputs ~f:(fun n -> n > 5) in
      test ~inputs ~expectations)
end)
*)
