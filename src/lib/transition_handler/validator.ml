open Async_kernel
open Core_kernel
open Pipe_lib.Strict_pipe
open Protocols.Coda_pow
open Coda_base

(* TODO: what conditions should we punish? *)
(* TODO:
  let length = External_transition.protocol_state t |> Protocol_state.blockchain_state |> Blockchain_state.length in
  log_assert
    (match Root_history.find (Transition_frontier.root_history frontier) (length - k) with
    | `Known h -> State_hash.equal h (External_transition.frontier_root_hash t)
    | `Unknown -> true
    | `Out_of_bounds ->
      Logger.info logger "expected root of transition was out of bounds";
      false)
    "transition frontier root hash was invalid"
*)

module Make (Inputs : Inputs.S) :
  Transition_handler_validator_intf
  with type time := Inputs.Time.t
   and type state_hash := State_hash.t
   and type external_transition := Inputs.External_transition.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type staged_ledger := Inputs.Staged_ledger.t = struct
  open Inputs
  open Consensus.Mechanism
  open Deferred.Let_syntax

  (* NOTE FOR PR REVIEWER: are these lazys confusing? is there a neater way to do this? *)
  let validate_transition ?time_received ~logger ~frontier transition_with_hash
      =
    let open With_hash in
    let open Protocol_state in
    let {hash; data= transition} = transition_with_hash in
    let protocol_state = External_transition.protocol_state transition in
    let root_protocol_state =
      Transition_frontier.root frontier
      |> Transition_frontier.Breadcrumb.transition_with_hash |> With_hash.data
      |> External_transition.Verified.protocol_state
    in
    if Transition_frontier.find frontier hash |> Option.is_some then
      Deferred.return (Error `Duplicate)
    else
      (* these are done separately in order to avoid encoding
       * synchronicity into the deferred monad *)
      let synchronous_result =
        let open Result.Let_syntax in
        let%bind () =
          match time_received with
          | None -> Ok ()
          | Some t ->
              Result.ok_if_true
                (Consensus.Mechanism.received_at_valid_time
                   (consensus_state protocol_state)
                   ~time_received:t)
                ~error:(`Invalid "transition was received at an invalid time")
        in
        Result.ok_if_true
          ( `Take
          = Consensus.Mechanism.select ~logger
              ~existing:(consensus_state root_protocol_state)
              ~candidate:(consensus_state protocol_state) )
          ~error:
            (`Invalid
              "consensus state was not selected over transition frontier root \
               consensus state")
      in
      match synchronous_result with
      | Error err -> Deferred.return (Error err)
      | Ok () ->
          let open Deferred.Let_syntax in
          let%map valid =
            State_proof.verify
              (External_transition.protocol_state_proof transition)
              protocol_state
          in
          if valid then
            let (`I_swear_this_is_safe_don't_kill_me verified_transition) =
              External_transition.to_verified transition
            in
            Ok {hash; data= verified_transition}
          else Error (`Invalid "protocol state proof was not valid")

  let run ~logger ~frontier ~transition_reader ~valid_transition_writer =
    let logger = Logger.child logger __MODULE__ in
    don't_wait_for
      (Reader.iter transition_reader
         ~f:(fun (`Transition transition_env, `Time_received time_received) ->
           let time_received =
             Time.to_span_since_epoch time_received
             |> Time.Span.to_ms |> Unix_timestamp.of_int64
           in
           let (transition : External_transition.t) =
             Envelope.Incoming.data transition_env
           in
           let hash =
             Protocol_state.hash
               (External_transition.protocol_state transition)
           in
           let transition_with_hash = {With_hash.hash; data= transition} in
           match%map
             validate_transition ~logger ~frontier ~time_received
               transition_with_hash
           with
           | Ok valid_transition ->
               Logger.info logger
                 !"accepting transition %{sexp:State_hash.t}"
                 hash ;
               Writer.write valid_transition_writer valid_transition
           | Error `Duplicate ->
               Logger.info logger
                 !"ignoring transition we've already seen %{sexp:State_hash.t}"
                 hash
           | Error (`Invalid reason) ->
               Logger.warn logger
                 !"rejecting transitions because \"%s\" -- sent by %{sexp: \
                   Host_and_port.t}"
                 reason
                 (Envelope.Incoming.sender transition_env) ))
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
