open Core
open Nanobit_base
open Async
module Map_reduce = Rpc_parallel.Map_reduce

module T = struct
  type t =
    { snark : Transaction_snark.t option Deferred.t
    ; target_hash : Ledger_hash.t
    }
  [@@deriving fields]
end
include T

module Worker_state = struct
  type t = (module Transaction_snark.S)

  let create () : t =
    let module Keys = Keys.Make() in
    (module Transaction_snark.Make(struct
         let keys = Keys.transaction_snark_keys
       end))
end

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
        of_hash ~depth:Ledger.depth
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
    set_exn t receiver_idx
      { receiver_account with
        balance = Option.value_exn (Balance.add_amount sender_account.balance amount)
      }

  let merkle_root t = Ledger_hash.of_hash (merkle_root t)

  let handler t =
    let ledger = ref t in
    let path_exn idx =
      List.map (path_exn !ledger idx)
        ~f:(function `Left h -> h | `Right h -> h)
    in
    stage begin
      fun (With { request; respond}) ->
        match request with
        | Ledger_hash.Get_element idx ->
          let elt = get_exn !ledger idx in
          let path = path_exn idx in
          respond (Provide (elt, path))
        | Ledger_hash.Get_path idx ->
          let path = path_exn idx in
          respond (Provide path)
        | Ledger_hash.Set (idx, account) ->
          ledger := set_exn !ledger idx account;
          respond (Provide ())
        | Ledger_hash.Find_index pk ->
          let index = find_index_exn !ledger pk in
          respond (Provide index)
        | _ -> unhandled
    end
end

module Input = struct
  type t =
    { transaction : Transaction.t
    ; ledger : Sparse_ledger.t
    ; target_hash : Ledger_hash.Stable.V1.t
    }
  [@@deriving bin_io]
end

module M = Map_reduce.Make_map_reduce_function_with_init(struct
    module Input = Input
    module Accum = Transaction_snark
    module Param = struct type t = unit [@@deriving bin_io] end

    open Snark_params
    open Tick

    type state_type = Worker_state.t

    let init () = return (Worker_state.create ())

    let map ((module T) : state_type) { Input.transaction; ledger } =
      T.of_transaction
        (Sparse_ledger.merkle_root ledger)
        Sparse_ledger.(merkle_root (apply_transaction_exn ledger transaction))
        transaction
        (unstage (Sparse_ledger.handler ledger))
      |> return

    let combine ((module T) : state_type) t1 t2 =
      return (T.merge t1 t2)
  end)

let create ~conf_dir ledger transactions : t =
  Parallel.init_master ();
  let config =
    Map_reduce.Config.create
      ~redirect_stderr:(`File_append (conf_dir ^/ "bundle-stderr"))
      ~redirect_stdout:(`File_append (conf_dir ^/ "bundle-stdout"))
      ()
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
