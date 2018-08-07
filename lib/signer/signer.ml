open Core
open Async

module type Inputs_intf = sig
  include Protocols.Coda_pow.Inputs_intf

  module Prover : sig
    val prove :
         prev_state:State.t * State.Proof.t
      -> Internal_transition.t
      -> State.Proof.t Deferred.Or_error.t
  end

  module Transaction_interval : sig
    val t : Time.Span.t
  end
end

module Make (Inputs : Inputs_intf) :
  Coda.Signer_intf
  with type external_transition := Inputs.External_transition.t
   and type ledger_hash := Inputs.Ledger_hash.t
   and type ledger_builder := Inputs.Ledger_builder.t
   and type transaction := Inputs.Transaction.With_valid_signature.t
   and type state := Inputs.State.t
   and type state_proof := Inputs.State.Proof.t
   and type completed_work_statement := Inputs.Completed_work.Statement.t
   and type completed_work_checked := Inputs.Completed_work.Checked.t =
struct
  open Inputs

  module Hashing_result : sig
    type t

    val empty : unit -> t

    val create :
         State.t
      -> next_ledger_hash:Ledger_hash.t
      -> next_ledger_builder_hash:Ledger_builder_hash.t
      -> t

    val result : t -> [`Ok of State.t * Block_nonce.t | `Cancelled] Deferred.t

    val cancel : t -> unit
  end = struct
    type t =
      { cancelled: bool ref
      ; result: [`Ok of State.t * Block_nonce.t | `Cancelled] Deferred.t }

    let empty () = {cancelled= ref false; result= Deferred.return `Cancelled}

    let result t = t.result

    let cancel t = t.cancelled := true

    let find_block (previous: State.t) ~(next_ledger_hash: Ledger_hash.t)
        ~next_ledger_builder_hash : (State.t * Block_nonce.t) option =
      let iterations = 10 in
      let now = Time.now () in
      let difficulty = previous.next_difficulty in
      let next_difficulty =
        Difficulty.next difficulty ~last:previous.timestamp ~this:now
      in
      let next_state : State.t =
        { next_difficulty
        ; previous_state_hash= State.hash previous
        ; ledger_hash= next_ledger_hash
        ; ledger_builder_hash= next_ledger_builder_hash
        ; timestamp= now
        ; length= Length.succ (State.length previous)
        ; strength= Strength.increase previous.strength difficulty }
      in
      let nonce0 = Block_nonce.random () in
      let rec go nonce i =
        if i = iterations then None
        else
          match State.create_pow next_state nonce with
          | Ok hash when Difficulty.meets difficulty hash ->
              Some (next_state, nonce)
          | _ -> go (Block_nonce.succ nonce) (i + 1)
      in
      go nonce0 0

    let create previous ~next_ledger_hash ~next_ledger_builder_hash =
      let cancelled = ref false in
      let rec go () =
        if !cancelled then return `Cancelled
        else
          match
            find_block previous ~next_ledger_hash ~next_ledger_builder_hash
          with
          | None ->
              let%bind () = after (sec 0.01) in
              go ()
          | Some (state, nonce) -> return (`Ok (state, nonce))
      in
      {cancelled; result= go ()}
  end

  module Signing_result : sig
    type t

    val empty : unit -> t

    val cancel : t -> unit

    val create :
         state:State.t * State.Proof.t
      -> ledger_builder:Ledger_builder.t
      -> transactions:Transaction.With_valid_signature.t Sequence.t
      -> get_completed_work:(   Completed_work.Statement.t
                             -> Completed_work.Checked.t option)
      -> t

    val result : t -> External_transition.t Deferred.Or_error.t
  end = struct
    (* TODO: No need to have our own Ivar since we got rid of Bundle_result *)
    type t =
      { hashing_result: Hashing_result.t
      ; cancellation: unit Ivar.t
      ; result: External_transition.t Deferred.Or_error.t }
    [@@deriving fields]

    let empty () =
      { hashing_result= Hashing_result.empty ()
      ; cancellation= Ivar.create ()
      ; result= Deferred.Or_error.error_string "empty" }

    let cancel t =
      Hashing_result.cancel t.hashing_result ;
      Ivar.fill_if_empty t.cancellation ()

    let create ~state:(state, state_proof) ~ledger_builder ~transactions
        ~get_completed_work =
      let ( diff
          , `Hash_after_applying next_ledger_builder_hash
          , `Ledger_proof ledger_proof_opt ) =
        Ledger_builder.create_diff ledger_builder
          ~transactions_by_fee:transactions ~get_completed_work
      in
      let next_ledger_hash =
        Option.value_map ledger_proof_opt
          ~f:(fun (_, stmt) -> Ledger_proof.(statement_target stmt))
          ~default:state.State.ledger_hash
      in
      let hashing_result =
        Hashing_result.create state ~next_ledger_hash ~next_ledger_builder_hash
      in
      let cancellation = Ivar.create () in
      (* Someday: If bundle finishes first you can stuff more transactions in the bundle *)
      let result =
        let result =
          match%bind Hashing_result.result hashing_result with
          | `Ok (new_state, nonce) ->
              let transition =
                { Internal_transition.ledger_hash= next_ledger_hash
                ; ledger_builder_hash= next_ledger_builder_hash
                ; ledger_proof= Option.map ledger_proof_opt ~f:fst
                ; ledger_builder_diff= Ledger_builder_diff.forget diff
                ; timestamp= new_state.timestamp
                ; nonce }
              in
              let open Deferred.Or_error.Let_syntax in
              let%map state_proof =
                Prover.prove ~prev_state:(state, state_proof) transition
              in
              { External_transition.state_proof
              ; state= new_state
              ; ledger_builder_diff= Ledger_builder_diff.forget diff }
          | `Cancelled ->
              Deferred.return (Or_error.error_string "Signing cancelled")
        in
        Deferred.any
          [ ( Ivar.read cancellation
            >>| fun () -> Or_error.error_string "Signing cancelled" )
          ; result ]
      in
      {hashing_result; result; cancellation}
  end

  module Tip = struct
    type t =
      { state: State.t * State.Proof.t sexp_opaque
      ; ledger_builder: Ledger_builder.t sexp_opaque
      ; transactions: Transaction.With_valid_signature.t Sequence.t }
    [@@deriving sexp_of]
  end

  type change = Tip_change of Tip.t

  type state = {tip: Tip.t; result: Signing_result.t}

  type t = {transitions: External_transition.t Linear_pipe.Reader.t}
  [@@deriving fields]

  let transition_capacity = 64

  let create ~parent_log ~get_completed_work ~change_feeder =
    let logger = Logger.extend parent_log [("module", Atom __MODULE__)] in
    let r, w = Linear_pipe.create () in
    let write_result = function
      | Ok t -> Linear_pipe.write_or_exn ~capacity:transition_capacity w r t
      | Error e ->
          Logger.error logger "%s\n"
            Error.(to_string_hum (tag e ~tag:"signer"))
    in
    let create_result {Tip.state; transactions; ledger_builder} =
      let result =
        Signing_result.create ~state ~ledger_builder ~transactions
          ~get_completed_work
      in
      upon (Signing_result.result result) write_result ;
      result
    in
    let schedule_transaction tip =
      let time_till_transaction =
        Time.modulus (Time.now ()) Transaction_interval.t
      in
      Logger.info logger !"Scheduling signing on a new tip %{sexp: Tip.t}" tip ;
      Time.Timeout.create time_till_transaction (fun () ->
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
            ~init:(schedule_transaction initial_tip) ~f:
            (fun scheduled_transaction (Tip_change tip) ->
              ( match Time.Timeout.peek scheduled_transaction with
              | None ->
                  Time.Timeout.cancel scheduled_transaction
                    (Signing_result.empty ())
              | Some result -> Signing_result.cancel result ) ;
              return (schedule_transaction tip) )
          >>| ignore ) ;
    {transitions= r}
end
