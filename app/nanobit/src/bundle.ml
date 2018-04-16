open Core
open Rpc_parallel
open Nanobit_base
open Async

module T = struct
  type t =
    { snark : Transaction_snark.t option Deferred.t
    ; target_hash : Ledger_hash.t
    }
  [@@deriving fields]
end
include T

module Sparse_ledger = struct
  open Snark_params.Tick

  include Sparse_ledger.Make(struct
      include Pedersen.Digest
      let equal = (=)
      let merge h1 h2 =
        let open Pedersen in
        hash_fold params (fun ~init ~f ->
          let init = Bits.fold h1 ~init ~f in
          Bits.fold h2 ~init ~f)
    end)
      (Public_key.Compressed.Stable.V1)
      (struct
        include Account.Stable.V1
        let key { Account.public_key } = public_key
        let hash account =
          let open Snark_params.Tick.Pedersen in
          hash_fold params (Account.fold_bits account)
      end)

  let of_ledger_subset ledger keys =
    List.fold keys ~f:(fun acc key ->
      add_path acc (Option.value_exn (Ledger.merkle_path ledger key))
        (Option.value_exn (Ledger.get ledger key)))
      ~init:(
        of_hash ~depth:(Ledger.depth ledger)
          (Ledger.merkle_root ledger :> Pedersen.Digest.t))

  let apply_transaction_exn t ({ sender; payload = { amount; fee=_; receiver } } : Transaction.t) =
    let sender_idx = find_index_exn t (Public_key.compress sender) in
    let receiver_idx = find_index_exn t receiver in
    let sender_account = get_exn t sender_idx in
    let receiver_account = get_exn t receiver_idx in
    (if not Insecure.fee_collection
      then failwith "Bundle.Sparse_ledger: Insecure.fee_collection");
    let open Currency in
    let t =
      set_exn t sender_idx
        { sender_account with
          balance = Option.value_exn (Balance.sub_amount sender_account.balance amount)
        }
    in
    set_exn t sender_idx
      { receiver_account with
        balance = Option.value_exn (Balance.add_amount sender_account.balance amount)
      }

  let merkle_root t = Ledger_hash.of_hash (merkle_root t)
end

module Input = struct
  type t =
    { transaction : Transaction.t
    ; ledger : Sparse_ledger.t
    ; target_hash : Ledger_hash.Stable.V1.t
    }
  [@@deriving bin_io]
end

module Make() = struct
  include T
  module Keys = Keys.Make()

  module M = Map_reduce.Make_map_reduce_function(struct
      module Input = Input
      module Accum = Transaction_snark

      module Transaction_snark =
        Transaction_snark.Make(struct let keys = Keys.transaction_snark_keys end)

      open Snark_params
      open Tick

      let map { Input.transaction; ledger } =
        let handler (With { request; respond}) =
          let ledger = ref ledger in
          let open Ledger_hash in
          let path_exn idx =
            List.map (Sparse_ledger.path_exn !ledger idx)
              ~f:(function `Left h -> h | `Right h -> h)
          in
          match request with
          | Get_element idx ->
            let elt = Sparse_ledger.get_exn !ledger idx in
            let path = path_exn idx in
            respond (Provide (elt, path))
          | Get_path idx ->
            respond (Provide (path_exn idx))
          | Set (idx, account) ->
            ledger := Sparse_ledger.set_exn !ledger idx account;
            respond (Provide ())
          | Find_index pk ->
            respond (Provide (Sparse_ledger.find_index_exn !ledger pk))
          | _ -> unhandled
        in
        Transaction_snark.of_transaction
          (Sparse_ledger.merkle_root ledger)
          Sparse_ledger.(merkle_root (apply_transaction_exn ledger transaction))
          transaction
          handler
        |> return

      let combine t1 t2 =
        return (Transaction_snark.merge t1 t2)
    end)

  let create ledger transactions : t =
    let config =
      Map_reduce.Config.create ~redirect_stderr:`Dev_null ~redirect_stdout:`Dev_null ()
    in
    let inputs =
      List.filter_map transactions ~f:(fun (transaction : Transaction.t) ->
        let sparse_ledger =
          Sparse_ledger.of_ledger_subset ledger
            [ Public_key.compress transaction.sender; transaction.payload.receiver ]
        in
        (* TODO: Bad transactions should probably get thrown away earlier? *)
        match Ledger.apply_transaction ledger transaction with
        | Ok () ->
          let target_hash = Ledger.merkle_root ledger in
          let t = { Input.transaction; ledger = sparse_ledger; target_hash } in
          Some t
        | Error _s -> None)
    in
    let target_hash = Ledger.merkle_root ledger in
    List.iter (List.rev inputs) ~f:(fun { transaction } ->
      Or_error.ok_exn (Ledger.undo_transaction ledger transaction));
    { snark =
        Map_reduce.map_reduce config
          (Pipe.of_list inputs)
          ~m:(module M)
          ~param:()
    ; target_hash
    }

  let cancel t = printf "Bundle.cancel: todo\n%!"
end
