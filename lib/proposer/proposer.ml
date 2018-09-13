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
   and type time_controller := Inputs.Time.Controller.t
   and type keypair := Inputs.Keypair.t =
struct
  open Inputs
  open Consensus_mechanism

  module External_transition_result : sig
    type t

    val cancel : t -> unit

    val create :
         previous_protocol_state:Protocol_state.value
      -> previous_protocol_state_proof:Protocol_state_proof.t
      -> protocol_state:Protocol_state.value
      -> internal_transition:Internal_transition.t
      -> t

    val result : t -> External_transition.t Deferred.Or_error.t
  end = struct
    (* TODO: No need to have our own Ivar since we got rid of Bundle_result *)
    type t =
      { cancellation: unit Ivar.t
      ; result: External_transition.t Deferred.Or_error.t }
    [@@deriving fields]

    let cancel t = Ivar.fill_if_empty t.cancellation ()

    let create ~previous_protocol_state ~previous_protocol_state_proof
        ~protocol_state ~internal_transition =
      let cancellation = Ivar.create () in
      (* Someday: If bundle finishes first you can stuff more transactions in the bundle *)
      let result =
        let result =
          let open Deferred.Or_error.Let_syntax in
          let%map protocol_state_proof =
            Prover.prove ~prev_state:previous_protocol_state
              ~prev_state_proof:previous_protocol_state_proof
              ~next_state:protocol_state internal_transition
          in
          External_transition.create ~protocol_state ~protocol_state_proof
            ~ledger_builder_diff:
              (Internal_transition.ledger_builder_diff internal_transition)
        in
        Deferred.any
          [ ( Ivar.read cancellation
            >>| fun () -> Or_error.error_string "Signing cancelled" )
          ; result ]
      in
      {result; cancellation}
  end

  let generate_next_state ~previous_protocol_state ~local_state
      ~time_controller ~ledger_builder ~transactions ~get_completed_work
      ~logger ~keypair =
    let open Option.Let_syntax in
    let ( diff
        , `Hash_after_applying next_ledger_builder_hash
        , `Ledger_proof ledger_proof_opt ) =
      Ledger_builder.create_diff ledger_builder ~logger
        ~transactions_by_fee:transactions ~get_completed_work
    in
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

  let create ~parent_log ~get_completed_work ~change_feeder ~time_controller
      ~keypair =
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
    let create_result
        { Tip.protocol_state=
            previous_protocol_state, previous_protocol_state_proof
        ; transactions
        ; ledger_builder } =
      let open Option.Let_syntax in
      let%map protocol_state, internal_transition =
        generate_next_state ~previous_protocol_state ~local_state
          ~time_controller ~ledger_builder ~transactions ~get_completed_work
          ~logger ~keypair
      in
      let result =
        External_transition_result.create ~previous_protocol_state
          ~previous_protocol_state_proof ~protocol_state ~internal_transition
      in
      upon (External_transition_result.result result) write_result ;
      result
    in
    let schedule_transition tip =
      let time_now = Time.now time_controller in
      let time_after_last_transition =
        Time.modulus time_now Proposal_interval.t
      in
      let last_transition_time =
        Time.sub time_now time_after_last_transition
      in
      let time_of_next_transition =
        Time.add last_transition_time Proposal_interval.t
      in
      let time_till_transition = Time.diff time_of_next_transition time_now in
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
              | None | Some None ->
                  Time.Timeout.cancel time_controller scheduled_transition None
              | Some (Some result) -> External_transition_result.cancel result
              ) ;
              return (schedule_transition tip) )
          >>| ignore ) ;
    {transitions= r}
end
