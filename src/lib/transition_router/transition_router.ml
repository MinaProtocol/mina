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
     and type consensus_local_state := Consensus.Local_state.t
     and type user_command := User_command.t

  module Network :
    Network_intf
    with type peer := Network_peer.Peer.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type consensus_state := Consensus.Consensus_state.value
     and type state_body_hash := State_body_hash.t
     and type ledger_hash := Ledger_hash.t
     and type sync_ledger_query := Sync_ledger.query
     and type sync_ledger_answer := Sync_ledger.answer

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
     and type ledger_db := Ledger.Db.t

  module State_proof :
    Proof_intf
    with type input := Consensus.Protocol_state.value
     and type t := Proof.t

  module Protocol_state_validator :
    Protocol_state_validator_intf
    with type time := Time.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type external_transition_proof_verified :=
                External_transition.Proof_verified.t
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

  let is_transition_for_bootstrap root_state new_transition =
    let open External_transition.Verified in
    let new_state = protocol_state new_transition in
    Consensus.should_bootstrap
      ~existing:(External_transition.Protocol_state.consensus_state root_state)
      ~candidate:(External_transition.Protocol_state.consensus_state new_state)

  let is_bootstrapping = function
    | `Bootstrap_controller (_, _) -> true
    | `Transition_frontier_controller (_, _, _) -> false

  let get_root_state frontier =
    Transition_frontier.root frontier
    |> Transition_frontier.Breadcrumb.transition_with_hash |> With_hash.data
    |> External_transition.of_verified |> External_transition.protocol_state

  module Broadcaster = struct
    type 'a t = {mutable var: 'a; f: 'a -> unit}

    let create ~init ~f = {var= init; f}

    let broadcast t value =
      t.var <- value ;
      t.f value

    let get {var; _} = var
  end

  let set_bootstrap_phase ~controller_type root_state
      bootstrap_controller_writer =
    assert (not @@ is_bootstrapping (Broadcaster.get controller_type)) ;
    Broadcaster.broadcast controller_type
      (`Bootstrap_controller (root_state, bootstrap_controller_writer))

  let set_transition_frontier_controller_phase ~controller_type new_frontier
      reader writer =
    assert (not @@ is_bootstrapping (Broadcaster.get controller_type)) ;
    Broadcaster.broadcast controller_type
      (`Transition_frontier_controller (new_frontier, reader, writer))

  let peek_exn p = Broadcast_pipe.Reader.peek p |> Option.value_exn

  let run ~logger ~network ~time_controller
      ~frontier_broadcast_pipe:(frontier_r, frontier_w) ~ledger_db
      ~network_transition_reader ~proposer_transition_reader =
    let clean_transition_frontier_controller_and_start_bootstrap
        ~controller_type ~clear_writer ~transition_frontier_controller_reader
        ~transition_frontier_controller_writer ~old_frontier
        (`Transition _incoming_transition, `Time_received _tm) =
      kill transition_frontier_controller_reader
        transition_frontier_controller_writer ;
      Strict_pipe.Writer.write clear_writer `Clear |> don't_wait_for ;
      let bootstrap_controller_reader, bootstrap_controller_writer =
        Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))
      in
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "Starting Bootstrapping phase" ;
      let root_state = get_root_state old_frontier in
      set_bootstrap_phase ~controller_type root_state
        bootstrap_controller_writer ;
      Strict_pipe.Writer.write bootstrap_controller_writer
        ( `Transition _incoming_transition
        , `Time_received (to_unix_timestamp _tm) ) ;
      let%map new_frontier, collected_transitions =
        Bootstrap_controller.run ~logger ~network ~ledger_db
          ~frontier:old_frontier ~transition_reader:bootstrap_controller_reader
      in
      kill bootstrap_controller_reader bootstrap_controller_writer ;
      ( new_frontier
      , List.map collected_transitions
          ~f:
            (With_hash.of_data
               ~hash_data:
                 (Fn.compose Consensus.Protocol_state.hash
                    External_transition.Verified.protocol_state)) )
    in
    let start_transition_frontier_controller ~verified_transition_writer
        ~clear_reader ~collected_transitions frontier =
      let transition_reader, transition_writer = create_bufferred_pipe () in
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "Starting Transition Frontier Controller phase" ;
      let new_verified_transition_reader =
        Transition_frontier_controller.run ~logger ~network ~time_controller
          ~collected_transitions ~frontier
          ~network_transition_reader:transition_reader
          ~proposer_transition_reader ~clear_reader
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
    let ( transition_frontier_controller_reader
        , transition_frontier_controller_writer ) =
      start_transition_frontier_controller ~verified_transition_writer
        ~clear_reader ~collected_transitions:[] (peek_exn frontier_r)
    in
    let controller_type =
      Broadcaster.create
        ~init:
          (`Transition_frontier_controller
            ( peek_exn frontier_r
            , transition_frontier_controller_reader
            , transition_frontier_controller_writer ))
        ~f:(function
          | `Transition_frontier_controller (frontier, _, _) ->
              don't_wait_for
                (Broadcast_pipe.Writer.write frontier_w (Some frontier))
          | `Bootstrap_controller (_, _) ->
              Transition_frontier.close (peek_exn frontier_r) ;
              don't_wait_for (Broadcast_pipe.Writer.write frontier_w None))
    in
    let ( valid_protocol_state_transition_reader
        , valid_protocol_state_transition_writer ) =
      create_bufferred_pipe ()
    in
    Initial_validator.run ~logger ~transition_reader:network_transition_reader
      ~valid_transition_writer:valid_protocol_state_transition_writer ;
    Strict_pipe.Reader.iter valid_protocol_state_transition_reader
      ~f:(fun network_transition ->
        let `Transition incoming_transition, `Time_received tm =
          network_transition
        in
        let new_transition = Envelope.Incoming.data incoming_transition in
        match Broadcaster.get controller_type with
        | `Transition_frontier_controller
            ( frontier
            , transition_frontier_controller_reader
            , transition_frontier_controller_writer ) ->
            let root_state = get_root_state frontier in
            if is_transition_for_bootstrap root_state new_transition then
              let%map new_frontier, collected_transitions =
                clean_transition_frontier_controller_and_start_bootstrap
                  ~controller_type ~clear_writer
                  ~transition_frontier_controller_reader
                  ~transition_frontier_controller_writer ~old_frontier:frontier
                  network_transition
              in
              let reader, writer =
                start_transition_frontier_controller
                  ~verified_transition_writer ~clear_reader
                  ~collected_transitions new_frontier
              in
              set_transition_frontier_controller_phase ~controller_type
                new_frontier reader writer
            else (
              Strict_pipe.Writer.write transition_frontier_controller_writer
                network_transition ;
              Deferred.unit )
        | `Bootstrap_controller (root_state, bootstrap_controller_writer) ->
            if is_transition_for_bootstrap root_state new_transition then
              Strict_pipe.Writer.write bootstrap_controller_writer
                ( `Transition incoming_transition
                , `Time_received (to_unix_timestamp tm) ) ;
            Deferred.unit )
    |> don't_wait_for ;
    verified_transition_reader
end
