open Async_kernel
open Core_kernel
open Pipe_lib.Strict_pipe
open Coda_base
open Cache_lib
open Protocols.Coda_transition_frontier

module Make (Inputs : Inputs.With_unprocessed_transition_cache.S) :
  Transition_handler_validator_intf
  with type time := Inputs.Time.t
   and type state_hash := State_hash.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type unprocessed_transition_cache :=
              Inputs.Unprocessed_transition_cache.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type staged_ledger := Inputs.Staged_ledger.t = struct
  open Inputs
  open Consensus

  let validate_transition ~logger ~frontier ~unprocessed_transition_cache
      transition_with_hash =
    let open With_hash in
    let open Protocol_state in
    let open Result.Let_syntax in
    let {hash; data= transition} = transition_with_hash in
    let protocol_state =
      External_transition.Verified.protocol_state transition
    in
    let root_protocol_state =
      Transition_frontier.root frontier
      |> Transition_frontier.Breadcrumb.transition_with_hash |> With_hash.data
      |> External_transition.Verified.protocol_state
    in
    let%bind () =
      Result.ok_if_true
        (Transition_frontier.find frontier hash |> Option.is_none)
        ~error:`Duplicate
    in
    let%bind () =
      Result.ok_if_true
        (not
           (Unprocessed_transition_cache.mem unprocessed_transition_cache
              transition_with_hash))
        ~error:`Duplicate
    in
    let%map () =
      Result.ok_if_true
        ( `Take
        = Consensus.select ~logger
            ~existing:(consensus_state root_protocol_state)
            ~candidate:(consensus_state protocol_state) )
        ~error:
          (`Invalid
            "consensus state was not selected over transition frontier root \
             consensus state")
    in
    (* we expect this to be Ok since we just checked the cache *)
    Unprocessed_transition_cache.register unprocessed_transition_cache
      transition_with_hash
    |> Or_error.ok_exn

  let run ~logger ~frontier ~transition_reader
      ~(valid_transition_writer :
         ( ( (External_transition.Verified.t, State_hash.t) With_hash.t
           , State_hash.t )
           Cached.t
         , drop_head buffered
         , unit )
         Writer.t) ~unprocessed_transition_cache =
    let logger = Logger.child logger __MODULE__ in
    don't_wait_for
      (Reader.iter transition_reader
         ~f:(fun (`Transition transition_env, `Time_received _) ->
           let (transition : External_transition.Verified.t) =
             Envelope.Incoming.data transition_env
           in
           let hash =
             Protocol_state.hash
               (External_transition.Verified.protocol_state transition)
           in
           let transition_with_hash = {With_hash.hash; data= transition} in
           Deferred.return
             ( match
                 validate_transition ~logger ~frontier
                   ~unprocessed_transition_cache transition_with_hash
               with
             | Ok cached_transition ->
                 Logger.info logger
                   !"accepting transition %{sexp:State_hash.t}"
                   hash ;
                 let transition_time =
                   External_transition.Verified.protocol_state transition
                   |> Protocol_state.blockchain_state
                   |> Blockchain_state.timestamp |> Block_time.to_time
                 in
                 let hist_name =
                   match Envelope.Incoming.sender transition_env with
                   | Envelope.Sender.Local ->
                       "accepted_transition_local_latency"
                   | Envelope.Sender.Remote _ ->
                       "accepted_transition_remote_latency"
                 in
                 Perf_histograms.add_span ~name:hist_name
                   (Core_kernel.Time.diff (Core_kernel.Time.now ())
                      transition_time) ;
                 Writer.write valid_transition_writer cached_transition
             | Error `Duplicate ->
                 Logger.info logger
                   !"ignoring transition we've already seen \
                     %{sexp:State_hash.t}"
                   hash
             | Error (`Invalid reason) ->
                 Logger.warn logger
                   !"rejecting transitions because \"%s\" -- sent by %{sexp: \
                     Envelope.Sender.t}"
                   reason
                   (Envelope.Incoming.sender transition_env) ) ))
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
