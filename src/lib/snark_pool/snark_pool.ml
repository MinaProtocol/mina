open Core_kernel
open Async_kernel
open Pipe_lib

module Priced_proof = struct
  type ('proof, 'fee) t = {proof: 'proof; fee: 'fee}
  [@@deriving bin_io, sexp, fields]
end

module type Transition_frontier_intf = sig
  type t

  module Extensions :
    Protocols.Coda_transition_frontier.Transition_frontier_extensions_intf

  val extension_pipes : t -> Extensions.readers
end

module type S = sig
  type work

  type proof

  type fee

  type transition_frontier

  type t [@@deriving bin_io]

  val create :
       parent_log:Logger.t
    -> frontier_broadcast_pipe:transition_frontier option
                               Broadcast_pipe.Reader.t
    -> t

  val add_snark :
       t
    -> work:work
    -> proof:proof
    -> fee:fee
    -> [`Rebroadcast | `Don't_rebroadcast]

  val request_proof : t -> work -> (proof, fee) Priced_proof.t option
end

module Make (Proof : sig
  type t [@@deriving bin_io]
end) (Fee : sig
  type t [@@deriving sexp, bin_io]

  include Comparable.S with type t := t
end) (Work : sig
  type t = Transaction_snark.Statement.t list [@@deriving sexp, bin_io]

  include Hashable.S_binable with type t := t
end)
(Transition_frontier : Transition_frontier_intf
                       with module Extensions.Work = Work) :
  sig
    include S

    val sexp_of_t : t -> Sexp.t

    val remove_solved_work : t -> work -> unit
  end
  with type work := Work.t
   and type proof := Proof.t
   and type fee := Fee.t
   and type transition_frontier = Transition_frontier.t = struct
  module Priced_proof = struct
    type t = (Proof.t sexp_opaque, Fee.t) Priced_proof.t
    [@@deriving sexp, bin_io]

    let create proof fee : (Proof.t, Fee.t) Priced_proof.t = {proof; fee}

    let proof (t : t) = t.proof

    let fee (t : t) = t.fee
  end

  type t =
    { snark_table: Priced_proof.t Work.Table.t
    ; mutable ref_table: int Work.Table.t option }
  [@@deriving sexp, bin_io]

  type transition_frontier = Transition_frontier.t

  let removed_breadcrumb_wait = 10

  let listen_to_frontier_broadcast_pipe frontier_broadcast_pipe (t : t) =
    let tf_deferred, _ =
      Broadcast_pipe.Reader.iter frontier_broadcast_pipe ~f:(function
        | Some tf ->
            (* Start the count at the max so we flush after reconstructing the transition_frontier *)
            let removedCounter = ref removed_breadcrumb_wait in
            let pipe = Transition_frontier.extension_pipes tf in
            let deferred, _ =
              Broadcast_pipe.Reader.iter
                pipe.Transition_frontier.Extensions.snark_pool
                ~f:(fun (removed, refcount_table) ->
                  t.ref_table <- Some refcount_table ;
                  removedCounter := !removedCounter + removed ;
                  if !removedCounter < removed_breadcrumb_wait then return ()
                  else (
                    removedCounter := 0 ;
                    return
                      (Work.Table.filter_keys_inplace t.snark_table
                         ~f:(fun work ->
                           Option.is_some (Work.Table.find refcount_table work)
                       )) ) )
            in
            deferred
        | None ->
            t.ref_table <- None ;
            return () )
    in
    Deferred.don't_wait_for tf_deferred

  let create ~parent_log:_ ~frontier_broadcast_pipe =
    let t = {snark_table= Work.Table.create (); ref_table= None} in
    listen_to_frontier_broadcast_pipe frontier_broadcast_pipe t ;
    t

  (** True when there is no active transition_frontier or
    when the refcount for the given work is 0 *)
  let work_is_referenced t work =
    match t.ref_table with
    | None -> true
    | Some ref_table -> (
      match Work.Table.find ref_table work with None -> true | Some _ -> true )

  let add_snark t ~work ~proof ~fee =
    if work_is_referenced t work then
      let update_and_rebroadcast () =
        Hashtbl.set t.snark_table ~key:work
          ~data:(Priced_proof.create proof fee) ;
        `Rebroadcast
      in
      match Work.Table.find t.snark_table work with
      | None -> update_and_rebroadcast ()
      | Some prev ->
          if Fee.( < ) fee prev.fee then update_and_rebroadcast ()
          else `Don't_rebroadcast
    else `Don't_rebroadcast

  let request_proof t = Work.Table.find t.snark_table

  let remove_solved_work t = Work.Table.remove t.snark_table
end

(* let%test_module "random set test" =
  ( module struct
    module Mock_proof = struct
      type input = Int.t

      type t = Int.t [@@deriving sexp, bin_io]

      let verify _ _ = return true

      let gen = Int.gen
    end

    module Mock_transition_frontier = struct
      type t = string

      let create () : t = ""

      module Extensions = struct
        module Work = Int

        module Readers = struct
          type t =
            {snark_pool: int Work.Table.t Pipe_lib.Broadcast_pipe.Reader.t}
        end
      end

      let extension_pipes _ =
        let reader, _writer =
          Pipe_lib.Broadcast_pipe.create (Extensions.Work.Table.create ())
        in
        {Extensions.Readers.snark_pool= reader}
    end

    module Mock_work = Int
    module Mock_fee = Int

    module Mock_Priced_proof = struct
      type proof = Mock_proof.t [@@deriving sexp, bin_io]

      type fee = Mock_fee.t [@@deriving sexp, bin_io]

      type t = {proof: proof; fee: fee} [@@deriving sexp, bin_io]

      let proof t = t.proof
    end

    module Mock_snark_pool =
      Make (Mock_proof) (Mock_fee) (Mock_work) (Mock_transition_frontier)

    let gen =
      let open Quickcheck.Generator.Let_syntax in
      let gen_entry () =
        Quickcheck.Generator.tuple3 Mock_work.gen Mock_work.gen Mock_fee.gen
      in
      let%map sample_solved_work = Quickcheck.Generator.list (gen_entry ()) in
      let frontier_broadcast_pipe_r, _ =
        Broadcast_pipe.create (Some (Mock_transition_frontier.create ()))
      in
      let pool =
        Mock_snark_pool.create ~parent_log:(Logger.create ())
          ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
      in
      List.iter sample_solved_work ~f:(fun (work, proof, fee) ->
          ignore (Mock_snark_pool.add_snark pool ~work ~proof ~fee) ) ;
      pool

    let%test_unit "When two priced proofs of the same work are inserted into \
                   the snark pool, the fee of the work is at most the minimum \
                   of those fees" =
      let gen_entry () =
        Quickcheck.Generator.tuple2 Mock_proof.gen Mock_fee.gen
      in
      Quickcheck.test
        ~sexp_of:
          [%sexp_of:
            Mock_snark_pool.t
            * Mock_work.t
            * (Mock_proof.t * Mock_fee.t)
            * (Mock_proof.t * Mock_fee.t)]
        (Quickcheck.Generator.tuple4 gen Mock_work.gen (gen_entry ())
           (gen_entry ()))
        ~f:(fun (t, work, (proof_1, fee_1), (proof_2, fee_2)) ->
          ignore (Mock_snark_pool.add_snark t ~work ~proof:proof_1 ~fee:fee_1) ;
          ignore (Mock_snark_pool.add_snark t ~work ~proof:proof_2 ~fee:fee_2) ;
          let fee_upper_bound = Mock_fee.min fee_1 fee_2 in
          let {Priced_proof.fee; _} =
            Option.value_exn (Mock_snark_pool.request_proof t work)
          in
          assert (fee <= fee_upper_bound) )

    let%test_unit "A priced proof of a work will replace an existing priced \
                   proof of the same work only if it's fee is smaller than \
                   the existing priced proof" =
      Quickcheck.test
        ~sexp_of:
          [%sexp_of:
            Mock_snark_pool.t
            * Mock_work.t
            * Mock_fee.t
            * Mock_fee.t
            * Mock_proof.t
            * Mock_proof.t]
        (Quickcheck.Generator.tuple6 gen Mock_work.gen Mock_fee.gen
           Mock_fee.gen Mock_proof.gen Mock_proof.gen)
        ~f:(fun (t, work, fee_1, fee_2, cheap_proof, expensive_proof) ->
          Mock_snark_pool.remove_solved_work t work ;
          let expensive_fee = max fee_1 fee_2
          and cheap_fee = min fee_1 fee_2 in
          ignore
            (Mock_snark_pool.add_snark t ~work ~proof:cheap_proof
               ~fee:cheap_fee) ;
          assert (
            Mock_snark_pool.add_snark t ~work ~proof:expensive_proof
              ~fee:expensive_fee
            = `Don't_rebroadcast ) ;
          assert (
            {Priced_proof.fee= cheap_fee; proof= cheap_proof}
            = Option.value_exn (Mock_snark_pool.request_proof t work) ) )
  end ) *)
