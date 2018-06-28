open Protocols
open Core_kernel
open Async_kernel
open Coda_pow

module type S = sig
  type work

  type proof

  type fee

  type priced_proof

  type t

  val create_pool : unit -> t

  val add_snark : t -> work:work -> proof:proof -> fee:fee -> unit

  val request_proof : t -> work -> priced_proof option

  val add_unsolved_work : t -> work -> unit

  (* TODO: Include my_fee as a paramter for request work and 
          return work that has a fee less than my_fee if the 
          returned work does not have any unsolved work *)

  val request_work : t -> work option
end

module Make (Proof : sig
  type t [@@deriving sexp]

  val gen : t Quickcheck.Generator.t

  include Proof_intf with type t := t
end) (Fee : sig
  type t [@@deriving sexp]

  val gen : t Quickcheck.Generator.t

  include Comparable.S with type t := t
end) (Work : sig
  type t [@@deriving sexp, bin_io]

  val gen : t Quickcheck.Generator.t

  include Hashable.S_binable with type t := t
end) (Priced_proof : sig
  type t = {proof: Proof.t; fee: Fee.t}

  include Snark_pool_proof_intf with type proof := Proof.t and type t := t
end) :
  S
  with type work := Work.t
   and type proof := Proof.t
   and type fee := Fee.t
   and type priced_proof := Priced_proof.t =
struct
  module Work_random_set = Random_set.Make (Work)

  type t =
    { proofs: Priced_proof.t Work.Table.t
    ; solved_work: Work_random_set.t
    ; unsolved_work: Work_random_set.t }
  [@@deriving sexp, bin_io]

  let create_pool () =
    { proofs= Work.Table.create ()
    ; solved_work= Work_random_set.create ()
    ; unsolved_work= Work_random_set.create () }

  let add_snark t ~work ~proof ~fee =
    let open Option in
    let smallest_priced_proof =
      Work.Table.find t.proofs work
      >>| (fun {proof= existing_proof; fee= existing_fee} ->
            if existing_fee <= fee then
              {Priced_proof.proof= existing_proof; fee= existing_fee}
            else {proof; fee} )
      |> Option.value ~default:{proof; fee}
    in
    Work.Table.set t.proofs work smallest_priced_proof ;
    Work_random_set.add t.solved_work work

  let request_proof t = Work.Table.find t.proofs

  let add_unsolved_work t = Work_random_set.add t.unsolved_work

  let remove_solved_work t work =
    Work_random_set.remove t.solved_work work ;
    Work.Table.remove t.proofs work

  (* TODO: We request a random piece of work if there is unsolved work. 
           If there is no unsolved work, then we choose a uniformly random 
           piece of work from the solved work pool. We need to use different
           heuristics since there will be high contention when the work pool is small.
           See issue #276 *)
  let request_work t =
    let ( |? ) maybe default =
      match maybe with Some v -> Some v | None -> Lazy.force default
    in
    let open Option.Let_syntax in
    (let%map work = Work_random_set.get_random t.unsolved_work in
     Work_random_set.remove t.unsolved_work work ;
     work)
    |? lazy
         (let%map work = Work_random_set.get_random t.solved_work in
          remove_solved_work t work ; work)

  let gen =
    let open Quickcheck in
    let open Quickcheck.Generator.Let_syntax in
    let gen_entry () =
      Quickcheck.Generator.tuple3 Work.gen Proof.gen Fee.gen
    in
    let%map sample_solved_work = Quickcheck.Generator.list (gen_entry ())
    and sample_unsolved_solved_work = Quickcheck.Generator.list Work.gen in
    let pool = create_pool () in
    List.iter sample_solved_work ~f:(fun (work, proof, fee) ->
        add_snark pool work proof fee ) ;
    List.iter sample_unsolved_solved_work ~f:(fun work ->
        add_unsolved_work pool work ) ;
    pool

  let%test_unit "When two priced proofs of the same work are inserted into \
                 the snark pool, the fee of the work is at most the minimum \
                 of those fees" =
    let gen_entry () = Quickcheck.Generator.tuple2 Proof.gen Fee.gen in
    Quickcheck.test
      ~sexp_of:[%sexp_of : t * Work.t * (Proof.t * Fee.t) * (Proof.t * Fee.t)]
      (Quickcheck.Generator.tuple4 gen Work.gen (gen_entry ()) (gen_entry ()))
      ~f:(fun (t, work, (proof_1, fee_1), (proof_2, fee_2)) ->
        add_snark t work proof_1 fee_1 ;
        add_snark t work proof_2 fee_2 ;
        let fee_upper_bound = Fee.min fee_1 fee_2 in
        let {Priced_proof.fee; _} = Option.value_exn (request_proof t work) in
        assert (fee <= fee_upper_bound) )

  let%test_unit "A priced proof of a work will replace an existing priced \
                 proof of the same work only if it's fee is smaller than the \
                 existing priced proof" =
    Quickcheck.test
      ~sexp_of:[%sexp_of : t * Work.t * Fee.t * Fee.t * Proof.t * Proof.t]
      (Quickcheck.Generator.tuple6 gen Work.gen Fee.gen Fee.gen Proof.gen
         Proof.gen) ~f:
      (fun (t, work, fee_1, fee_2, cheap_proof, expensive_proof) ->
        remove_solved_work t work ;
        let expensive_fee = max fee_1 fee_2 and cheap_fee = min fee_1 fee_2 in
        add_snark t work cheap_proof cheap_fee ;
        add_snark t work expensive_proof expensive_fee ;
        assert (
          {Priced_proof.fee= cheap_fee; proof= cheap_proof}
          = Option.value_exn (request_proof t work) ) )

  let%test_unit "Remove unsolved work if unsolved work pool is not empty" =
    Quickcheck.test ~sexp_of:[%sexp_of : t * Work.t]
      (Quickcheck.Generator.tuple2 gen Work.gen) ~f:(fun (t, work) ->
        let open Quickcheck.Generator.Let_syntax in
        add_unsolved_work t work ;
        let size = Work_random_set.length t.unsolved_work in
        ignore @@ request_work t ;
        assert (size - 1 = Work_random_set.length t.unsolved_work) )
end

let%test_module "random set test" =
  ( module struct
    module Mock_proof = struct
      type input = Int.t

      type t = Int.t [@@deriving sexp, bin_io]

      let verify _ _ = return true

      let gen = Int.gen
    end

    module Mock_Priced_proof = struct
      type t = {proof: Mock_proof.t; fee: Int.t} [@@deriving sexp, bin_io]

      let proof t = t.proof

      type proof = Mock_proof.t

      type fee = Int.t
    end

    module Mock_snark_pool = Make (Mock_proof) (Int) (Int) (Mock_Priced_proof)
  end )
