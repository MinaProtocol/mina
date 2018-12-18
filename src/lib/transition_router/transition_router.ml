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
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
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

  let create_bufferred_pipe () =
    Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))

  type tfc_transition =
    [`Transition of Inputs.External_transition.t Envelope.Incoming.t]
    * [`Time_received of Inputs.Time.t]

  type bootstrap_transition =
    [`Transition of Inputs.External_transition.t Envelope.Incoming.t]
    * [`Time_received of int64]

  type acc_pipe =
    { tfc_reader: tfc_transition Strict_pipe.Reader.t
    ; tfc_writer:
        ( tfc_transition
        , Strict_pipe.drop_head Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t
    ; bootstrap_controller_reader: bootstrap_transition Strict_pipe.Reader.t
    ; bootstrap_controller_writer:
        ( bootstrap_transition
        , Strict_pipe.drop_head Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t }

  let kill reader writer =
    Strict_pipe.Reader.clear reader ;
    Strict_pipe.Writer.close writer

  (* TODO: Wrap frontier with a Mvar #1323 *)
  let run ~logger ~network ~time_controller ~frontier ~ledger_db
      ~transition_reader =
    let start_bootstrap (`Transition incoming_transition, `Time_received tm) =
      let ancestor_prover =
        Ancestor.Prover.create ~max_size:(2 * Transition_frontier.max_length)
      in
      let bootstrap_controller_reader, bootstrap_controller_writer =
        create_bufferred_pipe ()
      in
      Strict_pipe.Writer.write bootstrap_controller_writer
        (`Transition incoming_transition, `Time_received (to_unix_timestamp tm)) ;
      let%map () =
        Bootstrap_controller.run ~parent_log:logger ~network ~ledger_db
          ~ancestor_prover ~frontier
          ~transition_reader:bootstrap_controller_reader
      in
      (bootstrap_controller_reader, bootstrap_controller_writer)
    in
    let start_tfc ~verified_transition_writer ~clear_reader =
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
    let tfc_reader, tfc_writer =
      start_tfc ~verified_transition_writer ~clear_reader
    in
    let bootstrap_controller_reader, bootstrap_controller_writer =
      create_bufferred_pipe ()
    in
    let init =
      { tfc_reader
      ; tfc_writer
      ; bootstrap_controller_reader
      ; bootstrap_controller_writer }
    in
    Strict_pipe.Reader.fold transition_reader ~init
      ~f:(fun pipe_acc network_transition ->
        let is_bootstrapping () =
          Strict_pipe.Writer.is_closed pipe_acc.bootstrap_controller_writer
        in
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
          if not @@ is_bootstrapping () then (
            kill pipe_acc.tfc_reader pipe_acc.tfc_writer ;
            Strict_pipe.Writer.write clear_writer `Clear |> don't_wait_for ;
            let%map bootstrap_controller_reader, bootstrap_controller_writer =
              start_bootstrap network_transition
            in
            kill pipe_acc.bootstrap_controller_reader
              pipe_acc.bootstrap_controller_writer ;
            let tfc_reader, tfc_writer =
              start_tfc ~verified_transition_writer ~clear_reader
            in
            { tfc_reader
            ; tfc_writer
            ; bootstrap_controller_reader
            ; bootstrap_controller_writer } )
          else (
            Strict_pipe.Writer.write bootstrap_controller_writer
              ( `Transition incoming_transition
              , `Time_received (to_unix_timestamp tm) ) ;
            Deferred.return pipe_acc )
        else (
          if not @@ is_bootstrapping () then
            Strict_pipe.Writer.write tfc_writer network_transition ;
          Deferred.return pipe_acc ) )
    |> Deferred.ignore |> don't_wait_for ;
    verified_transition_reader
end
