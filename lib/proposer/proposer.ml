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
end = struct
  type 'a t = 'a option ref

  let create ~(f: 'a -> 'b) (reader: 'a Linear_pipe.Reader.t) : 'b t =
    let agent = ref None in
    don't_wait_for (Linear_pipe.iter reader ~f:(fun x ->
      agent := Some (f x);
      return ()));
    agent

  let get t = !t
end

module Interruptible_supervisor : sig
  type 'a t
  val create : task:(unit -> 'a Interruptible.t) -> 'a t
  val cancel : 'a t -> unit
  val dispatch : 'a t -> 'a Interruptible.t
end = struct
  type 'a t =
    { mutable task: 'a Interruptible.t option
    ; f: unit -> 'a Interruptible.t }

  let create ~task = {task= None; f= task}

  let cancel {task; _} = ignore (Option.map ~f:Interruptible.cancel)

  let dispatch t =
    cancel t;
    let task = t.f () in
    t.task <- Some task;
    task
end

module Singleton_scheduler : sig
  type t
  val create : Time.controller -> ~f:(t -> unit) -> t
  val cancel : t -> unit
  val schedule : t -> Time.t -> ~f:(unit -> unit) -> unit
end = struct
  type t =
    { time_controller: Time.controller
    ; mutable task: unit Interruptible.t }

  let create time_controller ~f =
    let t = {time_controller; task= Interruptible.create Deferred.unit} in
    f t;
    t

  let cancel {task; _} = Interruptible.cancel task

  let schedule t time ~f =
    cancel t;
    let span_till_time = Time.diff time (Time.now time_controller) in
    let timeout = Time.Timeout.create time_controller span ~f in
    t.task <- Interruptible.create timeout
end

module Make (Inputs : Inputs_intf) :
  Coda.Proposer_intf
  with type external_transition :=
              Inputs.Consensus_mechanism.External_transition.t
   and type ledger_hash := Inputs.Ledger_hash.t
   and type ledger_builder := Inputs.Ledger_builder.t
   and type transaction := Inputs.Transaction.With_valid_signature.t
   and type protocol_state := Inputs.Consensus_mechanism.Protocol_state.value
   and type protocol_state_proof := Inputs.Protocol_state_proof.t
   and type completed_work_statement := Inputs.Completed_work.Statement.t
   and type completed_work_checked := Inputs.Completed_work.Checked.t
   and type time_controller := Inputs.Time.Controller.t
   and type keypair := Inputs.Keypair.t =
struct
  open Inputs
  open Consensus_mechanism

  let generate_next_state ~previous_protocol_state ~local_state
      ~time_controller ~ledger_builder ~transactions ~get_completed_work
      ~logger ~keypair =
    let open Interruptible.Let_syntax in

    let%bind () = Interruptible.create Deferred.unit in
    let%bind (diff, `Hash_after_applying next_ledger_builder_hash, `Ledger_proof ledger_proof_opt) =
      Interruptible.return (
        Ledger_builder.create_diff ledger_builder
          ~logger
          ~transactions_by_fee:transactions
          ~get_completed_work)
    in
    let%map protocol_state, consensus_transition_data =
      let open Option.Let_syntax in
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
        Time.now time_controller |> Time.to_span_since_epoch |> Time.Span.to_ms
      in
      let%map protocol_state, consensus_transition_data =
        Consensus_mechanism.generate_transition ~previous_protocol_state
          ~blockchain_state ~local_state ~time ~keypair
          ~transactions:
            ( diff
                .Ledger_builder_diff.With_valid_signatures_and_proofs.
                 transactions
              :> Transaction.t list )
          ~ledger:(Ledger_builder.ledger ledger_builder)
      in
      Interruptible.return (protocol_state, consensus_transition_data)
    in
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
        ~blockchain_state:(Protocol_state.blockchain_state protocol_state)
        ~consensus_data:consensus_transition_data ()
    in
    let internal_transition =
      Internal_transition.create ~snark_transition
        ~ledger_builder_diff:(Ledger_builder_diff.forget diff)
    in
    (protocol_state, internal_transition)

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

  type t =
    { transitions:
        (External_transition.t * Unix_timestamp.t) Linear_pipe.Reader.t }
  [@@deriving fields]

  let transition_capacity = 64

  let create ~parent_log ~get_completed_work ~change_feeder ~time_controller ~keypair =
    let logger = Logger.child parent_log "proposer" in
    let r, w = Linear_pipe.create () in
    let write_result = function
      | Ok t ->
          let time =
            Time.now time_controller |> Time.to_span_since_epoch
            |> Time.Span.to_ms
          in
          Linear_pipe.write_or_exn ~capacity:transition_capacity w r (t, time)
      | Error e ->
          Logger.error logger "%s\n"
            Error.(to_string_hum (tag e ~tag:"signer"))
    in
    let local_state = Consensus_mechanism.Local_state.create () in

    let create_transition tip =
      let open Tip in
      let open Interruptible.Let_syntax in
      let (previous_protocol_state, previous_protocol_state_proof) = tip.protocol_state in
      let%bind protocol_state, internal_transition =
        generate_next_state
          ~previous_protocol_state
          ~local_state
          ~time_controller
          ~ledger_builder:tip.ledger_builder
          ~transactions:tip.transactions
          ~get_completed_work
          ~logger
          ~keypair
      in
      let%bind protocol_state_proof =
        prove
          ~prev_state:previous_protocol_state
          ~prev_state_proof:previous_protocol_state_proof
          ~next_state:protocol_state
          internal_transition
      in
      let%map external_transition =
        External_transition.create
          ~protocol_state
          ~protocol_state_proof
          ~ledger_builder_diff:(Internal_transition.ledger_builder_diff internal_transition)
      in
      external_transition
    in

    (*
    let tip_agent = Agent.create tip_reader ~f:(fun (Tip_change tip) -> tip) in
    let schedule_at ~f time =
      let span = Time.diff time (Time.now time_controller) in
      Time.Timeout.create time_controller span ~f
    in
    let schedule_proposal tip =
      match Consensus_mechanism.next_proposal_time (Time.now time_controller) tip.protocol_state with
      | `Check_again time -> schedule_at time ~f:(fun _ -> schedule_proposal tip)
      | `Propose time     ->
          schedule_at time ~f:(fun _ ->
            let tip = Agent.get tip_agent in
            Logger.info logger !"Starting to sign tip %{sexp: Tip.t}" tip;
            upon (Interruptible_supervisor.dispatch transition_supervisor tip) write_transition)

           (*
            create_transition tip
            |> Interruptible.map ~f:write_transition
            |> Interruptible.don't_wait_for)
              *)
    in
     *)

    let transition_reader, transition_writer = Linear_pipe.create () in
    let tip_agent = Agent.create tip_reader ~f:(fun (Tip_change tip) -> tip) in
    let proposal_supervisor = Singleton_supervisor.create ~f:(propose transition_writer) in
    let check_for_proposal scheduler =
      let check_again () = check_for_proposal scheduler in
      let tip = Agent.get tip_agent in
      match Consensus_mechanism.next_proposal_time (Time.now time_controller) tip.protocol_state with
      | `Check_again time -> Singleton_scheduler.schedule time ~f:check_again
      | `Propose time     ->
          Singleton_scheduler.schedule time ~f:(fun () ->
            Interruptible.finally
              (Singleton_supervisor.dispatch proposal_supervisor tip)
              check_again)
    in
    ignore (Singleton_scheduler.create time_controller ~f:check_for_proposal); 
    transition_reader
end
