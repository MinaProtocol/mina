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
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type ledger_diff_verified := Staged_ledger_diff.Verified.t
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
     and type external_transition := External_transition.t
     and type external_transition_verified := External_transition.Verified.t
     and type transition_frontier := Transition_frontier.t
     and type time := Time.t
     and type state_hash := State_hash.t
     and type network := Network.t

  module Bootstrap_controller :
    Bootstrap_controller_intf
    with type network := Network.t
     and type transition_frontier := Transition_frontier.t
     and type external_transition := External_transition.t
     and type ancestor_prover := Ancestor.Prover.t
     and type ledger_db := Ledger.Db.t
end

module Make (Inputs : Inputs_intf) :
  Transition_router_intf
  with type time_controller := Inputs.Time.Controller.t
   and type external_transition := Inputs.External_transition.t
   and type external_transition_verified := Inputs.External_transition.Verified.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type time := Inputs.Time.t
   and type state_hash := State_hash.t
   and type network := Inputs.Network.t
   and type ledger_db := Ledger.Db.t = struct
  open Inputs

  (* HACK: Bootstrap accepts unix_timestamp rather than Time.t *)
  let to_unix_timestamp recieved_time =
    recieved_time |> Time.to_span_since_epoch |> Time.Span.to_ms
    |> Unix_timestamp.of_int64

  let run ~logger ~network ~time_controller ~frontier ~ledger_db
      ~transition_reader =
    let clear_reader, clear_writer = Strict_pipe.create Synchronous in
    let tfc_reader, tfc_writer =
      Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))
    in
    let bootstrap_controller_reader, bootstrap_controller_writer =
      Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))
    in
    let is_bootstrapping = ref false in
    let ancestor_prover =
      Ancestor.Prover.create ~max_size:(2 * Transition_frontier.max_length)
    in
    let start_bootstrap (`Transition incoming_transition, `Time_received tm) =
      Strict_pipe.Writer.write clear_writer `Clear |> don't_wait_for ;
      is_bootstrapping := true ;
      Strict_pipe.Writer.write bootstrap_controller_writer
        (`Transition incoming_transition, `Time_received (to_unix_timestamp tm)) ;
      let%map () =
        Bootstrap_controller.run ~parent_log:logger ~network ~ledger_db
          ~ancestor_prover ~frontier
          ~transition_reader:bootstrap_controller_reader
      in
      is_bootstrapping := false
    in
    Strict_pipe.Reader.iter transition_reader ~f:(fun network_transition ->
        let `Transition incoming_transition, `Time_received tm =
          network_transition
        in
        let new_transition = Envelope.Incoming.data incoming_transition in
        let root_transition =
          Transition_frontier.root frontier
          |> Transition_frontier.Breadcrumb.transition_with_hash
          |> With_hash.data
        in
        let open External_transition in
        let root_state = protocol_state (root_transition |> forget) in
        let new_state = protocol_state new_transition in
        if
          Consensus.Mechanism.should_bootstrap
            ~max_length:Transition_frontier.max_length
            ~existing:(Protocol_state.consensus_state root_state)
            ~candidate:(Protocol_state.consensus_state new_state)
        then
          if not !is_bootstrapping then start_bootstrap network_transition
          else Deferred.unit
        else
          Deferred.return
            ( if not !is_bootstrapping then
              Strict_pipe.Writer.write tfc_writer network_transition
            else
              Strict_pipe.Writer.write bootstrap_controller_writer
                ( `Transition incoming_transition
                , `Time_received (to_unix_timestamp tm) ) ) )
    |> don't_wait_for ;
    Transition_frontier_controller.run ~logger ~network ~time_controller
      ~frontier ~transition_reader:tfc_reader ~clear_reader
end
