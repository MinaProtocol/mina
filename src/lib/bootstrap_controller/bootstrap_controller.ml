open Core
open Async
open Protocols.Coda_pow
open Coda_base
open Pipe_lib

module type Inputs_intf = sig
  module Consensus_mechanism : Consensus.Mechanism.S

  module External_transition :
    External_transition_intf
    with type protocol_state := Consensus_mechanism.Protocol_state.value

  module Merkle_address : Merkle_address.S

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Merkle_address.t
     and type hash := Ledger_hash.t
     and type root_hash := Frozen_ledger_hash.t
end

module type S = sig
  module Inputs : Inputs_intf

  open Inputs

  type t

  val create : unit -> t

  val result : t -> (Ledger.t * External_transition.t) Deferred.t
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  type get_ancestor =
       Ancestor.Input.t
    -> (Consensus_mechanism.Protocol_state.value * Ancestor.Proof.t) option
       Deferred.Or_error.t

  type state_with_root =
    { state: Consensus_mechanism.Protocol_state.value
    ; root: Consensus_mechanism.Protocol_state.value }

  type t =
    { syncable_ledger: Syncable_ledger.t
    ; root_length: int
    ; logger: Logger.t
    ; ancestor_prover: Ancestor.Prover.t
    ; mutable best_with_root: state_with_root
    ; get_ancestor: get_ancestor }

  let isn't_worth_getting_root t candidate time_received =
    match
      Consensus_mechanism.select ~logger:t.logger
        ~existing:
          (Consensus_mechanism.Protocol_state.consensus_state
             t.best_with_root.state)
        ~candidate:
          (Consensus_mechanism.Protocol_state.consensus_state candidate)
        ~time_received
    with
    | `Keep -> true
    | `Take -> false

  let received_bad_proof t e =
    (* TODO: Punish *)
    Logger.faulty_peer t.logger !"Bad ancestor proof: %{sexp:Error.t}" e

  let done_syncing_root t =
    Option.is_some (Syncable_ledger.valid_tree t.syncable_ledger)

  let on_transition t (transition, time_received) =
    let module Ps = Consensus_mechanism.Protocol_state in
    let candidate = External_transition.protocol_state transition in
    if isn't_worth_getting_root t candidate time_received then Deferred.unit
    else
      let previous_state_hash = Ps.previous_state_hash candidate in
      (* TODO: This may be an off by one *)
      let input : Ancestor.Input.t =
        {descendant= previous_state_hash; generations= t.root_length - 1}
      in
      let rec get_root () =
        let%bind res = t.get_ancestor input in
        if
          done_syncing_root t
          || isn't_worth_getting_root t candidate time_received
        then Deferred.unit
        else
          match res with
          | Error e ->
              Logger.error t.logger !"%{sexp:Error.t}" e ;
              get_root ()
          | Ok None ->
              Logger.info t.logger "Peer did not have root. Re-requesting." ;
              get_root ()
          | Ok (Some (ancestor, proof)) -> (
              let ancestor_length =
                Ps.(Consensus_state.length (consensus_state ancestor))
              in
              match
                Ancestor.Prover.verify_and_add t.ancestor_prover input
                  (Ps.hash ancestor) proof ~ancestor_length
              with
              | Ok () ->
                  t.best_with_root <- {state= candidate; root= ancestor} ;
                  let candidate_body_hash = Ps.Body.hash (Ps.body candidate) in
                  let candidate_hash =
                    Protocol_state.hash ~hash_body:Fn.id
                      {body= candidate_body_hash; previous_state_hash}
                  in
                  Ancestor.Prover.add t.ancestor_prover ~hash:candidate_hash
                    ~prev_hash:previous_state_hash
                    ~length:
                      Ps.(Consensus_state.length (consensus_state candidate))
                    ~body_hash:candidate_body_hash ;
                  Syncable_ledger.new_goal t.syncable_ledger
                    Consensus_mechanism.(
                      Protocol_state.blockchain_state ancestor
                      |> Blockchain_state.ledger_hash) ;
                  Deferred.unit
              | Error e -> received_bad_proof t e ; get_root () )
      in
      get_root ()

  let create ~parent_log ~(get_ancestor : get_ancestor) ~root_length
      ~ancestor_prover ~state ~root ~get_ancestor ledger transitions =
    let logger = Logger.child parent_log "Bootstrap_controller" in
    let t =
      { root_length
      ; get_ancestor
      ; logger
      ; ancestor_prover
      ; best_with_root= {state; root}
      ; syncable_ledger= Syncable_ledger.create ledger ~parent_log:logger }
    in
    let rec go () =
      match Syncable_ledger.valid_tree t.syncable_ledger with
      | Some tree -> return (Ok tree)
      | None -> (
          match%bind Pipe.read transitions with
          | `Eof -> return (Or_error.error_string "No more transitions")
          | `Ok transition ->
              don't_wait_for (on_transition t transition) ;
              go () )
    in
    go ()
end
