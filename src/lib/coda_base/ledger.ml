open Core
open Snark_params
open Signature_lib
open Merkle_ledger

module Ledger_inner = struct
  module Depth = struct
    let depth = Coda_compile_config.ledger_depth
  end

  module Location0 : Merkle_ledger.Location_intf.S =
    Merkle_ledger.Location.Make (Depth)

  module Location_at_depth = Location0

  module Kvdb : Intf.Key_value_database with type config := string =
    Rocksdb.Database

  module Storage_locations : Intf.Storage_locations = struct
    let key_value_db_dir = "coda_key_value_db"
  end

  module Hash = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Ledger_hash.Stable.V1.t
        [@@deriving sexp, compare, hash, eq, yojson]

        let to_latest = Fn.id

        (* TODO: move T outside V1 when %%versioned ppx allows it *)
        module T = struct
          type typ = t [@@deriving sexp, compare, hash, bin_io]

          type t = typ [@@deriving sexp, compare, hash, bin_io]
        end

        include Hashable.Make_binable (T) [@@deriving
                                            sexp, compare, hash, eq, yojson]

        let to_string = Ledger_hash.to_string

        let merge = Ledger_hash.merge

        let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

        let empty_account = hash_account Account.empty
      end
    end]

    type t = Stable.Latest.t
  end

  module Account = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Account.Stable.V1.t [@@deriving eq, compare, sexp]

        let to_latest = Fn.id

        let public_key = Account.public_key

        let balance Account.Poly.{balance; _} = balance

        let empty = Account.empty
      end
    end]

    type t = Stable.Latest.t

    let empty = Stable.Latest.empty

    let initialize = Account.initialize
  end

  module Inputs = struct
    module Key = Public_key.Compressed
    module Balance = Currency.Balance
    module Account = Account.Stable.Latest
    module Hash = Hash.Stable.Latest
    module Depth = Depth
    module Kvdb = Kvdb
    module Location = Location_at_depth
    module Storage_locations = Storage_locations
  end

  module Db :
    Merkle_ledger.Database_intf.S
    with module Location = Location_at_depth
    with module Addr = Location_at_depth.Addr
    with type root_hash := Ledger_hash.t
     and type hash := Ledger_hash.t
     and type account := Account.t
     and type key_set := Public_key.Compressed.Set.t
     and type key := Public_key.Compressed.t =
    Database.Make (Inputs)

  module Null = Null_ledger.Make (Inputs)

  module Any_ledger :
    Merkle_ledger.Any_ledger.S
    with module Location = Location_at_depth
    with type account := Account.t
     and type key := Public_key.Compressed.t
     and type key_set := Public_key.Compressed.Set.t
     and type hash := Hash.t =
    Merkle_ledger.Any_ledger.Make_base (Inputs)

  module Mask :
    Merkle_mask.Masking_merkle_tree_intf.S
    with module Location = Location_at_depth
     and module Attached.Addr = Location_at_depth.Addr
    with type account := Account.t
     and type key := Public_key.Compressed.t
     and type key_set := Public_key.Compressed.Set.t
     and type hash := Hash.t
     and type location := Location_at_depth.t
     and type parent := Any_ledger.M.t =
  Merkle_mask.Masking_merkle_tree.Make (struct
    include Inputs
    module Base = Any_ledger.M
  end)

  module Maskable :
    Merkle_mask.Maskable_merkle_tree_intf.S
    with module Location = Location_at_depth
    with module Addr = Location_at_depth.Addr
    with type account := Account.t
     and type key := Public_key.Compressed.t
     and type key_set := Public_key.Compressed.Set.t
     and type hash := Hash.t
     and type root_hash := Hash.t
     and type unattached_mask := Mask.t
     and type attached_mask := Mask.Attached.t
     and type t := Any_ledger.M.t =
  Merkle_mask.Maskable_merkle_tree.Make (struct
    include Inputs
    module Base = Any_ledger.M
    module Mask = Mask

    let mask_to_base m = Any_ledger.cast (module Mask.Attached) m
  end)

  include Mask.Attached
  module Debug = Maskable.Debug

  type maskable_ledger = t

  let of_database db =
    let casted = Any_ledger.cast (module Db) db in
    let mask = Mask.create () in
    Maskable.register_mask casted mask

  (* Mask.Attached.create () fails, can't create an attached mask directly
  shadow create in order to create an attached mask
  *)
  let create ?directory_name () = of_database (Db.create ?directory_name ())

  let create_ephemeral_with_base () =
    let maskable = Null.create () in
    let casted = Any_ledger.cast (module Null) maskable in
    let mask = Mask.create () in
    (casted, Maskable.register_mask casted mask)

  let create_ephemeral () =
    let _base, mask = create_ephemeral_with_base () in
    mask

  let with_ledger ~f =
    let ledger = create () in
    try
      let result = f ledger in
      close ledger ; result
    with exn -> close ledger ; raise exn

  let with_ephemeral_ledger ~f =
    let _base_ledger, masked_ledger = create_ephemeral_with_base () in
    try
      let result = f masked_ledger in
      let (_ : Mask.t) =
        Maskable.unregister_mask_exn ~grandchildren:`Recursive masked_ledger
      in
      result
    with exn ->
      let (_ : Mask.t) =
        Maskable.unregister_mask_exn ~grandchildren:`Recursive masked_ledger
      in
      raise exn

  let packed t = Any_ledger.cast (module Mask.Attached) t

  let register_mask t mask = Maskable.register_mask (packed t) mask

  let unregister_mask_exn mask = Maskable.unregister_mask_exn mask

  let remove_and_reparent_exn t t_as_mask =
    Maskable.remove_and_reparent_exn (packed t) t_as_mask

  type unattached_mask = Mask.t

  type attached_mask = Mask.Attached.t

  (* inside MaskedLedger, the functor argument has assigned to location, account, and path
  but the module signature for the functor result wants them, so we declare them here *)
  type location = Location.t

  (* TODO: Don't allocate: see Issue #1191 *)
  let fold_until t ~init ~f ~finish =
    let accounts = to_list t in
    List.fold_until accounts ~init ~f ~finish

  let create_new_account_exn t pk account =
    let action, _ = get_or_create_account_exn t pk account in
    assert (action = `Added)

  (* shadows definition in MaskedLedger, extra assurance hash is of right type  *)
  let merkle_root t =
    Ledger_hash.of_hash (merkle_root t :> Tick.Pedersen.Digest.t)

  let get_or_create ledger key =
    let action, loc =
      get_or_create_account_exn ledger key (Account.initialize key)
    in
    (action, Option.value_exn (get ledger loc), loc)

  let create_empty ledger key =
    let start_hash = merkle_root ledger in
    match get_or_create_account_exn ledger key Account.empty with
    | `Existed, _ ->
        failwith "create_empty for a key already present"
    | `Added, new_loc ->
        Debug_assert.debug_assert (fun () ->
            [%test_eq: Ledger_hash.t] start_hash (merkle_root ledger) ) ;
        (merkle_path ledger new_loc, Account.empty)

  let _handler t =
    let open Snark_params.Tick in
    let path_exn idx =
      List.map (merkle_path_at_index_exn t idx) ~f:(function
        | `Left h ->
            h
        | `Right h ->
            h )
    in
    stage (fun (With {request; respond}) ->
        match request with
        | Ledger_hash.Get_element idx ->
            let elt = get_at_index_exn t idx in
            let path = (path_exn idx :> Pedersen.Digest.t list) in
            respond (Provide (elt, path))
        | Ledger_hash.Get_path idx ->
            let path = (path_exn idx :> Pedersen.Digest.t list) in
            respond (Provide path)
        | Ledger_hash.Set (idx, account) ->
            set_at_index_exn t idx account ;
            respond (Provide ())
        | Ledger_hash.Find_index pk ->
            let index = index_of_key_exn t pk in
            respond (Provide index)
        | _ ->
            unhandled )
end

include Ledger_inner
include Transaction_logic.Make (Ledger_inner)

let gen_initial_ledger_state :
    (Signature_lib.Keypair.t * Currency.Amount.t * Coda_numbers.Account_nonce.t)
    array
    Quickcheck.Generator.t =
  let open Quickcheck.Generator.Let_syntax in
  let%bind n_accounts = Int.gen_incl 2 10 in
  let%bind keypairs = Quickcheck_lib.replicate_gen Keypair.gen n_accounts in
  let%bind balances =
    Quickcheck_lib.replicate_gen
      Currency.Amount.(gen_incl (of_int 500_000_000) (of_int 1_000_000_000))
      n_accounts
  in
  let%bind nonces =
    Quickcheck_lib.replicate_gen
      ( Quickcheck.Generator.map ~f:Coda_numbers.Account_nonce.of_int
      @@ Int.gen_incl 0 1000 )
      n_accounts
  in
  let rec zip3_exn a b c =
    match (a, b, c) with
    | [], [], [] ->
        []
    | x :: xs, y :: ys, z :: zs ->
        (x, y, z) :: zip3_exn xs ys zs
    | _ ->
        failwith "zip3 unequal lengths"
  in
  return @@ Array.of_list @@ zip3_exn keypairs balances nonces

type init_state =
  (Signature_lib.Keypair.t * Currency.Amount.t * Coda_numbers.Account_nonce.t)
  array
[@@deriving sexp_of]

let apply_initial_ledger_state : t -> init_state -> unit =
 fun t accounts ->
  Array.iter accounts ~f:(fun (kp, balance, nonce) ->
      let pk_compressed = Public_key.compress kp.public_key in
      let account = Account.initialize pk_compressed in
      let account' =
        { account with
          balance= Currency.Balance.of_int (Currency.Amount.to_int balance)
        ; nonce }
      in
      create_new_account_exn t pk_compressed account' )
