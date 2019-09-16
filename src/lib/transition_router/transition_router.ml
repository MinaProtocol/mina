open Core_kernel
open Async_kernel
open Coda_state
open Pipe_lib

module type Inputs_intf = sig
  include Coda_intf.Inputs_intf

  module Network : sig
    type t
  end

  module Transition_frontier :
    Coda_intf.Transition_frontier_intf
    with type external_transition_validated := External_transition.Validated.t
     and type mostly_validated_external_transition :=
                ( [`Time_received] * Truth.true_t
                , [`Proof] * Truth.true_t
                , [`Frontier_dependencies] * Truth.true_t
                , [`Staged_ledger_diff] * Truth.false_t )
                External_transition.Validation.with_transition
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t
     and type 'a transaction_snark_work_statement_table :=
       'a Transaction_snark_work.Statement.Table.t

  module Transition_frontier_controller :
    Coda_intf.Transition_frontier_controller_intf
    with type external_transition_validated := External_transition.Validated.t
     and type external_transition_with_initial_validation :=
                External_transition.with_initial_validation
     and type transition_frontier := Transition_frontier.t
     and type breadcrumb := Transition_frontier.Breadcrumb.t
     and type network := Network.t
     and type verifier := Verifier.t

  module Bootstrap_controller :
    Coda_intf.Bootstrap_controller_intf
    with type network := Network.t
     and type verifier := Verifier.t
     and type transition_frontier := Transition_frontier.t
     and type external_transition_with_initial_validation :=
                External_transition.with_initial_validation
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Initial_validator = Initial_validator.Make (Inputs)

  let create_bufferred_pipe ?name () =
    Strict_pipe.create ?name (Buffered (`Capacity 50, `Overflow Crash))

  let is_transition_for_bootstrap root_state new_transition =
    let open External_transition in
    let new_state = protocol_state new_transition in
    Consensus.Hooks.should_bootstrap
      ~existing:(Protocol_state.consensus_state root_state)
      ~candidate:(Protocol_state.consensus_state new_state)

  let is_bootstrapping = function
    | `Bootstrap_controller (_, _) ->
        true
    | `Transition_frontier_controller (_, _, _) ->
        false

  let get_root_state frontier =
    Transition_frontier.root frontier
    |> Transition_frontier.Breadcrumb.transition_with_hash |> With_hash.data
    |> External_transition.Validated.protocol_state

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
    assert (is_bootstrapping (Broadcaster.get controller_type)) ;
    Broadcaster.broadcast controller_type
      (`Transition_frontier_controller (new_frontier, reader, writer))

  let peek_exn p = Broadcast_pipe.Reader.peek p |> Option.value_exn

  let run ~logger ~trust_system ~verifier ~network ~time_controller
      ~consensus_local_state
      ~frontier_broadcast_pipe:(frontier_r, frontier_w)
      ~network_transition_reader ~proposer_transition_reader =
    let start_transition_frontier_controller ~verified_transition_writer
        ~clear_reader ~collected_transitions frontier =
      let transition_reader, transition_writer =
        create_bufferred_pipe ~name:"network transitions" ()
      in
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "Starting Transition Frontier Controller phase" ;
      let new_verified_transition_reader =
        Transition_frontier_controller.run ~logger ~trust_system ~verifier
          ~network ~time_controller ~collected_transitions ~frontier
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
    let clean_transition_frontier_controller_and_start_bootstrap
        ~controller_type ~clear_reader ~clear_writer
        ~transition_frontier_controller_writer ~old_frontier
        ~verified_transition_writer
        (`Transition _incoming_transition, `Time_received tm) =
      Strict_pipe.Writer.kill transition_frontier_controller_writer ;
      Strict_pipe.Writer.write clear_writer `Clear |> don't_wait_for ;
      let bootstrap_controller_reader, bootstrap_controller_writer =
        Strict_pipe.create ~name:"bootstrap controller"
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "Bootstrap state: starting." ;
      let root_state = get_root_state old_frontier in
      set_bootstrap_phase ~controller_type root_state
        bootstrap_controller_writer ;
      Strict_pipe.Writer.write bootstrap_controller_writer
        (`Transition _incoming_transition, `Time_received tm) ;
      upon
        (Bootstrap_controller.run ~logger ~trust_system ~verifier ~network
           ~frontier:old_frontier
           ~consensus_local_state
           ~transition_reader:bootstrap_controller_reader)
        (fun (new_frontier, collected_transitions) ->
          Strict_pipe.Writer.kill bootstrap_controller_writer ;
          let reader, writer =
            start_transition_frontier_controller ~verified_transition_writer
              ~clear_reader ~collected_transitions new_frontier
          in
          set_transition_frontier_controller_phase ~controller_type
            new_frontier reader writer )
    in
    let clear_reader, clear_writer =
      Strict_pipe.create ~name:"clear" Synchronous
    in
    let verified_transition_reader, verified_transition_writer =
      create_bufferred_pipe ~name:"verified transitions" ()
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
        ~f:(fun state ->
          don't_wait_for (
            match state with
            | `Transition_frontier_controller (frontier, _, _) ->
                Broadcast_pipe.Writer.write frontier_w (Some frontier)
            | `Bootstrap_controller (_, _) ->
                Broadcast_pipe.Writer.write frontier_w None ))
    in
    let ( valid_protocol_state_transition_reader
        , valid_protocol_state_transition_writer ) =
      create_bufferred_pipe ~name:"valid transitions" ()
    in
    Initial_validator.run ~logger ~trust_system ~verifier
      ~transition_reader:network_transition_reader
      ~valid_transition_writer:valid_protocol_state_transition_writer ;
    Strict_pipe.Reader.iter_without_pushback
      valid_protocol_state_transition_reader ~f:(fun valid_transition ->
        let `Transition incoming_transition, _ = valid_transition in
        let new_transition_with_validation =
          Envelope.Incoming.data incoming_transition
        in
        let {With_hash.data= new_transition; _}, _ =
          new_transition_with_validation
        in
        match Broadcaster.get controller_type with
        | `Transition_frontier_controller
            (frontier, _, transition_frontier_controller_writer) ->
            let root_state = get_root_state frontier in
            if is_transition_for_bootstrap root_state new_transition then
              clean_transition_frontier_controller_and_start_bootstrap
                ~controller_type ~clear_reader ~clear_writer
                ~transition_frontier_controller_writer ~old_frontier:frontier
                ~verified_transition_writer valid_transition
            else
              Strict_pipe.Writer.write transition_frontier_controller_writer
                valid_transition
        | `Bootstrap_controller (root_state, bootstrap_controller_writer) ->
            if is_transition_for_bootstrap root_state new_transition then
              Strict_pipe.Writer.write bootstrap_controller_writer
                valid_transition )
    |> don't_wait_for ;
    verified_transition_reader
end
