open Core
open Async
open Coda_base

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
      { m: (module S)
      ; cache: Cache.t
      ; proof_level: Genesis_constants.Proof_level.t }

    let create ~proof_level () =
      ( if Genesis_constants.Proof_level.is_compiled proof_level then
        Genesis_constants.Proof_level.(
          failwithf "Bad proof level %s (expected %s)" (to_string proof_level)
            (to_string compiled) ()) ) ;
      let%map proving, verification =
        match proof_level with
        | Genesis_constants.Proof_level.Full ->
            let%map proving = Snark_keys.transaction_proving ()
            and verification = Snark_keys.transaction_verification () in
            (proving, verification)
        | Check | None ->
            return Transaction_snark.Keys.(Proving.dummy, Verification.dummy)
      in
      { m=
          ( module Transaction_snark.Make (struct
            let keys = {Transaction_snark.Keys.proving; verification}
          end)
          : S )
      ; cache= Cache.create ()
      ; proof_level }

    let worker_wait_time = 5.
  end

  type single_spec =
    ( Transaction.t Transaction_protocol_state.t
    , Transaction_witness.t
    , Transaction_snark.t )
    Snark_work_lib.Work.Single.Spec.t
  [@@deriving sexp]

  (* TODO: Use public_key once SoK is implemented *)
  let perform_single ({m= (module M); cache; proof_level} : Worker_state.t)
      ~message =
    ( if Genesis_constants.Proof_level.is_compiled proof_level then
      Genesis_constants.Proof_level.(
        failwithf "Bad proof level %s (expected %s)" (to_string proof_level)
          (to_string compiled) ()) ) ;
    let open Snark_work_lib in
    let sok_digest = Coda_base.Sok_message.digest message in
    fun (single : single_spec) ->
      match proof_level with
      | Genesis_constants.Proof_level.Full -> (
          let statement = Work.Single.Spec.statement single in
          let process k =
            let start = Time.now () in
            match k () with
            | Error e ->
                Logger.error (Logger.create ()) ~module_:__MODULE__
                  ~location:__LOC__ "SNARK worker failed: $error"
                  ~metadata:
                    [ ("error", `String (Error.to_string_hum e))
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
              Or_error.return (proof, Time.Span.zero)
          | None -> (
            match single with
            | Work.Single.Spec.Transition
                (input, t, (w : Transaction_witness.t)) ->
                process (fun () ->
                    Or_error.try_with (fun () ->
                        M.of_transaction ~sok_digest
                          ~source:input.Transaction_snark.Statement.source
                          ~target:input.target t
                          ~pending_coinbase_stack_state:
                            input
                              .Transaction_snark.Statement
                               .pending_coinbase_stack_state
                          (unstage (Coda_base.Sparse_ledger.handler w.ledger))
                    ) )
            | Merge (_, proof1, proof2) ->
                process (fun () -> M.merge ~sok_digest proof1 proof2) ) )
      | Check | None ->
          (* Use a dummy proof. *)
          let stmt, proof_type =
            match single with
            | Work.Single.Spec.Transition (stmt, _, _) ->
                (stmt, `Base)
            | Merge (stmt, _, _) ->
                (stmt, `Merge)
          in
          let fee_excess =
            Currency.Amount.(
              Signed.create
                ~magnitude:(of_fee stmt.fee_excess.magnitude)
                ~sgn:stmt.fee_excess.sgn)
          in
          Or_error.return
          @@ ( Transaction_snark.create ~source:stmt.source ~target:stmt.target
                 ~proof_type ~supply_increase:stmt.supply_increase
                 ~pending_coinbase_stack_state:
                   stmt.pending_coinbase_stack_state ~fee_excess ~sok_digest
                 ~proof:Precomputed_values.unit_test_base_proof
             , Time.Span.zero )
end

module Worker = Functor.Make (Inputs)
