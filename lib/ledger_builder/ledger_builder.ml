open Core_kernel
open Async_kernel
open Nanobit_base
open Protocols

module Work = struct
  type ('a, 'd) work_item = Base of 'd | Merge of 'a * 'a
  [@@deriving sexp, bin_io]

  let max_length' = 8

  type ('a, 'd) t =
    { max_length:
        int
        (* max number of items should always be of the this length.
    Currently length = 8 *)
    ; items: ('a, 'd) work_item list }
  [@@deriving sexp, bin_io]

  let gen txns =
    let () = assert (List.length txns = max_length') in
    let addto work t' =
      {max_length= work.max_length; items= Base t' :: work.items}
    in
    let init_work = {max_length= 8; items= []} in
    List.fold txns ~init:init_work ~f:addto
end

module Make (Proof : sig
  include Coda_pow.Snark_pool_proof_intf

  include Sexpable with type t := t
end) (Transaction : sig
  include Coda_pow.Transaction_intf

  include Sexpable with type t := t
  (*[@@deriving sexp] , bin_io, eq] *)
end)
(Public_key : Coda_pow.Public_Key_intf) (Fee : sig
    type t [@@deriving sexp]
end) (Fee_transfer : sig
  include Coda_pow.Fee_transfer_intf
          with type public_key := Public_key.t
           and type fee := Fee.t
end) (Super_transaction : sig
  include Coda_pow.Super_transaction_intf
          with type valid_transaction := Transaction.With_valid_signature.t
           and type fee_transfer := Fee_transfer.t
end) (Ledger : sig
  include Coda_pow.Ledger_intf
          with type valid_transaction := Transaction.With_valid_signature.t
           and type super_transaction := Super_transaction.t

  val apply_fee_transfer : t -> Fee_transfer.t -> unit Or_error.t
end) (Witness : sig
  include Coda_pow.Ledger_builder_witness_intf
          with type transaction := Transaction.With_valid_signature.t
end) (Snark_pool : sig
  type t

  type work = (Proof.t * Fee.t, Super_transaction.t) Work.work_item

  type proof_fee = Proof.t * Fee.t

  val request_proof : t -> work -> proof_fee option

  val request_work : t -> work option

  val add_work : t -> work -> unit

  val get : t
end) (Ledger_hash : sig
  include Coda_pow.Ledger_hash_intf with type t = Ledger.ledger_hash
end) =
struct
  open Work

  module Ledger_builder_update = struct
    type t =
      { super_transactions: Super_transaction.t list
      ; prev_ledger_hash: Ledger_hash.t
      ; self_pk: Public_key.t }

    let verify t : bool = true

    (* Transaction_fee*)
  end

  type leaf = Super_transaction.t [@@deriving sexp_of]

  (*Need transaction list corresponding to each proof to update the ledger*)
  type node = Proof.t * Fee.t * leaf list [@@deriving sexp_of]

  let snark_pool = Snark_pool.get

  type t =
    { ledger: Ledger.t
    ; scan_state: (node, node, leaf) Parallel_scan.State.t
    ; lb_update: Ledger_builder_update.t }

  (*[@@deriving sexp, bin_io, eq]*)

  type ledger_hash = Ledger.ledger_hash

  type ledger_proof = Proof.t

  let payment_transitions payments =
    List.map payments Super_transaction.from_transaction

  let fee_transitions fee_transfers =
    List.map fee_transfers Super_transaction.from_fee_transfer

  let transitions payments fee_transfers =
    List.append
      (List.map payments payment_transitions)
      (List.map fee_transfers fee_transitions)

  module Config = struct
    type t =
      { ledger: Ledger.t
      ; snark_pool: Snark_pool.t
      ; init_state: (node, node, leaf) Parallel_scan.State.t
      ; witness: Witness.t
      ; self_pk: Public_key.t }
  end

  let create (config: Config.t) =
    let ledger_hash = Ledger.merkle_root config.ledger in
    let update : Ledger_builder_update.t =
      { super_transactions= []
      ; prev_ledger_hash= ledger_hash
      ; self_pk= config.self_pk }
    in
    {ledger= config.ledger; scan_state= config.init_state; lb_update= update}

  let copy t =
    {ledger= t.ledger; scan_state= t.scan_state; lb_update= t.lb_update}

  module Spec = struct
    (*let rec combine = fun t t' -> match (t, t') with (*failwith "TODO"*)
      | (Base x, Base x') -> Merge (lift x, lift x')
      | (Merge (x, x'), Merge (y, y')) ->  
          Merge (merge_proof x x', merge_proof y y')
      | _ -> failwith "TODO"*)

    let prover work =
      match Snark_pool.request_proof snark_pool work with
      | None -> failwith "TODO"
      | Some p -> p

    module Accum = struct
      type t = node [@@deriving sexp_of]

      let fst (a, b, c) = a

      let snd (a, b, c) = b

      let thrd (a, b, c) = c

      let ( + ) t t' =
        let proof, fee = prover (Merge ((fst t, snd t), (fst t', snd t'))) in
        return (proof, fee, List.append (thrd t) (thrd t'))
    end

    module Data = struct
      type t = leaf [@@deriving sexp_of]
    end

    module Output = struct
      type t = node [@@deriving sexp_of]
    end

    let lift t = Snark_pool.request_work snark_pool

    let merge t t' = return t'

    let map (x: Data.t) : Accum.t Deferred.t =
      let proof, fee = prover (Base x) in
      return (proof, fee, [x])

    (* TODO already retieving to create fee transfers*)
    (*??*)
  end

  let spec =
    ( module Spec
    : Parallel_scan.Spec_intf with type Data.t = leaf and type Accum.t = node and type 
      Output.t = node )

  let copy t = failwith "TODO"

  let retrieve_from_pool (work: ('a, 'd) Work.t) no :
      (('a, 'd) Work.work_item * Snark_pool.proof_fee option) list =
    List.zip_exn work.items
      (List.map work.items ~f:(Snark_pool.request_proof snark_pool))

  (* using exn because we know for sure both the lists are of same size *)

  let proven_transactions proofs =
    List.filter_map proofs ~f:(fun x ->
        match x with Base t, Some p -> Some t | _ -> None )

  let fee_transfer (lb_update: Ledger_builder_update.t) from_snark :
      Fee_transfer.t option =
    match from_snark with
    | _, None -> None
    | _, Some (_, fee) ->
        Some (Fee_transfer.fee_transfer lb_update.self_pk fee)

  let apply t witness :
      (t * (ledger_hash * ledger_proof) option) Deferred.Or_error.t =
    let ts =
      List.map
        (Witness.transactions witness)
        Super_transaction.from_transaction
    in
    let work_list = gen ts in
    let snarks =
      retrieve_from_pool work_list (work_list.max_length * List.length ts)
    in
    let fee_transfers = List.filter_map snarks (fee_transfer t.lb_update) in
    let final_list =
      List.append
        (proven_transactions snarks)
        (List.map fee_transfers Super_transaction.from_fee_transfer)
    in
    let can_include = Ledger_builder_update.verify final_list in
    let%bind final_proof = Parallel_scan.step t.scan_state final_list spec in
    match final_proof with
    | None -> return @@ Ok (t, None)
    | Some (proof, fee, txns') ->
        match%bind
          Deferred.List.fold txns' (Ok ()) (fun r t' ->
              return @@ Ledger.apply_super_transaction t.ledger t' )
        with
        | Ok () -> return @@ Ok (t, Some (Ledger.merkle_root t.ledger, proof))
        | Error e -> return @@ Error e
end
