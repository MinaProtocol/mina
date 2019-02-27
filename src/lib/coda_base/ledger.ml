open Core
open Snark_params
open Signature_lib
open Merkle_ledger

module Ledger_inner = struct
  module Depth = struct
    let depth = ledger_depth
  end

  module Location0 : Merkle_ledger.Location_intf.S =
    Merkle_ledger.Location.Make (Depth)

  module Location_at_depth = Location0

  module Kvdb : Intf.Key_value_database = Rocksdb.Database

  module Storage_locations : Intf.Storage_locations = struct
    let stack_db_file = "coda_stack_db"

    let key_value_db_dir = "coda_key_value_db"
  end

  module Hash = struct
    module T = struct
      type t = Ledger_hash.t [@@deriving bin_io, sexp, compare, hash, eq]
    end

    include T
    include Hashable.Make_binable (T)

    let merge = Ledger_hash.merge

    let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

    let empty_account = hash_account Account.empty
  end

  module Account = struct
    type t = Account.Stable.V1.t [@@deriving bin_io, eq, compare, sexp]

    let empty = Account.empty

    let public_key = Account.public_key

    let initialize = Account.initialize
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
    Database.Make (Public_key.Compressed) (Account) (Hash) (Depth)
      (Location_at_depth)
      (Kvdb)
      (Storage_locations)

  module Null =
    Null_ledger.Make (Public_key.Compressed) (Account) (Hash)
      (Location_at_depth)
      (Depth)

  module Any_ledger :
    Merkle_ledger.Any_ledger.S
    with module Location = Location_at_depth
    with type account := Account.t
     and type key := Public_key.Compressed.t
     and type key_set := Public_key.Compressed.Set.t
     and type hash := Hash.t =
    Merkle_ledger.Any_ledger.Make_base (Public_key.Compressed) (Account) (Hash)
      (Location_at_depth)
      (Depth)

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
    Merkle_mask.Masking_merkle_tree.Make (Public_key.Compressed) (Account)
      (Hash)
      (Location_at_depth)
      (Any_ledger.M)

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
    Merkle_mask.Maskable_merkle_tree.Make (Public_key.Compressed) (Account)
      (Hash)
      (Location_at_depth)
      (Any_ledger.M)
      (Mask)

  include Mask.Attached

  type maskable_ledger = t

  (* Mask.Attached.create () fails, can't create an attached mask directly
  shadow create in order to create an attached mask
*)
  let create ?directory_name () =
    let maskable = Db.create ?directory_name () in
    let casted = Any_ledger.cast (module Db) maskable in
    let mask = Mask.create () in
    Maskable.register_mask casted mask

  let of_database db =
    let casted = Any_ledger.cast (module Db) db in
    let mask = Mask.create () in
    Maskable.register_mask casted mask

  (* Mask.Attached.create () fails, can't create an attached mask directly
  shadow create in order to create an attached mask
  *)
  let create ?directory_name () = of_database (Db.create ?directory_name ())

  let create_ephemeral () =
    let maskable = Null.create () in
    let casted = Any_ledger.cast (module Null) maskable in
    let mask = Mask.create () in
    Maskable.register_mask casted mask

  let with_ledger ~f =
    let ledger = create () in
    try
      let result = f ledger in
      close ledger ; result
    with exn -> close ledger ; raise exn

  let packed t = Any_ledger.cast (module Mask.Attached) t

  let register_mask t mask = Maskable.register_mask (packed t) mask

  let unregister_mask_exn t mask = Maskable.unregister_mask_exn (packed t) mask

  let remove_and_reparent_exn t t_as_mask ~children =
    Maskable.remove_and_reparent_exn (packed t) t_as_mask ~children

  (* TODO: Implement the serialization/deserialization *)
  let unattached_mask_of_serializable _ = failwith "unimplmented"

  let serializable_of_t _ = failwith "unimplented"

  type serializable = int [@@deriving bin_io]

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
    let key, loc =
      match get_or_create_account_exn ledger key (Account.initialize key) with
      | `Existed, loc -> ([], loc)
      | `Added, loc -> ([key], loc)
    in
    (key, get ledger loc |> Option.value_exn, loc)

  let create_empty ledger key =
    let start_hash = merkle_root ledger in
    match get_or_create_account_exn ledger key Account.empty with
    | `Existed, _ -> failwith "create_empty for a key already present"
    | `Added, new_loc ->
        Debug_assert.debug_assert (fun () ->
            [%test_eq: Ledger_hash.t] start_hash (merkle_root ledger) ) ;
        (merkle_path ledger new_loc, Account.empty)
end

include Ledger_inner
include Transaction_logic.Make (Ledger_inner)
