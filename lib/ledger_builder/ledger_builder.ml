open Core_kernel
open Async_kernel
open Protocols

module Make (Fee : sig
  type t [@@deriving sexp_of]

  val add : t -> t -> t

  val sub : t -> t -> t

  val zero : t

  val gte : t -> t -> bool
end) (Public_key : sig
  include Coda_pow.Public_Key_intf
end) (Transaction : sig
  include Coda_pow.Transaction_intf with type fee := Fee.t

  include Sexpable with type t := t
  (*[@@deriving sexp] , bin_io, eq] *)
end) (Fee_transfer : sig
  include Coda_pow.Fee_transfer_intf
          with type public_key := Public_key.t
           and type fee := Fee.t
end) (Super_transaction : sig
  include Coda_pow.Super_transaction_intf
          with type valid_transaction := Transaction.With_valid_signature.t
           and type fee_transfer := Fee_transfer.t
           and type fee := Fee.t
end) (Proof : sig
  include Coda_pow.Snark_pool_proof_intf

  include Sexpable with type t := t
end) (Ledger : sig
  include Coda_pow.Ledger_intf
end) (Ledger_hash : sig
  include Coda_pow.Ledger_hash_intf

  val equal : t -> t -> bool
end) (Ledger_builder_hash : sig
  type t [@@deriving eq]
end) (Ledger_builder_witness : sig
  include Coda_pow.Ledger_builder_witness_intf
          with type fee := Fee.t
           and type transaction := Transaction.With_valid_signature.t
           and type pk := Public_key.t

  val prev_hash : t -> Ledger_builder_hash.t
end) (Proof_type : sig
  type t [@@deriving sexp_of]
end) (Transaction_snark : sig
  type t [@@deriving sexp_of]

  val base : Proof_type.t

  val merge : Proof_type.t

  val verify : t -> bool

  val create :
       proof:Ledger_builder_witness.snarket_proof
    -> source:Ledger_hash.t
    -> target:Ledger_hash.t
    -> fee_excess:Fee.t
    -> proof_type:Proof_type.t
    -> t
end) =
struct
  (* Assume you have

  enqueue_data
  : Paralell_scan.State.t -> Transition,t list -> unit

  complete_jobs
  : Paralell_scan.State.t -> Accum.t list -> unit
  
  Alternatively,
  change the intf of parallel scan to take a function
  check_work : Job.t -> Accum.t -> bool Deferred,t

  and then have in parallel scan

  validate_and_apply_work
  : Parallel_scan.State.t -> Accum.t list -> unit Or_error.t Deferred.t

  *)

  module Statement = struct
    type t =
      { source: Ledger_hash.t
      ; target: Ledger_hash.t
      ; fee_excess: Fee.t (*Currency.Amount.Signed.t*)
      ; proof_type: Proof_type.t
      (*[ `Merge | `Base ]*)
      (*Should this also contain the transactions part of this statement?*) }
    [@@deriving sexp_of]
  end

  module With_statement = struct
    type 'a t = 'a * Statement.t [@@deriving sexp_of]
  end

  module Ledger_proof = struct
    type t = {next_ledger_hash: Ledger_hash.t; proof: Proof.t}
  end

  (*module Completed_work = struct
    type t =
      { fee : Currency.Fee.t
      ; worker : Public_key.t
      ; proof : Proof.t
      }
  end*)

  type transaction = Super_transaction.t [@@deriving sexp_of]

  type snark_for_statement = Transaction_snark.t With_statement.t
  [@@deriving sexp_of]

  type job =
    ( snark_for_statement
    , transaction With_statement.t )
    Parallel_scan.State.Job.t
  [@@deriving sexp_of]

  let new_statement transaction : Statement.t =
    { source= failwith "TODO"
    ; target= failwith "TODO"
    ; fee_excess= Super_transaction.fee_excess transaction
    ; proof_type= Transaction_snark.base }

  let new_job (transaction: Super_transaction.t) :
      ('a, transaction With_statement.t) Parallel_scan.State.Job.t =
    Base (Some (transaction, new_statement transaction))

  type t =
    { scan_state:
        ( snark_for_statement
        , snark_for_statement
        , transaction With_statement.t )
        Parallel_scan.State.t
    ; ledger: Ledger.t }

  let copy t = {scan_state= t.scan_state; ledger= t.ledger}

  module Job_hash = struct
    type t = job [@@deriving sexp_of]
  end

  let job_proof_map = Hashtbl.create

  let hash t : Ledger_builder_hash.t = failwith "TODO"

  module Spec = struct
    module Accum = struct
      type t = Transaction_snark.t With_statement.t [@@deriving sexp_of]

      let ( + ) t t' : t Deferred.t = failwith "TODO"
    end

    module Data = struct
      type t = transaction With_statement.t [@@deriving sexp_of]
    end

    module Output = struct
      type t = Transaction_snark.t With_statement.t [@@deriving sexp_of]
    end

    let merge t t' = return t'

    let map (x: Data.t) : Accum.t Deferred.t =
      failwith
        "Create a transaction snark from a transaction. Needs to look up some \
         ds that stores all the proofs that the witness has"
  end

  let spec =
    ( module Spec
    : Parallel_scan.Spec_intf with type Data.t = transaction With_statement.t and type 
      Accum.t = Transaction_snark.t With_statement.t and type Output.t = Transaction_snark.
                                                                         t
                                                                         With_statement.
                                                                         t )

  let statement_of_job : job -> Statement.t option = function
    | Base (Some (_, statement)) -> Some statement
    | Merge_up (Some (_, statement)) -> Some statement
    | Merge (Some (_, stmt1), Some (_, stmt2)) ->
        assert (Ledger_hash.equal stmt1.target stmt2.source) ;
        Some
          { source= stmt1.source
          ; target= stmt2.target
          ; fee_excess=
              Fee.add stmt1.fee_excess stmt2.fee_excess
              (*Currency.Amount.Signed.add stmt1.fee_excess stmt2.fee_excess
            |> Option.value_exn*)
          ; proof_type= Transaction_snark.merge (*`Merge*) }
    | _ -> None

  let verify job proof =
    let statement = Option.value_exn (statement_of_job job) in
    let transaction_snark =
      Transaction_snark.create ~proof ~source:statement.source
        ~target:statement.target ~fee_excess:statement.fee_excess
        ~proof_type:statement.proof_type
    in
    assert (Transaction_snark.verify transaction_snark)

  let fill_in_completed_work state works =
    failwith "TODO: To be done in parallel scan?"

  let apply t (witness: Ledger_builder_witness.t) :
      (t * (Ledger_hash.t * Ledger_proof.t) option) Deferred.Or_error.t =
    let check b label = if not b then Or_error.error_string label else Ok () in
    let open Or_error.Let_syntax in
    let _ =
      check
        (not
           (Ledger_builder_hash.equal
              (Ledger_builder_witness.prev_hash witness)
              (hash t)))
        "bad hash"
    in
    let payments = Ledger_builder_witness.transactions witness in
    let work_fee = Ledger_builder_witness.total_work_fee witness in
    let delta =
      Fee.sub
        (List.fold
           (List.map payments Transaction.transaction_fee)
           ~init:Fee.zero ~f:Fee.add)
        work_fee
    in
    let _ = check (Fee.gte delta Fee.zero) "fees does not suffice" in
    let next_jobs =
      Parallel_scan.next_k_jobs ~state:t.scan_state ~spec
        ~k:(List.length @@ Ledger_builder_witness.proofs witness)
    in
    let completed_works = Ledger_builder_witness.completed_work_list witness in
    let _ =
      (*verify the completed_work*)
      List.iter2 next_jobs
        (List.map completed_works (fun (proof, _, _) -> proof))
        verify
    in
    let _ =
      fill_in_completed_work t.scan_state completed_works
      (*Applying the completed work to the scan state*)
    in
    let fee_transfers =
      (*create fee transfers to pay the workers*)
      let ft =
        List.map completed_works ~f:(fun (_, fee, worker) -> (worker, fee))
        |> Fee_transfer.of_single_list
      in
      List.map ft Super_transaction.from_fee_transfer
    in
    let new_jobs =
      List.map
        (List.append fee_transfers
           (List.map payments Super_transaction.from_transaction))
        new_job
    in
    let _ =
      (*Enqueueing new jobs to the scan state*)
      Parallel_scan.enqueue_new_jobs t.scan_state new_jobs
    in
    Deferred.return @@ Ok (t, None)
end
