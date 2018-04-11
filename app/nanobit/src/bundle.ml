open Core
open Rpc_parallel
open Nanobit_base
open Async

module Keys = Keys.Make()
module T = Transaction_snark.Make(struct let keys = Keys.transaction_snark_keys end)

module Sparse_ledger = struct
  open Snark_params

  type tree =
    | Account of Account.Stable.V1.t
    | Hash of Tick.Pedersen.Digest.t
    | Node of Tick.Pedersen.Digest.t * tree * tree
  [@@deriving bin_io]

  let hash_account a =
    Tick.Pedersen.(hash_fold params (Account.fold_bits a))

  let hash = function
    | Account a -> hash_account a
    | Hash h -> h
    | Node (h, _, _) -> h

  type t =
    { indexes : (Public_key.Compressed.Stable.V1.t, Account.Index.t) List.Assoc.t
    ; depth   : int
    ; tree    : tree
    }
  [@@deriving bin_io]

  let merkle_root { tree; _ } = Ledger_hash.of_hash (hash tree)

  let is_prefix ~depth ~prefix idx = failwith "TODO"

  let merge h1 h2 =
    let open Tick.Pedersen in
    hash_fold params (fun ~init ~f ->
      let init = Digest.Bits.fold h1 ~init ~f in
      Digest.Bits.fold h2 ~init ~f)

  let add_path tree0 path0 account =
    let rec build_tree = function
      | Ledger.Path.Left h_r :: path ->
        let l = build_tree path in
        Node (merge (hash l) h_r, l, Hash h_r)
      | Ledger.Path.Right h_l :: path ->
        let r = build_tree path in
        Node (merge h_l (hash r), Hash h_l, r)
      | [] ->
        Account account
    in
    let rec union tree path =
      match tree, path with
      | Hash h, path ->
        let t = build_tree path in
        assert (Tick.Pedersen.Digest.(=) h (hash t));
        t
      | Node (h, l, r), (Ledger.Path.Left h_r :: path) ->
        assert (Tick.Pedersen.Digest.(=) h_r (hash r));
        let l = union l path in
        Node (h, l, r)
      | Node (h, l, r), (Ledger.Path.Right h_l :: path) ->
        assert (Tick.Pedersen.Digest.(=) h_l (hash l));
        let r = union r path in
        Node (h, l, r)
      | Node _, [] -> failwith "Path too short"
      | Account _, _::_ -> failwith "Path too long"
      | Account a, [] ->
        assert (Account.equal a account);
        tree
    in
    union tree0 path0
  ;;

  let of_ledger_subset ledger keys =
    let tree =
      List.fold keys ~init:(Hash (Ledger.merkle_root ledger :> Tick.Pedersen.Digest.t))
        ~f:(fun tree pk ->
          add_path tree (Option.value_exn (Ledger.merkle_path ledger pk))
            (Option.value_exn (Ledger.get ledger pk)))
    in
    { depth = Ledger.depth ledger
    ; tree
    ; indexes = List.map keys ~f:(fun k -> (k, Ledger.index_of_key_exn ledger k))
    }

  let ith_bit idx i = (idx lsr i) land 1 = 1

  let find_index_exn t pk =
    List.Assoc.find_exn t.indexes ~equal:Public_key.Compressed.equal pk

  let get_exn { tree; depth; _ } idx =
    let rec go i tree =
      match i < 0, tree with
      | true, Account acct -> acct
      | false, Node (_, l, r) ->
        let go_right = ith_bit idx i in
        if go_right then go (i - 1) r else go (i - 1) l
      | _ -> failwith "Sparse_ledger.get: Bad index"
    in
    go (depth - 1) tree

  let set_exn t idx acct =
    let rec go i tree =
      match i < 0, tree with
      | true, Account _ -> Account acct
      | false, Node (_, l, r) ->
        let l, r =
          let go_right = ith_bit idx i in
          if go_right
          then (l, go (i - 1) r)
          else (go (i - 1) l, r)
        in
        Node (merge (hash l) (hash r), l, r)
      | _ -> failwith "Sparse_ledger.get: Bad index"
    in
    { t with tree = go (t.depth - 1) t.tree }

  let apply_transaction_exn t ({ sender; payload = { amount; fee=_; receiver } } : Transaction.t) =
    let sender_idx =
      List.Assoc.find_exn t.indexes ~equal:Public_key.Compressed.equal
        (Public_key.compress sender)
    in
    let receiver_idx =
      List.Assoc.find_exn t.indexes ~equal:Public_key.Compressed.equal
        receiver
    in
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

  let path_exn { tree; depth; _ } idx =
    let rec go acc i tree =
      if i < 0
      then acc
      else
        match tree with
        | Account _ -> failwith "Sparse_ledger.path: Bad depth"
        | Hash _ -> failwith "Sparse_ledger.path: Dead end"
        | Node (_, l, r) ->
          let go_right = ith_bit idx i in
          if go_right
          then go (hash l :: acc) (i - 1) r
          else go (hash r :: acc) (i - 1) l
    in
    go [] (depth - 1) tree
end

type t =
  { snark : Transaction_snark.t option Deferred.t
  ; target_hash : Ledger_hash.t
  }
[@@deriving fields]

module Input = struct
  type t =
    { transaction : Transaction.t
    ; ledger : Sparse_ledger.t
    ; target_hash : Ledger_hash.Stable.V1.t
    }
  [@@deriving bin_io]
end

module M = Map_reduce.Make_map_reduce_function(struct
    module Input = Input
    module Accum = Transaction_snark

    open Snark_params
    open Tick

    let map { Input.transaction; ledger } =
      let handler (With { request; respond}) =
        let ledger = ref ledger in
        let open Ledger_hash in
        match request with
        | Get_element idx ->
          let elt = Sparse_ledger.get_exn !ledger idx in
          let path = Sparse_ledger.path_exn !ledger idx in
          respond (Provide (elt, path))
        | Get_path idx ->
          respond (Provide (Sparse_ledger.path_exn !ledger idx))
        | Set (idx, account) ->
          ledger := Sparse_ledger.set_exn !ledger idx account;
          respond (Provide ())
        | Find_index pk ->
          respond (Provide (Sparse_ledger.find_index_exn !ledger pk))
        | _ -> unhandled
      in
      T.of_transaction
        (Sparse_ledger.merkle_root ledger)
        Sparse_ledger.(merkle_root (apply_transaction_exn ledger transaction))
        transaction
        handler
      |> return

    let combine t1 t2 =
      return (T.merge t1 t2)
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
