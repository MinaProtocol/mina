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
(Fee_transfer : Coda_pow.Fee_transfer_intf) (Super_transaction : sig
    include Coda_pow.Super_transaction_intf
end) (Ledger : sig
  include Coda_pow.Ledger_intf
          with type valid_transaction := Transaction.With_valid_signature.t
           and type super_transaction := Super_transaction.t

  val apply_fee_transfer : t -> Fee_transfer.t -> unit Or_error.t
end) (Witness : sig
  include Coda_pow.Ledger_builder_witness_intf
          with type transaction := Transaction.With_valid_signature.t
end) (Fee : sig
  type t [@@deriving sexp]
end) (Snark_pool : sig
  type t

  type work = (Proof.t * Fee.t, Super_transaction.t) Work.t

  val request_proof : t -> work -> (Proof.t * Fee.t) option

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
      { payments: Transaction.With_valid_signature.t list
      ; fee_transfers: Fee_transfer.t list
      ; prev_ledger_hash: Ledger_hash.t
      ; self_pk: Public_key.Compressed.t }

    let verify t : bool = true
  end

  type leaf = Super_transaction.t [@@deriving sexp_of]

  (*Need transaction list to update the ledger*)
  type node = Proof.t * Fee.t * leaf list [@@deriving sexp_of]

  let snark_pool = Snark_pool.get

  type t =
    { ledger: Ledger.t
    ; scan_state: (node, node, leaf) Parallel_scan.State.t
    ; lb_update: Ledger_builder_update.t }

  (*[@@deriving sexp, bin_io, eq]*)

  type ledger_hash = Ledger.ledger_hash

  type ledger_proof = Proof.t

  type snark_data = Proof.t * Fee.t * Public_key.Compressed.t

  let payment_transitions payments = failwith "TODO"

  let fee_transitions fee_transfers = failwith "TODO"

  let transitions payments fee_transfers = failwith "TODO"

  module Config = struct
    type t =
      { ledger: Ledger.t
      ; snark_pool: Snark_pool.t
      ; init_state: (node, node, leaf) Parallel_scan.State.t
      ; witness: Witness.t
      ; self_pk: Public_key.Compressed.t }
  end

  let snark_fees payments : Fee_transfer.t list = failwith "TODO"

  let create (config: Config.t) =
    let payments = Witness.transactions config.witness in
    let fees = snark_fees payments in
    let ledger_hash = Ledger.merkle_root config.ledger in
    let update : Ledger_builder_update.t =
      { payments
      ; fee_transfers= fees
      ; prev_ledger_hash= ledger_hash
      ; self_pk= config.self_pk }
    in
    {ledger= config.ledger; scan_state= config.init_state; lb_update= update}

  let copy t = failwith "TODO"

  module Spec = struct
    (*let rec combine = fun t t' -> match (t, t') with (*failwith "TODO"*)
      | (Base x, Base x') -> Merge (lift x, lift x')
      | (Merge (x, x'), Merge (y, y')) ->  
          Merge (merge_proof x x', merge_proof y y')
      | _ -> failwith "TODO"*)

    let prover work =
      match Snark_pool.request_proof snark_pool work with
      | None -> failwith "TODO"
      | Some p -> return p

    module Accum = struct
      type t = node [@@deriving sexp_of]

      let fst (a, b, c) = a

      let snd (a, b, c) = b

      let thrd (a, b, c) = c

      let ( + ) t t' =
        let%bind proof, fee =
          prover
            { max_length= max_length'
            ; items= [Merge ((fst t, snd t), (fst t', snd t'))] }
        in
        return (proof, fee, List.append (thrd t) (thrd t'))
    end

    module Data = struct
      type t = leaf [@@deriving sexp_of]
    end

    module Output = struct
      type t = node [@@deriving sexp_of]
    end

    let lift t = Snark_pool.request_work snark_pool

    let prover work : snark_data = failwith "TODO"

    let merge t t' = return t'

    let map (x: Data.t) : Accum.t Deferred.t =
      match
        Snark_pool.request_proof snark_pool
          {max_length= max_length'; items= [Base x]}
      with
      | None -> failwith "TODO"
      | Some (proof, fee) -> return (proof, fee, [x])

    (*??*)
  end

  let spec =
    ( module Spec
    : Parallel_scan.Spec_intf with type Data.t = leaf and type Accum.t = node and type 
      Output.t = node )

  let copy t = failwith "TODO"

  let retrieve_from_pool no : snark_data list = failwith "TODO"

  let create_transaction (proof, fee, addr) : leaf = failwith "TODO"

  (* let receiver_compressed = Public_key.compress addr in
    let sender_kp = Signature_keypair.of_private_key Config.t.private_key in
    failwith "TODO" 
*)
  (*let sign_txns ts : Transaction.With_valid_signature.t list = failwith "TODO"*)
  (* Deferred.List.fold
  let rec apply_txns t txns : unit Core_kernel.Or_error.t= 
    match txns with
    | []        -> Ok ()
    | (t':: ts) ->
    let open Or_error.Let_syntax in 
    let%bind () = Ledger.apply_transaction t.ledger t' in
    apply_txns t ts *)
  (*let apply_transition ledger transition = match transition with 
   | Transaction_snark.Transition.Transaction txn ->  
        return @@ (Ok ())(*Ledger.apply_transaction ledger txn *) 
   | Transaction_snark.Transition.Fee_transfer ft ->
        return @@ Ledger.apply_fee_transfer ledger ft *)

  let apply t witness :
      (t * (ledger_hash * ledger_proof) option) Deferred.Or_error.t =
    let ts = Witness.transactions witness in
    let work_list = gen ts in
    let snarks = retrieve_from_pool (work_list.max_length * List.length ts) in
    let fee_transfers : leaf list = List.map snarks create_transaction in
    let valid_list = transitions ts fee_transfers in
    let%bind final_proof = Parallel_scan.step t.scan_state valid_list spec in
    match final_proof with
    | None -> return @@ Ok (t, None)
    | Some (proof, fee, txns') ->
        match%bind
          Deferred.List.fold txns' (Ok ()) (fun r t' ->
              return @@ Ledger.apply_super_transaction t.ledger t' )
        with
        | Ok () -> return @@ Ok (t, Some (Ledger.merkle_root t.ledger, proof))
        | Error e -> return @@ Error e

  (*how do you fold when things mutate?*)
end
