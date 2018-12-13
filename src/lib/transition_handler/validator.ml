open Async_kernel
open Core_kernel
open Pipe_lib.Strict_pipe
open Coda_base

module Make (Inputs : Inputs.S) = struct
  open Inputs
  open Consensus.Mechanism
  open Deferred.Let_syntax

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
    let ( || ) a b =
      match (a, b) with
      | _, `Duplicate -> `Duplicate
      | `Duplicate, _ -> `Duplicate
      | `Valid, _ -> `Valid
      | _, `Valid -> `Valid
      | `Reject, `Reject -> `Reject
    in
    let of_bool = function true -> `Valid | false -> `Reject in
    let t = Envelope.Incoming.data t_env in
    let time_received =
      Time.to_span_since_epoch time_received
      |> Time.Span.to_ms |> Unix_timestamp.of_int64
    in
    let log_assert condition error_msg =
      let log () =
        Logger.info logger "transition rejected: %s" error_msg ;
        `Reject
      in
      of_bool condition || log ()
    in
    let consensus_state =
      Fn.compose Protocol_state.consensus_state
        External_transition.protocol_state
    in
    let root =
      With_hash.data
        (Transition_frontier.Breadcrumb.transition_with_hash
           (Transition_frontier.root frontier))
    in
    let psh = Protocol_state.hash (External_transition.protocol_state t) in
    if Transition_frontier.find frontier psh |> Option.is_some then (
      Logger.info logger
        !"we've already seen protocol state %{sexp:State_hash.t}"
        psh ;
      Deferred.return `Duplicate )
    else
      match
        log_assert
          (Consensus.Mechanism.is_valid (consensus_state t) ~time_received)
          "failed consensus validation"
        && log_assert
             ( Consensus.Mechanism.select ~logger
                 ~existing:(consensus_state root)
                 ~candidate:(consensus_state t) ~time_received
             = `Take )
             "was not better than transition frontier root"
      with
      | `Valid ->
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
          let%map proof_is_valid =
            State_proof.verify
              (External_transition.protocol_state_proof t)
              (External_transition.protocol_state t)
          in
          log_assert proof_is_valid "proof was invalid"
      | x -> return x

  let run ~logger ~frontier ~transition_reader ~valid_transition_writer =
    let logger = Logger.child logger "transition_handler_validator" in
    don't_wait_for
      (Reader.iter transition_reader
         ~f:(fun (`Transition transition_env, `Time_received time_received) ->
           let transition = Envelope.Incoming.data transition_env in
           match%map
             validate_transition ~logger ~frontier ~time_received
               transition_env
           with
           | `Valid ->
               Writer.write valid_transition_writer
                 (With_hash.of_data transition
                    ~hash_data:
                      (Fn.compose Protocol_state.hash
                         External_transition.protocol_state))
           | `Duplicate -> ()
           | `Reject ->
               Logger.warn logger
                 !"failed to verify transition from the network! sent by \
                   %{sexp: Host_and_port.t}"
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
