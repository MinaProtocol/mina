open Core
open Async

module type Inputs_intf = sig
  include Protocols.Coda_pow.Inputs_intf

  module Prover : sig
    val prove :
         prev_state:Consensus_mechanism.Protocol_state.value
      -> prev_state_proof:Protocol_state_proof.t
      -> next_state:Consensus_mechanism.Protocol_state.value
      -> Consensus_mechanism.Internal_transition.t
      -> Protocol_state_proof.t Deferred.Or_error.t
  end
end

module Agent : sig
  type 'a t

  val create : f:('a -> 'b) -> 'a Linear_pipe.Reader.t -> 'b t

  val get : 'a t -> 'a option

  val with_value : f:('a -> unit) -> 'a t -> unit
end = struct
  type 'a t = {signal: unit Ivar.t; mutable value: 'a option}

  let create ~(f : 'a -> 'b) (reader : 'a Linear_pipe.Reader.t) : 'b t =
    let t = {signal= Ivar.create (); value= None} in
    don't_wait_for
      (Linear_pipe.iter reader ~f:(fun x ->
           let old_value = t.value in
           t.value <- Some (f x) ;
           if old_value = None then Ivar.fill t.signal () ;
           return () )) ;
    t

  let get t = t.value

  let rec with_value ~f t =
    match t.value with
    | Some x -> f x
    | None -> don't_wait_for (Ivar.read t.signal >>| fun () -> with_value ~f t)
end

module Singleton_supervisor : sig
  type 'a t

  val create : task:(unit Ivar.t -> ('a, unit) Interruptible.t) -> 'a t

  val cancel : 'a t -> unit

  val dispatch : 'a t -> ('a, unit) Interruptible.t
end = struct
  type 'a t =
    { mutable task: (unit Ivar.t * ('a, unit) Interruptible.t) option
    ; f: unit Ivar.t -> ('a, unit) Interruptible.t }

  let create ~task = {task= None; f= task}

  let cancel t =
    match t.task with
    | Some (ivar, _) ->
        Ivar.fill ivar () ;
        t.task <- None
    | None -> ()

  let dispatch t =
    cancel t ;
    let ivar = Ivar.create () in
    let interruptible =
      let open Interruptible.Let_syntax in
      t.f ivar
      >>| fun x ->
      t.task <- None ;
      x
    in
    t.task <- Some (ivar, interruptible) ;
    interruptible
end

module Make (Inputs : Inputs_intf) :
  Coda_lib.Proposer_intf
  with type external_transition :=
              Inputs.Consensus_mechanism.External_transition.t
   and type ledger_hash := Inputs.Ledger_hash.t
   and type ledger_builder := Inputs.Ledger_builder.t
   and type transaction := Inputs.Transaction.With_valid_signature.t
   and type protocol_state := Inputs.Consensus_mechanism.Protocol_state.value
   and type protocol_state_proof := Inputs.Protocol_state_proof.t
   and type consensus_local_state := Inputs.Consensus_mechanism.Local_state.t
   and type completed_work_statement := Inputs.Completed_work.Statement.t
   and type completed_work_checked := Inputs.Completed_work.Checked.t
   and type time_controller := Inputs.Time.Controller.t
   and type keypair := Inputs.Keypair.t = struct
  open Inputs
  open Consensus_mechanism

  let time_to_ms = Fn.compose Time.Span.to_ms Time.to_span_since_epoch

  let time_of_ms = Fn.compose Time.of_span_since_epoch Time.Span.of_ms

  let lift_sync f =
    Interruptible.uninterruptible
      (Deferred.create (fun ivar -> Ivar.fill ivar (f ())))

  module Singleton_scheduler : sig
    type t

    val create : Time.Controller.t -> t

    val schedule : t -> Time.t -> f:(unit -> unit) -> unit
  end = struct
    type t =
      { mutable timeout: unit Time.Timeout.t option
      ; time_controller: Time.Controller.t }

    let create time_controller = {time_controller; timeout= None}

    let cancel t =
      match t.timeout with
      | Some timeout ->
          Time.Timeout.cancel t.time_controller timeout () ;
          t.timeout <- None
      | None -> ()

    let schedule t time ~f =
      cancel t ;
      let span_till_time = Time.diff time (Time.now t.time_controller) in
      let timeout =
        Time.Timeout.create t.time_controller span_till_time ~f:(fun _ ->
            t.timeout <- None ;
            f () )
      in
      t.timeout <- Some timeout
  end

  let generate_next_state ~previous_protocol_state ~consensus_local_state
      ~time_controller ~ledger_builder ~transactions ~get_completed_work
      ~logger ~keypair =
    let open Interruptible.Let_syntax in
    let%bind ( diff
             , `Hash_after_applying next_ledger_builder_hash
             , `Ledger_proof ledger_proof_opt ) =
      lift_sync (fun () ->
          Ledger_builder.create_diff ledger_builder ~logger
            ~transactions_by_fee:transactions ~get_completed_work )
    in
    let%bind transition_opt =
      lift_sync (fun () ->
          let next_ledger_hash =
            Option.value_map ledger_proof_opt
              ~f:(fun (_, stmt) -> Ledger_proof.(statement_target stmt))
              ~default:
                ( previous_protocol_state |> Protocol_state.blockchain_state
                |> Blockchain_state.ledger_hash )
          in
          let blockchain_state =
            Blockchain_state.create_value ~timestamp:(Time.now time_controller)
              ~ledger_hash:next_ledger_hash
              ~ledger_builder_hash:next_ledger_builder_hash
          in
          let time =
            Time.now time_controller |> Time.to_span_since_epoch
            |> Time.Span.to_ms
          in
          Consensus_mechanism.generate_transition ~previous_protocol_state
            ~blockchain_state ~local_state:consensus_local_state ~time ~keypair
            ~transactions:
              ( Ledger_builder_diff.With_valid_signatures_and_proofs
                .transactions diff
                :> Transaction.t list )
            ~ledger:(Ledger_builder.ledger ledger_builder)
            ~logger )
    in
    Option.value
      ~default:(Interruptible.return None)
      (Option.map transition_opt
         ~f:(fun (protocol_state, consensus_transition_data) ->
           lift_sync (fun () ->
               let snark_transition =
                 Snark_transition.create_value
                   ?sok_digest:
                     (Option.map ledger_proof_opt ~f:(fun (p, _) ->
                          Ledger_proof.sok_digest p ))
                   ?ledger_proof:
                     (Option.map ledger_proof_opt
                        ~f:(Fn.compose Ledger_proof.underlying_proof fst))
                   ~supply_increase:
                     (Option.value_map ~default:Currency.Amount.zero
                        ~f:(fun (_p, statement) -> statement.supply_increase)
                        ledger_proof_opt)
                   ~blockchain_state:
                     (Protocol_state.blockchain_state protocol_state)
                   ~consensus_data:consensus_transition_data ()
               in
               let internal_transition =
                 Internal_transition.create ~snark_transition
                   ~ledger_builder_diff:(Ledger_builder_diff.forget diff)
               in
               Some (protocol_state, internal_transition) ) ))

  module Tip = struct
    type t =
      { protocol_state:
          Protocol_state.value * Protocol_state_proof.t sexp_opaque
      ; ledger_builder: Ledger_builder.t sexp_opaque
      ; transactions: Transaction.With_valid_signature.t Sequence.t sexp_opaque
      }
    [@@deriving sexp_of]
  end

  type change = Tip_change of Tip.t

  let transition_capacity = 64

  let create ~parent_log ~get_completed_work ~change_feeder:tip_reader
      ~time_controller ~keypair ~consensus_local_state =
    let logger = Logger.child parent_log "proposer" in
    let transition_reader, transition_writer = Linear_pipe.create () in
    let tip_agent = Agent.create tip_reader ~f:(fun (Tip_change tip) -> tip) in
    let propose ivar =
      let open Tip in
      let open Interruptible.Let_syntax in
      match Agent.get tip_agent with
      | None -> Interruptible.return ()
      | Some tip -> (
          Logger.info logger
            !"Begining to propose off of tip %{sexp: Tip.t}"
            tip ;
          let previous_protocol_state, previous_protocol_state_proof =
            tip.protocol_state
          in
          let%bind () =
            Interruptible.lift (Deferred.return ()) (Ivar.read ivar)
          in
          let%bind next_state_opt =
            generate_next_state ~previous_protocol_state ~consensus_local_state
              ~time_controller ~ledger_builder:tip.ledger_builder
              ~transactions:tip.transactions ~get_completed_work ~logger
              ~keypair
          in
          match next_state_opt with
          | None -> Interruptible.return ()
          | Some (protocol_state, internal_transition) ->
              lift_sync (fun () ->
                  let open Deferred.Or_error.Let_syntax in
                  ignore
                    (let%map protocol_state_proof =
                       Prover.prove ~prev_state:previous_protocol_state
                         ~prev_state_proof:previous_protocol_state_proof
                         ~next_state:protocol_state internal_transition
                     in
                     let external_transition =
                       External_transition.create ~protocol_state
                         ~protocol_state_proof
                         ~ledger_builder_diff:
                           (Internal_transition.ledger_builder_diff
                              internal_transition)
                     in
                     let time =
                       Time.now time_controller |> Time.to_span_since_epoch
                       |> Time.Span.to_ms
                     in
                     Linear_pipe.write_or_exn ~capacity:transition_capacity
                       transition_writer transition_reader
                       (external_transition, time)) ) )
    in
    let proposal_supervisor = Singleton_supervisor.create ~task:propose in
    let scheduler = Singleton_scheduler.create time_controller in
    let rec check_for_proposal () =
      Agent.with_value tip_agent ~f:(fun tip ->
          let open Tip in
          match
            Consensus_mechanism.next_proposal
              (time_to_ms (Time.now time_controller))
              (Protocol_state.consensus_state (fst tip.protocol_state))
              ~local_state:consensus_local_state ~keypair ~logger
          with
          | `Check_again time ->
              Singleton_scheduler.schedule scheduler (time_of_ms time)
                ~f:check_for_proposal
          | `Propose time ->
              Singleton_scheduler.schedule scheduler (time_of_ms time)
                ~f:(fun () ->
                  ignore
                    (Interruptible.finally
                       (Singleton_supervisor.dispatch proposal_supervisor)
                       ~f:check_for_proposal) ) )
    in
    check_for_proposal () ; transition_reader
end
