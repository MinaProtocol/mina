open Core
open Async
open Mina_base

module Cache = struct
  module T = Hash_heap.Make (Transaction_snark.Statement)

  type t = (Time.t * Transaction_snark.t) T.t

  let max_size = 100

  let create () : t = T.create (fun (t1, _) (t2, _) -> Time.compare t1 t2)

  let add t ~statement ~proof =
    T.push_exn t ~key:statement ~data:(Time.now (), proof) ;
    if Int.( > ) (T.length t) max_size then ignore (T.pop_exn t)

  let find (t : t) statement = Option.map ~f:snd (T.find t statement)
end

module Inputs = struct
  module Ledger_proof = Ledger_proof.Prod

  module Worker_state = struct
    module type S = Transaction_snark.S

    type t =
      { m: (module S) option
      ; cache: Cache.t
      ; proof_level: Genesis_constants.Proof_level.t }

    let create ~constraint_constants ~proof_level () =
      let m =
        match proof_level with
        | Genesis_constants.Proof_level.Full ->
            Some
              ( module Transaction_snark.Make (struct
                let constraint_constants = constraint_constants
              end)
              : S )
        | Check | None ->
            None
      in
      Deferred.return {m; cache= Cache.create (); proof_level}

    let worker_wait_time = 5.
  end

  type single_spec =
    ( Transaction.t
    , Transaction_witness.t
    , Transaction_snark.t )
    Snark_work_lib.Work.Single.Spec.t
  [@@deriving sexp]

  let perform_single ({m; cache; proof_level} : Worker_state.t) ~message =
    let open Deferred.Or_error.Let_syntax in
    let open Snark_work_lib in
    let sok_digest = Mina_base.Sok_message.digest message in
    fun (single : single_spec) ->
      match proof_level with
      | Genesis_constants.Proof_level.Full -> (
          let (module M) = Option.value_exn m in
          let statement = Work.Single.Spec.statement single in
          let process k =
            let start = Time.now () in
            match%map.Async k () with
            | Error e ->
                let logger = Logger.create () in
                [%log error] "SNARK worker failed: $error"
                  ~metadata:
                    [ ("error", Error_json.error_to_yojson e)
                    ; ( "spec"
                        (* the sexp_opaque in Work.Single.Spec.t means we can't derive yojson,
		       so we use the less-desirable sexp here
                    *)
                      , `String (Sexp.to_string (sexp_of_single_spec single))
                      ) ] ;
                Error.raise e
            | Ok res ->
                Cache.add cache ~statement ~proof:res ;
                let total = Time.abs_diff (Time.now ()) start in
                Ok (res, total)
          in
          match Cache.find cache statement with
          | Some proof ->
              Deferred.Or_error.return (proof, Time.Span.zero)
          | None -> (
            match single with
            | Work.Single.Spec.Transition
                (input, t, (w : Transaction_witness.t)) ->
                process (fun () ->
                    let%bind t =
                      Deferred.return
                      @@
                      (* Validate the received transaction *)
                      match t with
                      | Command (Signed_command cmd) -> (
                        match Signed_command.check cmd with
                        | Some cmd ->
                            ( Ok (Command (Signed_command cmd))
                              : Transaction.Valid.t Or_error.t )
                        | None ->
                            Or_error.errorf "Command has an invalid signature"
                        )
                      | Command (Snapp_command cmd) ->
                          Ok (Command (Snapp_command cmd))
                      | Fee_transfer ft ->
                          Ok (Fee_transfer ft)
                      | Coinbase cb ->
                          Ok (Coinbase cb)
                    in
                    let snapp_account1, snapp_account2 =
                      Sparse_ledger.snapp_accounts w.ledger
                        (Transaction.forget t)
                    in
                    Deferred.Or_error.try_with (fun () ->
                        M.of_transaction ~sok_digest ~snapp_account1
                          ~snapp_account2
                          ~source:input.Transaction_snark.Statement.source
                          ~target:input.target
                          { Transaction_protocol_state.Poly.transaction= t
                          ; block_data= w.protocol_state_body }
                          ~init_stack:w.init_stack
                          ~next_available_token_before:
                            input.next_available_token_before
                          ~next_available_token_after:
                            input.next_available_token_after
                          ~pending_coinbase_stack_state:
                            input
                              .Transaction_snark.Statement
                               .pending_coinbase_stack_state
                          (unstage (Mina_base.Sparse_ledger.handler w.ledger))
                    ) )
            | Merge (_, proof1, proof2) ->
                process (fun () -> M.merge ~sok_digest proof1 proof2) ) )
      | Check | None ->
          (* Use a dummy proof. *)
          let stmt =
            match single with
            | Work.Single.Spec.Transition (stmt, _, _) ->
                stmt
            | Merge (stmt, _, _) ->
                stmt
          in
          Deferred.Or_error.return
          @@ ( Transaction_snark.create ~source:stmt.source ~target:stmt.target
                 ~supply_increase:stmt.supply_increase
                 ~pending_coinbase_stack_state:
                   stmt.pending_coinbase_stack_state
                 ~next_available_token_before:stmt.next_available_token_before
                 ~next_available_token_after:stmt.next_available_token_after
                 ~fee_excess:stmt.fee_excess ~sok_digest
                 ~proof:Proof.transaction_dummy
             , Time.Span.zero )
end
