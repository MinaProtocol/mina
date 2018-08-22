open Core
open Async

module type Inputs_intf = sig
  include Protocols.Coda_pow.Inputs_intf

  module Prover : sig
    val prove :
         prev_state:Consensus_mechanism.Protocol_state.value
                    * Protocol_state_proof.t
      -> Consensus_mechanism.Internal_transition.t
      -> Protocol_state_proof.t Deferred.Or_error.t
  end

  module Proposal_interval : sig
    val t : Time.Span.t
  end
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
   and type time_controller := Inputs.Time.Controller.t =
struct
  open Inputs

  (* TODO fold signing result and hashing result together? *)
  module Consensus_result : sig
    type t

    val empty : Time.Controller.t -> t

    val create :
         Consensus_mechanism.Protocol_state.value
      -> time_controller:Time.Controller.t
      -> next_ledger_hash:Ledger_hash.t
      -> next_ledger_builder_hash:Ledger_builder_hash.t
      -> t

    val result :
         t
      -> [ `Ok of Consensus_mechanism.Protocol_state.value
                  * Consensus_mechanism.Consensus_data.value
         | `Cancelled ]
         Deferred.t

    val cancel : t -> unit
  end = struct
    type t =
      { cancelled: bool ref
      ; result:
          [ `Ok of Consensus_mechanism.Protocol_state.value
                   * Consensus_mechanism.Consensus_data.value
          | `Cancelled ]
          Deferred.t
      ; time_controller: Time.Controller.t }

    let empty time_controller =
      { cancelled= ref false
      ; result= Deferred.return `Cancelled
      ; time_controller }

    let result t = t.result

    let cancel t = t.cancelled := true

    let generate_next_state previous_state ~next_ledger_hash
        ~next_ledger_builder_hash ~time_controller =
      let open Option.Let_syntax in
      let blockchain_state =
        Blockchain_state.create_value ~timestamp:(Time.now time_controller)
          ~ledger_hash:next_ledger_hash
          ~ledger_builder_hash:next_ledger_builder_hash
      in
      let protocol_state =
        Consensus_mechanism.Protocol_state.create_value
          ~previous_state_hash:
            (Consensus_mechanism.Protocol_state.hash previous_state)
          ~blockchain_state
          ~consensus_state:
            (Consensus_mechanism.create_consensus_state previous_state)
      in
      let%map consensus_data =
        Consensus_mechanism.create_consensus_data protocol_state
          ~time:
            ( Time.now time_controller |> Time.to_span_since_epoch
            |> Time.Span.to_ms )
      in
      (protocol_state, consensus_data)

    let create previous_state ~time_controller ~next_ledger_hash
        ~next_ledger_builder_hash =
      let cancelled = ref false in
      let rec go () =
        if !cancelled then return `Cancelled
        else
          match
            generate_next_state previous_state ~next_ledger_hash
              ~next_ledger_builder_hash ~time_controller
          with
          | None ->
              let%bind () = after (sec 0.01) in
              go ()
          | Some state -> return (`Ok state)
      in
      {cancelled; result= go (); time_controller}
  end

  module Signing_result : sig
    type t

    val empty : Time.Controller.t -> t

    val cancel : t -> unit

    val create :
         state:Consensus_mechanism.Protocol_state.value * Protocol_state_proof.t
      -> time_controller:Time.Controller.t
      -> ledger_builder:Ledger_builder.t
      -> transactions:Transaction.With_valid_signature.t Sequence.t
      -> get_completed_work:(   Completed_work.Statement.t
                             -> Completed_work.Checked.t option)
      -> t

    val result :
      t -> Consensus_mechanism.External_transition.t Deferred.Or_error.t
  end = struct
    (* TODO: No need to have our own Ivar since we got rid of Bundle_result *)
    type t =
      { consensus_result: Consensus_result.t
      ; cancellation: unit Ivar.t
      ; result: Consensus_mechanism.External_transition.t Deferred.Or_error.t
      }
    [@@deriving fields]

    let empty controller =
      { consensus_result= Consensus_result.empty controller
      ; cancellation= Ivar.create ()
      ; result= Deferred.Or_error.error_string "empty" }

    let cancel t =
      Consensus_result.cancel t.consensus_result ;
      Ivar.fill_if_empty t.cancellation ()

    let create ~state:(state, state_proof) ~time_controller ~ledger_builder
        ~transactions ~get_completed_work =
      let ( diff
          , `Hash_after_applying next_ledger_builder_hash
          , `Ledger_proof ledger_proof_opt ) =
        Ledger_builder.create_diff ledger_builder
          ~transactions_by_fee:transactions ~get_completed_work
      in
      let next_ledger_hash =
        Option.value_map ledger_proof_opt
          ~f:(fun (_, stmt) -> Ledger_proof.(statement_target stmt))
          ~default:
            ( state |> Consensus_mechanism.Protocol_state.blockchain_state
            |> Blockchain_state.ledger_hash )
      in
      let consensus_result =
        Consensus_result.create state ~next_ledger_hash
          ~next_ledger_builder_hash ~time_controller
      in
      let cancellation = Ivar.create () in
      (* Someday: If bundle finishes first you can stuff more transactions in the bundle *)
      let result =
        let result =
          match%bind Consensus_result.result consensus_result with
          | `Ok (protocol_state, consensus_data) ->
              let snark_transition =
                Consensus_mechanism.Snark_transition.create_value
                  ~blockchain_state:
                    (Consensus_mechanism.Protocol_state.blockchain_state
                       protocol_state)
                  ~consensus_data
                  ~ledger_proof:
                    (Option.map ledger_proof_opt
                       ~f:(Fn.compose Ledger_proof.underlying_proof fst))
              in
              let open Deferred.Or_error.Let_syntax in
              let internal_transition =
                Consensus_mechanism.Internal_transition.create
                  ~snark_transition
                  ~ledger_builder_diff:(Ledger_builder_diff.forget diff)
              in
              let%map protocol_state_proof =
                Prover.prove ~prev_state:(state, state_proof)
                  internal_transition
              in
              let external_transition =
                Consensus_mechanism.External_transition.create ~protocol_state
                  ~protocol_state_proof
                  ~ledger_builder_diff:
                    (Consensus_mechanism.Internal_transition.
                     ledger_builder_diff internal_transition)
              in
              external_transition
          | `Cancelled ->
              Deferred.return (Or_error.error_string "Signing cancelled")
        in
        Deferred.any
          [ ( Ivar.read cancellation
            >>| fun () -> Or_error.error_string "Signing cancelled" )
          ; result ]
      in
      {consensus_result; result; cancellation}
  end

  module Tip = struct
    type t =
      { protocol_state:
          Consensus_mechanism.Protocol_state.value
          * Protocol_state_proof.t sexp_opaque
      ; ledger_builder: Ledger_builder.t sexp_opaque
      ; transactions: Transaction.With_valid_signature.t Sequence.t }
    [@@deriving sexp_of]
  end

  type change = Tip_change of Tip.t

  type t =
    { transitions:
        Consensus_mechanism.External_transition.t Linear_pipe.Reader.t }
  [@@deriving fields]

  let transition_capacity = 64

  let create ~parent_log ~get_completed_work ~change_feeder ~time_controller =
    let logger = Logger.extend parent_log [("module", Atom __MODULE__)] in
    let r, w = Linear_pipe.create () in
    let write_result = function
      | Ok t -> Linear_pipe.write_or_exn ~capacity:transition_capacity w r t
      | Error e ->
          Logger.error logger "%s\n"
            Error.(to_string_hum (tag e ~tag:"signer"))
    in
    let create_result {Tip.protocol_state; transactions; ledger_builder} =
      let result =
        Signing_result.create ~state:protocol_state ~ledger_builder
          ~transactions ~get_completed_work ~time_controller
      in
      upon (Signing_result.result result) write_result ;
      result
    in
    let schedule_transition tip =
      let time_till_transition =
        Time.modulus (Time.now time_controller) Proposal_interval.t
      in
      Logger.info logger !"Scheduling signing on a new tip %{sexp: Tip.t}" tip ;
      Time.Timeout.create time_controller time_till_transition ~f:(fun _ ->
          Logger.info logger !"Starting to sign tip %{sexp: Tip.t}" tip ;
          create_result tip )
    in
    don't_wait_for
      ( match%bind Pipe.read change_feeder.Linear_pipe.Reader.pipe with
      | `Eof -> failwith "change_feeder was empty"
      | `Ok (Tip_change initial_tip) ->
          Logger.info logger
            !"Signer got initial change with tip %{sexp: Tip.t}"
            initial_tip ;
          Linear_pipe.fold change_feeder
            ~init:(schedule_transition initial_tip) ~f:
            (fun scheduled_transition (Tip_change tip) ->
              ( match Time.Timeout.peek scheduled_transition with
              | None ->
                  Time.Timeout.cancel time_controller scheduled_transition
                    (Signing_result.empty time_controller)
              | Some result -> Signing_result.cancel result ) ;
              return (schedule_transition tip) )
          >>| ignore ) ;
    {transitions= r}
end
