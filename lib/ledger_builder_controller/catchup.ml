open Core_kernel
open Async_kernel

module type Inputs_intf = sig
  module Ledger_hash : sig
    type t [@@deriving sexp]
  end

  module Ledger : sig
    type t

    val copy : t -> t

    val merkle_root : t -> Ledger_hash.t
  end

  module Ledger_builder_hash : sig
    type t [@@deriving eq, sexp]

    val ledger_hash : t -> Ledger_hash.t
  end

  module Ledger_builder_aux_hash : sig
    type t [@@deriving sexp]
  end

  module Ledger_builder : sig
    type t [@@deriving bin_io]

    type proof

    module Aux : sig
      type t [@@deriving bin_io]

      val hash : t -> Ledger_builder_aux_hash.t
    end

    val ledger : t -> Ledger.t

    val hash : t -> Ledger_builder_hash.t

    val of_aux_and_ledger :
         snarked_ledger_hash:Ledger_hash.t
      -> ledger:Ledger.t
      -> aux:Aux.t
      -> t Or_error.t

    val copy : t -> t
  end

  module Protocol_state_proof : sig
    type t
  end

  module Protocol_state : sig
    type value
  end

  module External_transition : sig
    type t [@@deriving bin_io, eq, compare, sexp]

    val target_state : t -> Protocol_state.value

    val ledger_hash : t -> Ledger_hash.t

    val ledger_builder_hash : t -> Ledger_builder_hash.t
  end

  module Tip :
    Protocols.Coda_pow.Tip_intf
    with type ledger_builder := Ledger_builder.t
     and type protocol_state := Protocol_state.value
     and type protocol_state_proof := Protocol_state_proof.t
     and type external_transition := External_transition.t

  module Transition_logic_state :
    Transition_logic_state.S
    with type tip := Tip.t
     and type external_transition := External_transition.t

  module Sync_ledger : sig
    type t

    type answer [@@deriving bin_io]

    type query [@@deriving bin_io]

    val create : Ledger.t -> t

    val answer_writer : t -> (Ledger_hash.t * answer) Linear_pipe.Writer.t

    val query_reader : t -> (Ledger_hash.t * query) Linear_pipe.Reader.t

    val destroy : t -> unit

    val fetch :
      t -> Ledger_hash.t -> [`Ok of Ledger.t | `Target_changed] Deferred.t
  end

  module Net : sig
    include Coda.Ledger_builder_io_intf
            with type sync_ledger_query := Sync_ledger.query
             and type sync_ledger_answer := Sync_ledger.answer
             and type ledger_builder_hash := Ledger_builder_hash.t
             and type ledger_builder_aux := Ledger_builder.Aux.t
             and type ledger_hash := Ledger_hash.t
             and type protocol_state := Protocol_state.value
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  type t = {net: Net.t; log: Logger.t; sl_ref: Sync_ledger.t option ref}

  let create net parent_log =
    {net; log= Logger.child parent_log __MODULE__; sl_ref= ref None}

  (* Perform the `Sync interruptible work *)
  let do_sync {net; log; sl_ref} (state: Transition_logic_state.t) transition =
    let locked_tip = Transition_logic_state.locked_tip state in
    let snarked_ledger_hash = External_transition.ledger_hash transition in
    let h =
      External_transition.ledger_builder_hash transition
      |> Ledger_builder_hash.ledger_hash
    in
    (* Lazily recreate the sync_ledger if necessary *)
    let sl : Sync_ledger.t =
      match !sl_ref with
      | None ->
          let ledger =
            Ledger_builder.ledger locked_tip.ledger_builder |> Ledger.copy
          in
          let sl = Sync_ledger.create ledger in
          Net.glue_sync_ledger net
            (Sync_ledger.query_reader sl)
            (Sync_ledger.answer_writer sl) ;
          sl_ref := Some sl ;
          sl
      | Some sl -> sl
    in
    let open Interruptible.Let_syntax in
    let ivar : External_transition.t Ivar.t = Ivar.create () in
    let work =
      match%bind
        Interruptible.lift (Sync_ledger.fetch sl h)
          (Deferred.map (Ivar.read ivar) ~f:ignore)
      with
      | `Ok ledger -> (
          (* TODO: This should be parallelized with the syncing *)
          match%map
            Interruptible.uninterruptible
              (Net.get_ledger_builder_aux_at_hash net
                 (External_transition.ledger_builder_hash transition))
          with
          | Ok aux -> (
            match
              Ledger_builder.of_aux_and_ledger ~snarked_ledger_hash ~ledger
                ~aux
            with
            (* TODO: We'll need the full history in order to trust that
               the ledger builder we get is actually valid. See #285 *)
            | Ok lb ->
                sl_ref := None ;
                let new_tree =
                  Transition_logic_state.Transition_tree.singleton transition
                in
                let new_tip = Tip.of_transition_and_lb transition lb in
                let open Transition_logic_state.Change in
                [Ktree new_tree; Locked_tip new_tip; Longest_branch_tip new_tip]
            | Error e ->
                Logger.warn log "Malicious aux data received from net %s"
                  (Error.to_string_hum e) ;
                (* TODO: Retry? see #361 *)
                [] )
          | Error e ->
              Logger.warn log "Network failed to send aux %s"
                (Error.to_string_hum e) ;
              [] )
      | `Target_changed -> return []
    in
    (work, ivar)

  let sync (t: t) (state: Transition_logic_state.t) transition =
    (transition, do_sync t state)
end
