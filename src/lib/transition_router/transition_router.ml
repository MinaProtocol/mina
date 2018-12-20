open Core_kernel
open Async_kernel
open Coda_base
open Protocols.Coda_pow
open Pipe_lib
open Protocols.Coda_transition_frontier

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Time : Time_intf

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type ledger_database := Ledger.Db.t
     and type staged_ledger := Staged_ledger.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type masked_ledger := Coda_base.Ledger.t

  module Network :
    Network_intf
    with type peer := Kademlia.Peer.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type ancestor_proof_input := State_hash.t * int
     and type ancestor_proof := Ancestor.Proof.t
     and type protocol_state := External_transition.Protocol_state.value

  module Transition_frontier_controller :
    Transition_frontier_controller_intf
    with type time_controller := Time.Controller.t
     and type external_transition_verified := External_transition.Verified.t
     and type transition_frontier := Transition_frontier.t
     and type time := Time.t
     and type state_hash := State_hash.t
     and type network := Network.t

  module Bootstrap_controller :
    Bootstrap_controller_intf
    with type network := Network.t
     and type transition_frontier := Transition_frontier.t
     and type external_transition_verified := External_transition.Verified.t
     and type ancestor_prover := Ancestor.Prover.t
     and type ledger_db := Ledger.Db.t

  module State_proof :
    Proof_intf
    with type input := Consensus.Mechanism.Protocol_state.value
     and type t := Proof.t

  module Protocol_state_validator :
    Protocol_state_validator_intf
    with type time := Time.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type external_transition_verified := External_transition.Verified.t
end

module Make (Inputs : Inputs_intf) :
  Transition_router_intf
  with type time_controller := Inputs.Time.Controller.t
   and type external_transition := Inputs.External_transition.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type time := Inputs.Time.t
   and type state_hash := State_hash.t
   and type network := Inputs.Network.t
   and type ledger_db := Ledger.Db.t = struct
  open Inputs
  module Initial_validator = Initial_validator.Make (Inputs)

  (* HACK: Bootstrap accepts unix_timestamp rather than Time.t *)
  let to_unix_timestamp recieved_time =
    recieved_time |> Time.to_span_since_epoch |> Time.Span.to_ms
    |> Unix_timestamp.of_int64

  let create_bufferred_pipe () =
    Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))

  let kill reader writer =
    Strict_pipe.Reader.clear reader ;
    Strict_pipe.Writer.close writer

  let is_transition_for_bootstrap ~frontier new_transition =
    let root_transition =
      Transition_frontier.root frontier
      |> Transition_frontier.Breadcrumb.transition_with_hash |> With_hash.data
    in
    let open External_transition.Verified in
    let root_state = protocol_state root_transition in
    let new_state = protocol_state new_transition in
    Consensus.Mechanism.should_bootstrap
      ~existing:(External_transition.Protocol_state.consensus_state root_state)
      ~candidate:(External_transition.Protocol_state.consensus_state new_state)

  let is_bootstrapping mode =
    match mode with
    | `Bootstrap_controller _ -> true
    | `Transition_frontier_controller (_, _) -> false

  (* TODO: Wrap frontier with a Mvar #1323 *)
  let run ~logger ~network ~time_controller ~frontier ~ledger_db
      ~transition_reader =
    let clean_transition_frontier_controller_and_start_bootstrap ~mode
        ~clear_writer ~transition_frontier_controller_reader
        ~transition_frontier_controller_writer
        (`Transition incoming_transition, `Time_received tm) =
      kill transition_frontier_controller_reader
        transition_frontier_controller_writer ;
      Strict_pipe.Writer.write clear_writer `Clear |> don't_wait_for ;
      let bootstrap_controller_reader, bootstrap_controller_writer =
        create_bufferred_pipe ()
      in
      assert (not @@ is_bootstrapping !mode) ;
      mode := `Bootstrap_controller bootstrap_controller_writer ;
      let ancestor_prover =
        Ancestor.Prover.create ~max_size:(2 * Transition_frontier.max_length)
      in
      Strict_pipe.Writer.write bootstrap_controller_writer
        (`Transition incoming_transition, `Time_received (to_unix_timestamp tm)) ;
      let%map () =
        Bootstrap_controller.run ~parent_log:logger ~network ~ledger_db
          ~ancestor_prover ~frontier
          ~transition_reader:bootstrap_controller_reader
      in
      kill bootstrap_controller_reader bootstrap_controller_writer
    in
    let start_transition_frontier_controller ~verified_transition_writer
        ~clear_reader =
      let transition_reader, transition_writer = create_bufferred_pipe () in
      let new_verified_transition_reader =
        Transition_frontier_controller.run ~logger ~network ~time_controller
          ~frontier ~transition_reader ~clear_reader
      in
      Strict_pipe.Reader.iter new_verified_transition_reader
        ~f:
          (Fn.compose Deferred.return
             (Strict_pipe.Writer.write verified_transition_writer))
      |> don't_wait_for ;
      (transition_reader, transition_writer)
    in
    let clear_reader, clear_writer = Strict_pipe.create Synchronous in
    let verified_transition_reader, verified_transition_writer =
      create_bufferred_pipe ()
    in
    let mode =
      ref
      @@ `Transition_frontier_controller
           (start_transition_frontier_controller ~verified_transition_writer
              ~clear_reader)
    in
    let ( valid_protocol_state_transition_reader
        , valid_protocol_state_transition_writer ) =
      create_bufferred_pipe ()
    in
    Initial_validator.run ~logger ~transition_reader
      ~valid_transition_writer:valid_protocol_state_transition_writer ;
    Strict_pipe.Reader.iter valid_protocol_state_transition_reader
      ~f:(fun network_transition ->
        let `Transition incoming_transition, `Time_received tm =
          network_transition
        in
        let new_transition = Envelope.Incoming.data incoming_transition in
        match !mode with
        | `Transition_frontier_controller
            ( transition_frontier_controller_reader
            , transition_frontier_controller_writer ) ->
            if is_transition_for_bootstrap ~frontier new_transition then (
              let%map () =
                clean_transition_frontier_controller_and_start_bootstrap ~mode
                  ~clear_writer ~transition_frontier_controller_reader
                  ~transition_frontier_controller_writer network_transition
              in
              assert (is_bootstrapping !mode) ;
              mode :=
                `Transition_frontier_controller
                  (start_transition_frontier_controller
                     ~verified_transition_writer ~clear_reader) )
            else (
              Strict_pipe.Writer.write transition_frontier_controller_writer
                network_transition ;
              Deferred.unit )
        | `Bootstrap_controller bootstrap_controller_writer ->
            if is_transition_for_bootstrap ~frontier new_transition then
              Strict_pipe.Writer.write bootstrap_controller_writer
                ( `Transition incoming_transition
                , `Time_received (to_unix_timestamp tm) ) ;
            Deferred.unit )
    |> don't_wait_for ;
    verified_transition_reader
end
