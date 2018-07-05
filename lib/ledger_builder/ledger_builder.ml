open Core_kernel
open Async_kernel
open Protocols

module Make (Fee : sig
  module Unsigned : sig
    type t [@@deriving sexp_of, eq]

    val add : t -> t -> t option

    val sub : t -> t -> t option

    val zero : t

    val gte : t -> t -> bool
  end

  module Signed : sig
    type t [@@deriving sexp_of]

    val add : t -> t -> t option

    val negate : t -> t

    val of_unsigned : Unsigned.t -> t
  end
end) (Public_key : sig
  include Coda_pow.Public_Key_intf
end) (Transaction : sig
  include Coda_pow.Transaction_intf with type fee := Fee.Unsigned.t

  include Sexpable with type t := t
  (*[@@deriving sexp] , bin_io, eq] *)
end) (Fee_transfer : sig
  include Coda_pow.Fee_transfer_intf
          with type public_key := Public_key.t
           and type fee := Fee.Unsigned.t
end) (Super_transaction : sig
  include Coda_pow.Super_transaction_intf
          with type valid_transaction := Transaction.With_valid_signature.t
           and type fee_transfer := Fee_transfer.t
           and type signed_fee := Fee.Signed.t
end) (Proof : sig
  include Coda_pow.Snark_pool_proof_intf

  include Sexpable with type t := t
end)  (Ledger_hash : sig
  include Coda_pow.Ledger_hash_intf

  val equal : t -> t -> bool
end) (Ledger : sig
  include Coda_pow.Ledger_intf with type ledger_hash := Ledger_hash.t
                                and type super_transaction := Super_transaction.t
end)(Ledger_builder_hash : sig
  type t [@@deriving eq]
end) (Ledger_builder_witness : sig
  include Coda_pow.Ledger_builder_witness_intf
          with type fee := Fee.Unsigned.t
           and type transaction := Transaction.With_valid_signature.t
           and type pk := Public_key.t

  val prev_hash : t -> Ledger_builder_hash.t
end) (Proof_type : sig
  type t = Base | Merge [@@deriving sexp_of]
end) (Transaction_snark : sig
  type t [@@deriving sexp_of]

  val base : Proof_type.t

  val merge : Proof_type.t

  val verify : t -> bool

  val create :
       proof:Ledger_builder_witness.snarket_proof
    -> source:Ledger_hash.t
    -> target:Ledger_hash.t
    -> fee_excess:Fee.Signed.t
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
      ; fee_excess: Fee.Signed.t
      ; proof_type: Proof_type.t
      }
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

  type t =
    { scan_state:
        ( snark_for_statement
        , snark_for_statement
        , transaction With_statement.t )
        Parallel_scan.State.t
  (* Invariant: this is the ledger after having applied all the transactions in
    the above state. *)
    ; ledger: Ledger.t
    ; public_key : Public_key.t
    }

  let copy {scan_state; ledger; public_key } =
    { scan_state= Parallel_scan.State.copy scan_state
    ; ledger= Ledger.copy ledger
    ; public_key
    }

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

  let option lab =
    Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

  let check label b =
    if not b
    then Or_error.error_string label
    else Ok ()

  let statement_of_job : job -> Statement.t option = function
    | Base (Some (_, statement)) -> Some statement
    | Merge_up (Some (_, statement)) -> Some statement
    | Merge (Some (_, stmt1), Some (_, stmt2)) ->
      let open Option.Let_syntax in
      let%bind () =
        Option.some_if (Ledger_hash.equal stmt1.target stmt2.source) ()
      in
      let%map fee_excess = Fee.Signed.add stmt1.fee_excess stmt2.fee_excess in
      { Statement.source= stmt1.source
      ; target= stmt2.target
      ; fee_excess
      ; proof_type= Transaction_snark.merge
      }
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

  module Result_with_rollback = struct
    module Rollback = struct
      type t = Do_nothing | Call of (unit -> unit)

      let compose t1 t2 =
        match t1, t2 with
        | Do_nothing, t | t, Do_nothing -> t
        | Call f1, Call f2 -> Call (fun () -> f1 (); f2 ())

      let run = function
        | Do_nothing -> ()
        | Call f -> f ()
    end

    module T = struct
      type 'a result = 
        { result : 'a Or_error.t
        ; rollback : Rollback.t
        }

      type 'a t = 'a result Deferred.t

      let return x =
        Deferred.return { result = Ok x; rollback = Do_nothing }

      let bind tx ~f =
        Deferred.bind tx ~f:(fun { result; rollback } ->
          match result with
          | Error e ->
            Deferred.return { result = Error e; rollback }
          | Ok x ->
            Deferred.map (f x) ~f:(fun ty ->
              { result = ty.result
              ; rollback = Rollback.compose rollback ty.rollback
              }))

      let map t ~f =
        Deferred.map t ~f:(fun res -> { res with result = Or_error.map ~f res.result })

      let map = `Custom map
    end
    include T
    include Monad.Make(T)

    let run t =
      Deferred.map t ~f:(fun { result; rollback } ->
        Rollback.run rollback;
        result)

    let error e = Deferred.return { result = Error e; rollback = Do_nothing }

    let of_or_error result = Deferred.return { result; rollback = Do_nothing }

    let with_no_rollback dresult =
      Deferred.map dresult ~f:(fun result -> { result; rollback = Do_nothing })
  end

  let fill_in_completed_work state works
    : Transaction_snark.t With_statement.t option Result_with_rollback.t =
    failwith "TODO: To be done in parallel scan?"

  let enqueue_data_with_rollback state data : unit Result_with_rollback.t =
    failwith "TODO"

  let sum_fees xs ~f =
    with_return (fun {return} ->
      Ok (
        List.fold ~init:Fee.Unsigned.zero xs ~f:(fun acc x ->
          match Fee.Unsigned.add acc (f x) with
          | None -> return (Or_error.error_string "Fee overflow")
          | Some res -> res)))

  let update_ledger_and_get_statements ledger ts =
    let undo_transactions =
      List.iter ~f:(fun t ->
        Or_error.ok_exn (Ledger.undo_super_transaction ledger t))
    in
    let rec go processed acc = function
      | [] ->
        Deferred.return
          { Result_with_rollback.result = Ok (List.rev acc)
          ; rollback = Call (fun () -> undo_transactions processed)
          }

      | t :: ts ->
        let source = Ledger.merkle_root ledger in
        begin match Ledger.apply_super_transaction ledger t with
        | Error e ->
          undo_transactions processed;
          Result_with_rollback.error e

        | Ok () ->
          let target = Ledger.merkle_root ledger in
          let stmt : Statement.t =
            { source; target; fee_excess = Super_transaction.fee_excess t; proof_type = Base }
          in
          go (t :: processed) ((t, stmt) :: acc) ts
        end
    in
    go [] [] ts

  let check_completed_works t completed_works =
    Result_with_rollback.with_no_rollback begin
      let open Deferred.Or_error.Let_syntax in
      let%bind next_jobs =
        Parallel_scan.next_k_jobs ~state:t.scan_state ~spec
          ~k:(List.length completed_works)
        |> Deferred.return
      in
      Deferred.List.for_all
        (List.zip_exn next_jobs completed_works)
        ~f:(fun (job, (proof, _, _)) -> verify job proof)
      |> Deferred.map ~f:(check "proofs did not verify")
    end

  let apply t (witness: Ledger_builder_witness.t) :
      (Transaction_snark.t With_statement.t option) Result_with_rollback.t =
    let payments = witness.transactions in
    let completed_works = witness.completed_works in
    let open Result_with_rollback.Let_syntax in
    let%bind () =
      check "bad hash"
        (not
          (Ledger_builder_hash.equal
              (Ledger_builder_witness.prev_hash witness)
              (hash t)))
      |> Result_with_rollback.of_or_error
    in
    let%bind delta =
      Result_with_rollback.of_or_error begin
        let open Or_error.Let_syntax in
        let%bind budget = sum_fees payments ~f:Transaction.fee in
        let%bind work_fee = sum_fees completed_works ~f:(fun (_, fee, _) -> fee) in
        option "budget did not suffice"
          (Fee.Unsigned.sub budget work_fee)
      end
    in
    let fee_transfers =
      (*create fee transfers to pay the workers*)
      let singles =
        (if Fee.Unsigned.(equal zero delta) then [] else [ (t.public_key, delta) ])
        @ List.map completed_works ~f:(fun (_, fee, worker) -> (worker, fee))
      in
      Fee_transfer.of_single_list singles
    in
    let super_transactions =
      List.map payments ~f:(fun t -> Super_transaction.Transaction t)
      @ List.map fee_transfers ~f:(fun t -> Super_transaction.Fee_transfer t)
    in
    let%bind new_data = update_ledger_and_get_statements t.ledger super_transactions in
    let%bind () = check_completed_works t completed_works in
    let%bind res_opt = fill_in_completed_work t.scan_state completed_works in
    let%map () = enqueue_data_with_rollback t.scan_state new_data in
    res_opt

  let apply t witness = Result_with_rollback.run (apply t witness)

  let create_diff ~(transactions : transaction.t sequence.t) ~get_completed_works =
    let rec go total_fee acc ts =
      match sequence.next ts with
      | none -> (total_fee, acc)
      | some (t, ts) ->
        t
    in
    go
end
