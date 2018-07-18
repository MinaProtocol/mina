open Core
open Nanobit_base
open Keys_lib
open Async
module Map_reduce = Rpc_parallel.Map_reduce

module type S0 = sig
  type proof

  type t

  val cancel : t -> unit

  val create :
       conf_dir:string
    -> Ledger.t
    -> Transaction.With_valid_signature.t list
    -> Public_key.Compressed.t
    -> t

  val target_hash : t -> Ledger_hash.t

  val result : t -> proof option Deferred.t
end

module type S = sig
  include S0

  module Sparse_ledger = Nanobit_base.Sparse_ledger
end

module T = struct
  type t =
    {result: Transaction_snark.t option Deferred.t; target_hash: Ledger_hash.t}
  [@@deriving fields]
end

include T

module Worker_state = struct
  type t = (module Transaction_snark.S)

  let create () : t Deferred.t =
    let%map keys = Keys.create () in
    let module Keys = (val keys) in
    ( ( module Transaction_snark.Make (struct
        let keys = Keys.transaction_snark_keys
      end) )
    : t )
end

module Sparse_ledger = Nanobit_base.Sparse_ledger

module Input = struct
  type t =
    { transition: Transaction_snark.Transition.t
    ; ledger: Sparse_ledger.t
    ; target_hash: Ledger_hash.Stable.V1.t }
  [@@deriving bin_io]
end

module M = Map_reduce.Make_map_reduce_function_with_init (struct
  module Input = Input
  module Accum = Transaction_snark

  module Param = struct
    type t = unit [@@deriving bin_io]
  end

  open Snark_params
  open Tick

  type state_type = Worker_state.t

  let init () = Worker_state.create ()

  let map ((module T): state_type) {Input.transition; ledger; target_hash} =
    return
      (T.of_transition
         (Sparse_ledger.merkle_root ledger)
         target_hash transition
         (unstage (Sparse_ledger.handler ledger)))

  let combine ((module T): state_type) t1 t2 =
    return (T.merge t1 t2 |> Or_error.ok_exn)
end)

let create ~conf_dir ledger
    (transactions: Transaction.With_valid_signature.t list) fee_pk =
  Parallel.init_master () ;
  let config =
    Map_reduce.Config.create ~local:1
      ~redirect_stderr:(`File_append (conf_dir ^/ "bundle-stderr"))
      ~redirect_stdout:(`File_append (conf_dir ^/ "bundle-stdout"))
      ()
  in
  let inputs, target_hash =
    let finalize_with_fees inputs total_fees =
      let fee_collection = Fee_transfer.One (fee_pk, total_fees) in
      let sparse_ledger = Sparse_ledger.of_ledger_subset_exn ledger [fee_pk] in
      (* We assume that the ledger and transactions passed in are constructed such that
         an overflow will not occur here. *)
      Or_error.ok_exn (Ledger.apply_fee_transfer ledger fee_collection) ;
      let target_hash = Ledger.merkle_root ledger in
      let fee_collection =
        { Input.transition= Fee_transfer fee_collection
        ; ledger= sparse_ledger
        ; target_hash }
      in
      let rev_inputs = fee_collection :: inputs in
      List.iter rev_inputs ~f:(fun {transition; _} ->
          Or_error.ok_exn
            ( match transition with
            | Fee_transfer t -> Ledger.undo_fee_transfer ledger t
            | Transaction t -> Ledger.undo_transaction ledger t ) ) ;
      (List.rev rev_inputs, target_hash)
    in
    let rec go inputs total_fees = function
      | [] -> finalize_with_fees inputs total_fees
      | (tx: Transaction.With_valid_signature.t) :: txs ->
          let ({Transaction.sender; payload} as transaction) =
            (tx :> Transaction.t)
          in
          match Currency.Fee.add payload.fee total_fees with
          | None ->
              (* We have hit max fees, truncate the list *)
              finalize_with_fees inputs total_fees
          | Some total_fees' ->
              (* TODO: Bad transactions should get thrown away earlier.
             That is, the error case here is actually unexpected and we
             should construct the system so that it does not occur.
          *)
              let sparse_ledger =
                Sparse_ledger.of_ledger_subset_exn ledger
                  [Public_key.compress sender; payload.receiver]
              in
              match Ledger.apply_transaction ledger tx with
              | Error _s -> go inputs total_fees txs
              | Ok () ->
                  let input : Input.t =
                    { transition= Transaction tx
                    ; ledger= sparse_ledger
                    ; target_hash= Ledger.merkle_root ledger }
                  in
                  go (input :: inputs) total_fees' txs
    in
    go [] Currency.Fee.zero transactions
  in
  { result=
      Map_reduce.map_reduce config (Pipe.of_list inputs)
        ~m:(module M)
        ~param:()
  ; target_hash }

let cancel t = printf "Bundle.cancel: todo\n%!"
