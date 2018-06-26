open Protocols
open Core_kernel
open Async_kernel
open Protocols
open MoreLabels

module type S = sig
  type work

  type proof

  type fee

  type t

  val create_pool : unit -> t

  val add_seller : t -> work:work -> proof:proof -> fee:fee -> unit

  val request_proof_price : t -> work -> (proof * fee) option

  val add_unsolved_work : t -> work -> unit

  val request_work : t -> work option
end

module Make
    (Proof : Coda_pow.Proof_intf)
    (Fee : Comparable.S) (Work : sig
        type t [@@deriving sexp, bin_io]

        val gen : t Quickcheck.Generator.t

        include Hashable.S_binable with type t := t
    end) :
  S
  with type work := Work.t
   and type proof := Proof.t
   and type fee := Fee.t =
struct
  module WorkRandomSet = Random_set.Make (Work)

  type t =
    { min_proof_pool: (Proof.t * Fee.t) Work.Table.t
    ; solved_work_set: WorkRandomSet.t
    ; unsolved_work_pool: WorkRandomSet.t }

  let create_pool () =
    { min_proof_pool= Work.Table.create ()
    ; solved_work_set= WorkRandomSet.create ()
    ; unsolved_work_pool= WorkRandomSet.create () }

  let add_seller t ~work ~proof ~fee =
    Option.iter (Work.Table.find t.min_proof_pool work) ~f:
      (fun (existing_proof, exisiting_fee) ->
        let smallest_fee = min exisiting_fee fee in
        Work.Table.set t.min_proof_pool work (existing_proof, smallest_fee) ;
        WorkRandomSet.add t.solved_work_set work )

  let request_proof_price t = Work.Table.find t.min_proof_pool

  let add_unsolved_work t = WorkRandomSet.add t.unsolved_work_pool

  let request_work t =
    match WorkRandomSet.get_random t.unsolved_work_pool with
    | None -> (
      match WorkRandomSet.get_random t.solved_work_set with
      | None -> None
      | Some work ->
          WorkRandomSet.remove t.solved_work_set work ;
          Work.Table.remove t.min_proof_pool work ;
          Some work )
    | Some work ->
        WorkRandomSet.remove t.unsolved_work_pool work ;
        Some work
end
