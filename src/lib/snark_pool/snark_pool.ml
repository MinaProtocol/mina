open Core_kernel
open Async_kernel
open Pipe_lib

(* TODO: fold Priced_proof underneath Proof *)
module Priced_proof = struct
  type ('proof, 'fee) t = {proof: 'proof; fee: 'fee}
  [@@deriving bin_io, sexp, fields]
end

module type Inputs_intf = sig
  module Proof : Binable.S

  module Fee : sig
    type t
    include Binable.S with type t := t
    include Comparable.S with type t := t
    include Sexpable.S with type t := t
    val gen : t Quickcheck.Generator.t
  end

  module Statement : sig
    type t
    include Binable.S with type t := t
    include Hashable.S_binable with type t := t
    include Sexpable.S with type t := t
  end

  module Work : sig
    type t
    include Binable.S with type t := t
    include Hashable.S_binable with type t := t
    include Sexpable.S with type t := t
    val gen : t Quickcheck.Generator.t
    val statements : t -> Statement.t list
  end
end

module type S = sig
  type statement

  type work

  type proof

  type fee

  type t [@@deriving bin_io]

  val create :
       parent_log:Logger.t
    -> relevant_statement_changes_reader:(statement, int) List.Assoc.t Linear_pipe.Reader.t
    -> t

  val add_snark :
       t
    -> work:work
    -> proof:proof
    -> fee:fee
    -> [`Rebroadcast | `Don't_rebroadcast]

  val request_proof : t -> work -> (proof, fee) Priced_proof.t option
end

module Make
    (Inputs : Inputs_intf)
  : S
    with type work := Inputs.Work.t
     and type statement := Inputs.Statement.t
     and type proof := Inputs.Proof.t
     and type fee := Inputs.Fee.t = struct
  open Inputs

  module Priced_proof = struct
    type t = (Proof.t sexp_opaque, Fee.t) Priced_proof.t
    [@@deriving sexp, bin_io]

    let create proof fee : (Proof.t, Fee.t) Priced_proof.t = {proof; fee}

    (* let proof (t : t) = t.proof *)

    let fee (t : t) = t.fee
  end

  type t =
    { statement_ref_count_table: int Statement.Table.t
    ; work_proof_table: Priced_proof.t Work.Table.t }
  [@@deriving sexp, bin_io]

  let create ~parent_log ~relevant_statement_changes_reader =
    let logger = Logger.child parent_log "Snark_pool" in
    let statement_ref_count_table = Statement.Table.create () in
    let work_proof_table = Work.Table.create () in
    don't_wait_for (
      Linear_pipe.iter relevant_statement_changes_reader ~f:(fun changes ->
        List.iter changes ~f:(fun (statement, ref_count_diff) ->
          Hashtbl.incr
            ~remove_if_zero:true
            statement_ref_count_table
            statement
            ~by:ref_count_diff;
          let ref_count = Hashtbl.find_exn statement_ref_count_table statement in
          (if ref_count < 0 then (
            Logger.warn logger "Snark_pool statement ref count went below 0 (this shouldn't happen)");
            Hashtbl.remove statement_ref_count_table statement));
        Deferred.return ()));
    {statement_ref_count_table; work_proof_table}

  let add_snark {statement_ref_count_table; work_proof_table} ~work ~proof ~fee =
    let save_proof () = Hashtbl.set work_proof_table ~key:work ~data:(Priced_proof.create proof fee) in
    if
      List.for_all (Work.statements work) ~f:(fun stmt ->
        Hashtbl.find statement_ref_count_table stmt
        |> Option.map ~f:(fun ref_count -> ref_count > 0)
        |> Option.value ~default:false)
    then
      (match Hashtbl.find work_proof_table work with
      | None -> save_proof (); `Rebroadcast
      | Some prev_proof ->
          if Fee.( < ) fee (Priced_proof.fee prev_proof) then
            (save_proof (); `Rebroadcast)
          else
            `Don't_rebroadcast)
    else
      `Don't_rebroadcast

  let request_proof {work_proof_table; _} = Work.Table.find work_proof_table
end

let%test_module "random set test" =
  ( module struct
    module Mocks = struct
      module Proof = struct
        type t = Int.t [@@deriving sexp, bin_io]

        let gen = Int.gen
      end

      module Fee = Int

      module Statement = Int

      module Work = struct
        module T = struct
          type t = Statement.t list
          [@@deriving sexp, bin_io, hash, compare]
        end

        include T
        include Hashable.Make_binable(T)

        let gen = List.gen Int.gen

        let statements = Fn.id
      end
    end

    module Mock_snark_pool = Make (Mocks)

    let%test_unit "When two priced proofs of the same work are inserted into \
                   the snark pool, the fee of the work is at most the minimum \
                   of those fees" =
      let gen_entry () =
        Quickcheck.Generator.tuple2 Mocks.Proof.gen Mocks.Fee.gen
      in
      Quickcheck.test
        ~sexp_of:
          [%sexp_of
            :   Mocks.Work.t
              * (Mocks.Proof.t * Mocks.Fee.t)
              * (Mocks.Proof.t * Mocks.Fee.t)]
        (Quickcheck.Generator.tuple3 Mocks.Work.gen (gen_entry ())
           (gen_entry ()))
        ~f:(fun (work, (proof_1, fee_1), (proof_2, fee_2)) ->
          let t =
            Mock_snark_pool.create
              ~parent_log:(Logger.create ())
              ~relevant_statement_changes_reader:(Linear_pipe.create_reader ~close_on_exception:false (fun _ -> Deferred.return ()))
          in
          ignore (Mock_snark_pool.add_snark t ~work ~proof:proof_1 ~fee:fee_1) ;
          ignore (Mock_snark_pool.add_snark t ~work ~proof:proof_2 ~fee:fee_2) ;
          let fee_upper_bound = Mocks.Fee.min fee_1 fee_2 in
          let {Priced_proof.fee; _} =
            Option.value_exn (Mock_snark_pool.request_proof t work)
          in
          assert (fee <= fee_upper_bound) )

    let%test_unit "A priced proof of a work will replace an existing priced \
                   proof of the same work only if it's fee is smaller than \
                   the existing priced proof" =
      Quickcheck.test
        ~sexp_of:
          [%sexp_of
            :   Mocks.Work.t
              * Mocks.Fee.t
              * Mocks.Fee.t
              * Mocks.Proof.t
              * Mocks.Proof.t]
        (Quickcheck.Generator.tuple5 Mocks.Work.gen Mocks.Fee.gen
           Mocks.Fee.gen Mocks.Proof.gen Mocks.Proof.gen) ~f:
        (fun (work, fee_1, fee_2, cheap_proof, expensive_proof) ->
          let t =
            Mock_snark_pool.create
              ~parent_log:(Logger.create ())
              ~relevant_statement_changes_reader:(Linear_pipe.create_reader ~close_on_exception:false (fun _ -> Deferred.return ()))
          in
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
  end )
