open Core
open Nanobit_base
open Async
module Map_reduce = Rpc_parallel.Map_reduce

module type S0 = sig
  type proof
  type t

  val cancel : t -> unit

  val create
    : conf_dir:string
    -> Ledger.t
    -> Transaction.With_valid_signature.t list
    -> Public_key.Compressed.t
    -> t

  val target_hash : t -> Ledger_hash.t

  val result : t -> proof option Deferred.t
end

module type S = sig
  include S0

  module Sparse_ledger : sig
    open Snark_params.Tick

    type t
    [@@deriving sexp]

    val merkle_root : t -> Ledger_hash.t

    val path_exn : t -> int -> [ `Left of Pedersen.Digest.t | `Right of Pedersen.Digest.t ] list

    val apply_transaction_exn : t -> Transaction.t -> t

    val apply_transition_exn : t -> Transaction_snark.Transition.t -> t

    val of_ledger_subset : Ledger.t -> Public_key.Compressed.t list -> t

    val handler : t -> Handler.t Staged.t
  end
end

module T = struct
  type t =
    { result : Transaction_snark.t option Deferred.t
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

  let apply_transaction_exn t ({ sender; payload = { amount; fee; receiver } } : Transaction.t) =
    let sender_idx = find_index_exn t (Public_key.compress sender) in
    let receiver_idx = find_index_exn t receiver in
    let sender_account = get_exn t sender_idx in
    (if not Insecure.fee_collection
      then failwith "Bundle.Sparse_ledger: Insecure.fee_collection");
    let open Currency in
    let t =
      set_exn t sender_idx
        { sender_account with
          nonce = Account.Nonce.succ sender_account.nonce
        ; balance =
            Option.(
              value_exn (
                let open Let_syntax in
                let%bind total = Amount.add_fee amount fee in
                Balance.sub_amount sender_account.balance total))
        }
    in
    let receiver_account = get_exn t receiver_idx in
    set_exn t receiver_idx
      { receiver_account with
        balance = Option.value_exn (Balance.add_amount receiver_account.balance amount)
      }

  let apply_fee_transfer_exn =
    let apply_single t ((pk, fee) : Fee_transfer.single) =
      let index = find_index_exn t pk in
      let account = get_exn t index in
      let open Currency in
      set_exn t index
        { account
          with balance = Option.value_exn (Balance.add_amount account.balance (Amount.of_fee fee))
        }
    in
    fun t transfer ->
      List.fold (Fee_transfer.to_list transfer) ~f:apply_single ~init:t

  let apply_transition_exn t transition =
    match transition with
    | Transaction_snark.Transition.Fee_transfer tr -> apply_fee_transfer_exn t tr
    | Transaction tr -> apply_transaction_exn t (tr :> Transaction.t)

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
    { transition : Transaction_snark.Transition.t
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

    let map ((module T) : state_type) { Input.transition; ledger; target_hash } =
      return
        (T.of_transition (Sparse_ledger.merkle_root ledger) target_hash transition
           (unstage (Sparse_ledger.handler ledger)))

    let combine ((module T) : state_type) t1 t2 =
      return (T.merge t1 t2)
  end)

let create ~conf_dir ledger (transactions : Transaction.With_valid_signature.t list) fee_pk : t =
  Parallel.init_master ();
  let config =
    Map_reduce.Config.create
      ~redirect_stderr:(`File_append (conf_dir ^/ "bundle-stderr"))
      ~redirect_stdout:(`File_append (conf_dir ^/ "bundle-stdout"))
      ()
  in
  let total_fees = ref Currency.Fee.zero in
  let inputs =
    List.filter_map transactions ~f:(fun tx ->
      let { Transaction.sender; payload } as transaction = (tx :> Transaction.t) in
      let sparse_ledger =
        Sparse_ledger.of_ledger_subset ledger
          [ Public_key.compress sender; payload.receiver ]
      in
      (* TODO: Bad transactions should probably get thrown away earlier? *)
      match Ledger.apply_transaction ledger tx with
      | Ok () ->
        let target_hash = Ledger.merkle_root ledger in
        total_fees := Option.value_exn (Currency.Fee.add !total_fees payload.fee);
        let t = { Input.transition = Transaction tx; ledger = sparse_ledger; target_hash } in
        Some t
      | Error _s -> None)
  in
  let fee_collection = Fee_transfer.One (fee_pk, !total_fees) in
  let fee_collection_ledger = Sparse_ledger.of_ledger_subset ledger [ fee_pk ] in
  Or_error.ok_exn (Ledger.apply_fee_transfer ledger fee_collection);
  let target_hash = Ledger.merkle_root ledger in
  let fee_collection_input : Input.t =
    { transition = Fee_transfer fee_collection
    ; ledger = fee_collection_ledger
    ; target_hash
    }
  in
  let inputs = inputs @ [ fee_collection_input ] in
  List.iter (List.rev inputs) ~f:(fun { transition; _ } ->
    Or_error.ok_exn begin match transition with
      | Fee_transfer t -> Ledger.undo_fee_transfer ledger t
      | Transaction t -> Ledger.undo_transaction ledger (t :> Transaction.t)
    end);
  { result =
      Map_reduce.map_reduce config
        (Pipe.of_list inputs)
        ~m:(module M)
        ~param:()
  ; target_hash
  }

let cancel t = printf "Bundle.cancel: todo\n%!"
