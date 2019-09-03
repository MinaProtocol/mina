open Core_kernel
open Async_kernel
open Coda_base
open Pipe_lib

module Priced_proof = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type 'proof t = {proof: 'proof; fee: Fee_with_prover.Stable.V1.t}
        [@@deriving bin_io, sexp, fields, yojson, version]
      end

      include T
    end

    module Latest = V1
  end

  type 'proof t = 'proof Stable.Latest.t =
    {proof: 'proof; fee: Fee_with_prover.Stable.V1.t}
end

module type Transition_frontier_intf = sig
  type 'a transaction_snark_work_statement_table

  type t

  val snark_pool_refcount_pipe :
       t
    -> (int * int transaction_snark_work_statement_table)
       Pipe_lib.Broadcast_pipe.Reader.t
end

module type S = sig
  type ledger_proof

  type work

  type transition_frontier

  type t [@@deriving bin_io]

  val create :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> frontier_broadcast_pipe:transition_frontier Option.t
                               Broadcast_pipe.Reader.t
    -> t

  val add_snark :
       t
    -> work:work
    -> proof:ledger_proof list
    -> fee:Fee_with_prover.t
    -> [`Rebroadcast | `Don't_rebroadcast]

  val request_proof : t -> work -> ledger_proof list Priced_proof.t option

  val listen_to_frontier_broadcast_pipe :
    transition_frontier option Broadcast_pipe.Reader.t -> t -> unit
end

module Make (Ledger_proof : sig
  type t [@@deriving bin_io, sexp, version]
end) (Work : sig
  type t [@@deriving sexp]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io]

        include Hashable.S_binable with type t := t
      end
    end
    with type V1.t = t

  include Hashable.S with type t := t
end)
(Transition_frontier : Transition_frontier_intf with type 'a transaction_snark_work_statement_table := 'a Work.Table.t) : sig
  include
    S
    with type work := Work.t
     and type transition_frontier := Transition_frontier.t
     and type ledger_proof := Ledger_proof.t

  val sexp_of_t : t -> Sexp.t

  val remove_solved_work : t -> Work.t -> unit
end = struct
  (* TODO : Version this type *)
  type t =
    { snark_table:
        Ledger_proof.t list Priced_proof.Stable.V1.t Work.Stable.V1.Table.t
    ; mutable ref_table: int Work.Stable.V1.Table.t option }
  [@@deriving sexp, bin_io]

  (* shadow generated bin_io code so that ref table is always None when written *)

  let bin_write_t buf ~pos t =
    let t_no_ref_tbl = {t with ref_table= None} in
    bin_write_t buf ~pos t_no_ref_tbl

  let bin_writer_t = Bin_prot.Type_class.{size= bin_size_t; write= bin_write_t}

  let removed_breadcrumb_wait = 10

  let listen_to_frontier_broadcast_pipe frontier_broadcast_pipe (t : t) =
    (* start with empty ref table *)
    t.ref_table <- None ;
    let tf_deferred =
      Broadcast_pipe.Reader.iter frontier_broadcast_pipe ~f:(function
        | Some tf ->
            (* Start the count at the max so we flush after reconstructing the transition_frontier *)
            let removedCounter = ref removed_breadcrumb_wait in
            let pipe = Transition_frontier.snark_pool_refcount_pipe tf in
            let deferred =
              Broadcast_pipe.Reader.iter pipe
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

  let create ~logger:_ ~trust_system:_ ~frontier_broadcast_pipe =
    let t = {snark_table= Work.Table.create (); ref_table= None} in
    listen_to_frontier_broadcast_pipe frontier_broadcast_pipe t ;
    t

  (** True when there is no active transition_frontier or
      when the refcount for the given work is 0 *)
  let work_is_referenced t work =
    match t.ref_table with
    | None ->
        true
    | Some ref_table -> (
      match Work.Table.find ref_table work with
      | None ->
          false
      | Some _ ->
          true )

  let add_snark t ~work ~proof ~fee =
    if work_is_referenced t work then
      let update_and_rebroadcast () =
        Hashtbl.set t.snark_table ~key:work ~data:{proof; fee} ;
        `Rebroadcast
      in
      match Work.Table.find t.snark_table work with
      | None ->
          update_and_rebroadcast ()
      | Some prev ->
          if Currency.Fee.( < ) fee.fee prev.fee.fee then
            update_and_rebroadcast ()
          else `Don't_rebroadcast
    else `Don't_rebroadcast

  let request_proof t = Work.Table.find t.snark_table

  let remove_solved_work t = Work.Table.remove t.snark_table
end

include Make (Ledger_proof.Stable.V1) (Transaction_snark_work.Statement)
          (Transition_frontier)

let%test_module "random set test" =
  ( module struct
    module Mock_proof = struct
      module Stable = struct
        module V1 = struct
          module T = struct
            type t = int [@@deriving bin_io, sexp, version {unnumbered}]
          end

          include T
        end
      end

      include Stable.V1.T
    end

    module Mock_work = struct
      (* no bin_io except in Stable versions *)
      module T = struct
        type t = Int.t [@@deriving sexp, hash, compare]

        let gen = Int.quickcheck_generator
      end

      include T
      include Hashable.Make (T)

      module Stable = struct
        module V1 = Int
      end
    end

    module Mock_transition_frontier = struct
      type t = string

      let create () : t = ""

      module Extensions = struct
        module Snark_pool_refcount = struct
          module Work = Mock_work
        end
      end

      let snark_pool_refcount_pipe _ =
        let reader, _writer =
          Pipe_lib.Broadcast_pipe.create
            (0, Extensions.Snark_pool_refcount.Work.Table.create ())
        in
        reader
    end

    module Mock_snark_pool =
      Make (Mock_proof) (Mock_work) (Mock_transition_frontier)

    let gen =
      let open Quickcheck.Generator.Let_syntax in
      let gen_entry =
        Quickcheck.Generator.tuple2 Mock_work.gen Fee_with_prover.gen
      in
      let%map sample_solved_work = Quickcheck.Generator.list gen_entry in
      let frontier_broadcast_pipe_r, _ =
        Broadcast_pipe.create (Some (Mock_transition_frontier.create ()))
      in
      let pool =
        Mock_snark_pool.create ~logger:(Logger.null ())
          ~trust_system:(Trust_system.null ())
          ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
      in
      List.iter sample_solved_work ~f:(fun (work, fee) ->
          ignore (Mock_snark_pool.add_snark pool ~work ~proof:[] ~fee) ) ;
      pool

    let%test_unit "When two priced proofs of the same work are inserted into \
                   the snark pool, the fee of the work is at most the minimum \
                   of those fees" =
      Quickcheck.test
        ~sexp_of:
          [%sexp_of:
            Mock_snark_pool.t
            * Mock_work.t
            * Fee_with_prover.t
            * Fee_with_prover.t]
        (Quickcheck.Generator.tuple4 gen Mock_work.gen Fee_with_prover.gen
           Fee_with_prover.gen) ~f:(fun (t, work, fee_1, fee_2) ->
          ignore (Mock_snark_pool.add_snark t ~work ~proof:[] ~fee:fee_1) ;
          ignore (Mock_snark_pool.add_snark t ~work ~proof:[] ~fee:fee_2) ;
          let fee_upper_bound = Currency.Fee.min fee_1.fee fee_2.fee in
          let {Priced_proof.fee= {fee; _}; _} =
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
            * Fee_with_prover.t
            * Fee_with_prover.t]
        (Quickcheck.Generator.tuple4 gen Mock_work.gen Fee_with_prover.gen
           Fee_with_prover.gen) ~f:(fun (t, work, fee_1, fee_2) ->
          Mock_snark_pool.remove_solved_work t work ;
          let expensive_fee = max fee_1 fee_2
          and cheap_fee = min fee_1 fee_2 in
          ignore (Mock_snark_pool.add_snark t ~work ~proof:[] ~fee:cheap_fee) ;
          assert (
            Mock_snark_pool.add_snark t ~work ~proof:[] ~fee:expensive_fee
            = `Don't_rebroadcast ) ;
          assert (
            cheap_fee.fee
            = (Option.value_exn (Mock_snark_pool.request_proof t work)).fee.fee
          ) )
  end )
