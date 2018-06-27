open Protocols
open Core_kernel
open Async_kernel
open Coda_pow

module type S = sig
  type work

  type proof

  type fee

  type pool

  type t

  val create_pool : unit -> t

  val add_snark : t -> work:work -> proof:proof -> fee:fee -> unit

  val request_proof : t -> work -> pool option

  val add_unsolved_work : t -> work -> unit

  (* TODO: Include my_fee as a paramter for request work and 
          return work that has a fee less than my_fee if the 
          returned work does not have any unsolved work *)

  val request_work : t -> work option
end

module Make
    (Proof : Proof_intf)
    (Fee : Comparable.S) (Work : sig
        type t [@@deriving sexp, bin_io]

        val gen : t Quickcheck.Generator.t

        include Hashable.S_binable with type t := t
    end) (Pool : sig
      type t = {proof: Proof.t; fee: Fee.t} [@@deriving fields]

      include Snark_pool_proof_intf with type proof := Proof.t and type t := t
    end) :
  S
  with type work := Work.t
   and type proof := Proof.t
   and type fee := Fee.t
   and type pool := Pool.t =
struct
  module Work_random_set = Random_set.Make (Work)

  type t =
    { proofs: Pool.t Work.Table.t
    ; solved_work: Work_random_set.t
    ; unsolved_work: Work_random_set.t }
  [@@deriving bin_io]

  let create_pool () =
    { proofs= Work.Table.create ()
    ; solved_work= Work_random_set.create ()
    ; unsolved_work= Work_random_set.create () }

  let add_snark t ~work ~proof ~fee =
    Option.iter (Work.Table.find t.proofs work) ~f:
      (fun {proof= existing_proof; fee= existing_fee} ->
        let smallest_fee = min existing_fee fee in
        Work.Table.set t.proofs work {proof= existing_proof; fee= smallest_fee} ;
        Work_random_set.add t.solved_work work )

  let request_proof t = Work.Table.find t.proofs

  let add_unsolved_work t = Work_random_set.add t.unsolved_work

  (* TODO: We request a random piece of work if there is unsolved work. 
           If there is no unsolved work, then we choose a uniformly random 
           piece of work from the solved work pool. We need to use different
           heuristics since there will be high contention when the work pool is small.
           See issue #276 *)
  let request_work t =
    let open Option.Let_syntax in
    let remove_random_unsolved_work =
      let%bind work = Work_random_set.get_random t.unsolved_work in
      Work_random_set.remove t.unsolved_work work ;
      Some (lazy work)
    in
    let%bind work = Work_random_set.get_random t.solved_work in
    return
    @@ lazy
         ( Work_random_set.remove t.solved_work work ;
           Work.Table.remove t.proofs work ;
           work )
    |> Option.first_some remove_random_unsolved_work
    >>| Lazy.force
end
