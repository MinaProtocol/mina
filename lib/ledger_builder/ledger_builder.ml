open Core_kernel
open Async_kernel
open Protocols

module Make (Fee : sig
  type t [@@deriving sexp_of]

  val add : t -> t -> t option

  val sub : t -> t -> t option

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

  let option lab =
    Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

  let check label b = if not b then Or_error.error_string label else Ok ()

  let statement_of_job : job -> Statement.t option = function
    | Base (Some (_, statement)) -> Some statement
    | Merge_up (Some (_, statement)) -> Some statement
    | Merge (Some (_, stmt1), Some (_, stmt2)) ->
        let open Option.Let_syntax in
        let%bind () =
          Option.some_if (Ledger_hash.equal stmt1.target stmt2.source) ()
        in
        let%map fee_excess = Fee.add stmt1.fee_excess stmt2.fee_excess in
        { Statement.source= stmt1.source
        ; target= stmt2.target
        ; fee_excess
        ; proof_type= Transaction_snark.merge }
    | _ -> None

  (* TODO: This should yield to the scheduler between verify's *)
  let verify job proof =
    match statement_of_job job with
    | None -> return false
    | Some statement ->
        let transaction_snark =
          Transaction_snark.create ~proof ~source:statement.source
            ~target:statement.target ~fee_excess:statement.fee_excess
            ~proof_type:statement.proof_type
        in
        return (Transaction_snark.verify transaction_snark)

  let fill_in_completed_work state works =
    failwith "TODO: To be done in parallel scan?"

  let sum_fees xs ~f =
    with_return (fun {return} ->
        Ok
          (List.fold ~init:Fee.zero xs ~f:(fun acc x ->
               match Fee.add acc (f x) with
               | None -> return (Or_error.error_string "Fee overflow")
               | Some res -> res )) )

  let fst (a, b, c) = a

  let snd (a, b, c) = b

  let thrd (a, b, c) = c

  let create_transaction_snark (statement: Statement.t) work =
    Transaction_snark.create ~proof:work ~source:statement.source
      ~target:statement.target ~fee_excess:statement.fee_excess
      ~proof_type:statement.proof_type

  let job_proof (job: job) (work: Ledger_builder_witness.completed_work) :
      (job * snark_for_statement) Or_error.t =
    match job with
    | Base (Some (t, s)) -> Ok (job, (create_transaction_snark s (fst work), s))
    | Merge (Some (t, s), Some (t', s')) ->
        let open Or_error.Let_syntax in
        let%bind fee =
          Fee.add s.fee_excess s'.fee_excess
          |> option "Error adding fee_excess"
        in
        let new_stmt : Statement.t =
          { source= s.source
          ; target= s'.target
          ; fee_excess= fee
          ; proof_type= Transaction_snark.merge }
        in
        Ok (job, (create_transaction_snark new_stmt (fst work), new_stmt))
    | _ ->
        Error
          (Error.of_thunk (fun () ->
               sprintf "Invalid job for the corresponding transaction_snark" ))

  let jobs_proofs_assoc jobs completed_works :
      (job * snark_for_statement) list Or_error.t =
    let open Or_error.Let_syntax in
    let rec map_custom js ws =
      match (js, ws) with
      | [], [] -> Ok []
      | j :: js', w :: ws' ->
          let%bind sn = job_proof j w in
          let%bind rem_sn = map_custom js' ws' in
          Ok (sn :: rem_sn)
      | _ ->
          Error
            (Error.of_thunk (fun () ->
                 sprintf "Job list and work list length mismatch" ))
    in
    map_custom jobs completed_works

  let apply t (witness: Ledger_builder_witness.t) :
      (t * (Ledger_hash.t * Ledger_proof.t) option) Deferred.Or_error.t =
    let open Deferred.Or_error.Let_syntax in
    let payments = Ledger_builder_witness.transactions witness in
    let completed_works = Ledger_builder_witness.completed_work_list witness in
    let check_hash_and_fees =
      let open Or_error.Let_syntax in
      let%bind () =
        check "bad hash"
          (not
             (Ledger_builder_hash.equal
                (Ledger_builder_witness.prev_hash witness)
                (hash t)))
      in
      let%bind budget = sum_fees payments ~f:Transaction.transaction_fee in
      let%bind work_fee =
        sum_fees completed_works ~f:(fun (_, fee, _) -> fee)
      in
      let%map delta =
        Fee.sub budget work_fee |> option "budget did not suffice"
      in
      ()
    in
    let%bind () = Deferred.return check_hash_and_fees in
    let%bind assoc_list =
      (*TODO to be sent to the parallel scan to update the ring_buffer*)
      let next_jobs =
        Parallel_scan.next_k_jobs ~state:t.scan_state ~spec
          ~k:(List.length @@ Ledger_builder_witness.proofs witness)
      in
      let%bind () =
        Deferred.List.for_all (List.zip_exn next_jobs completed_works) ~f:
          (fun (job, (proof, _, _)) -> verify job proof )
        |> Deferred.map ~f:(check "proofs did not verify")
      in
      return @@ jobs_proofs_assoc next_jobs completed_works
    in
    let%bind () =
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
        (List.map payments Super_transaction.from_transaction @ fee_transfers)
        new_job
    in
    let%bind () =
      (*Enqueueing new jobs to the scan state*)
      Parallel_scan.enqueue_new_jobs t.scan_state new_jobs
      |> Deferred.map ~f:(fun () -> Ok ())
    in
    Deferred.return @@ Ok (t, None)
end
