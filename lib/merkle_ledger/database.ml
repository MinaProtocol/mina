open Core
open Unsigned

module Make
    (Balance : Intf.Balance)
    (Account : Intf.Account with type balance := Balance.t)
    (Hash : Intf.Hash with type account := Account.t)
    (Depth : Intf.Depth)
    (Kvdb : Intf.Key_value_database)
    (Sdb : Intf.Stack_database) : sig
  include Intf.Database_S
          with type account := Account.t
           and type hash := Hash.t

  val gen_account_key : key Core.Quickcheck.Generator.t
end = struct
  (* The max depth of a merkle tree can never be greater than 253. *)
  let max_depth = Depth.depth

  let () = assert (max_depth < 0xfe)

  type error = Account_key_not_found | Out_of_leaves | Malformed_database

  module MerklePath = struct
    type t = Direction.t * Hash.t

    let implied_root path leaf_hash =
      let rec loop sibling_hash ~height = function
        | [] -> sibling_hash
        | (Direction.Left, hash) :: t ->
            loop (Hash.merge ~height hash sibling_hash) ~height:(height + 1) t
        | (Direction.Right, hash) :: t ->
            loop (Hash.merge ~height sibling_hash hash) ~height:(height + 1) t
      in
      loop leaf_hash ~height:0 path
  end

  module Addr = Merkle_address.Make (struct
    let depth = max_depth
  end)

  (* Keys are a bitstring prefixed by a byte. In the case of accounts, the prefix
   * byte is 0xfe. In the case of a hash node in the merkle tree, the prefix is between
   * 1 and N (where N is the height of the root of the merkle tree, with 1 representing
   * the leafs of the tree, and N representing the root of the merkle tree. For account
   * and node keys, the bitstring represents the path in the tree where that node exists.
   * For all other keys (generic keys), the prefix is 0xff. Generic keys can contain
   * any bitstring.
   *)
  module Key = struct
    module Prefix = struct
      let generic = UInt8.of_int 0xff

      let account = UInt8.of_int 0xfe

      let hash depth = UInt8.of_int (max_depth - depth)
    end

    type t =
      | Generic of Bigstring.t [@printer
                                 fun fmt bstr ->
                                   Format.pp_print_string fmt
                                     (Bigstring.to_string bstr)]
      | Account of Addr.t
      | Hash of Addr.t

    let is_generic = function Generic _ -> true | _ -> false

    let is_account = function Account _ -> true | _ -> false

    let is_hash = function Hash _ -> true | _ -> false

    let height : t -> int = function
      | Generic _ ->
          raise (Invalid_argument "height: generic key has no height")
      | Account _ -> 0
      | Hash path -> Addr.height path

    let path : t -> Addr.t = function
      | Generic _ -> raise (Invalid_argument "generic key has no directions")
      | Account path | Hash path -> path

    let root_hash : t = Hash (Addr.root ())

    let last_direction path =
      Direction.of_bool (Addr.get path (Addr.depth path - 1) <> 0)

    let build_generic (data: Bigstring.t) : t = Generic data

    let build_empty_account () : t =
      Account
        (Addr.of_directions @@ List.init max_depth ~f:(fun _ -> Direction.Left))

    let parse (str: Bigstring.t) : (t, unit) Result.t =
      let prefix = Bigstring.get str 0 |> Char.to_int |> UInt8.of_int in
      let data = Bigstring.sub str ~pos:1 ~len:(Bigstring.length str - 1) in
      if prefix = Prefix.generic then Result.return (Generic data)
      else
        let path = Addr.of_byte_string (Bigstring.to_string data) in
        let slice_path = Addr.slice path 0 in
        if prefix = Prefix.account then
          Result.return (Account (slice_path max_depth))
        else if UInt8.to_int prefix <= max_depth then
          Result.return (Hash (slice_path (max_depth - UInt8.to_int prefix)))
        else Result.fail ()

    let prefix_bigstring prefix src =
      let src_len = Bigstring.length src in
      let dst = Bigstring.create (src_len + 1) in
      Bigstring.set dst 0 (Char.of_int_exn (UInt8.to_int prefix)) ;
      Bigstring.blit ~src ~src_pos:0 ~dst ~dst_pos:1 ~len:src_len ;
      dst

    let get_path = function
      | Account path -> path
      | Hash path -> path
      | Generic _ ->
          raise (Invalid_argument "get_path: generic does not have a path")

    let serialize = function
      | Generic data -> prefix_bigstring Prefix.generic data
      | Account path ->
          assert (Addr.depth path = max_depth) ;
          prefix_bigstring Prefix.account (Addr.serialize path)
      | Hash path ->
          assert (Addr.depth path <= max_depth) ;
          prefix_bigstring
            (Prefix.hash (Addr.depth path))
            (Addr.serialize path)

    let parent : t -> t = function
      | Generic _ ->
          raise (Invalid_argument "parent: generic keys have no parent")
      | Account _ ->
          raise (Invalid_argument "parent: account keys have no parent")
      | Hash path ->
          assert (Addr.depth path > 0) ;
          Hash (Addr.parent_exn path)

    let next : t -> t Option.t = function
      | Generic _ ->
          raise (Invalid_argument "next: generic keys have no next key")
      | Account path ->
          Addr.next path |> Option.map ~f:(fun next -> Account next)
      | Hash path -> Addr.next path |> Option.map ~f:(fun next -> Hash next)

    let sibling : t -> t = function
      | Generic _ ->
          raise (Invalid_argument "sibling: generic keys have no sibling")
      | Account path -> Account (Addr.sibling path)
      | Hash path -> Hash (Addr.sibling path)

    let order_siblings (key: t) (base: 'a) (sibling: 'a) : 'a * 'a =
      match last_direction (path key) with
      | Left -> (base, sibling)
      | Right -> (sibling, base)
  end

  type key = Key.t

  type t = {kvdb: Kvdb.t; sdb: Sdb.t}

  (* let sexp_of_t {kvdb; _} = 
    let rec go i =  *)

  let gen_account_key =
    let open Quickcheck.Let_syntax in
    let build_account (path: Direction.t list) =
      assert (List.length path = Depth.depth) ;
      Key.Account (Addr.of_directions path)
    in
    let%map dirs =
      Quickcheck.Generator.list_with_length Depth.depth Direction.gen
    in
    build_account dirs

  let create ~key_value_db_dir ~stack_db_file =
    let kvdb = Kvdb.create ~directory:key_value_db_dir in
    let sdb = Sdb.create ~filename:stack_db_file in
    {kvdb; sdb}

  let destroy {kvdb; sdb} = Kvdb.destroy kvdb ; Sdb.destroy sdb

  let empty_hashes =
    let empty_hashes = Array.create ~len:(max_depth + 1) Hash.empty in
    let rec loop last_hash height =
      if height <= max_depth then (
        let hash = Hash.merge ~height:(height - 1) last_hash last_hash in
        empty_hashes.(height) <- hash ;
        loop hash (height + 1) )
    in
    loop Hash.empty 1 ;
    Immutable_array.of_array empty_hashes

  let empty_hash_array =
    let array = Array.create ~len:(max_depth + 1) Hash.empty in
    Array.iteri array ~f:(fun i _ ->
        array.(i) <- Immutable_array.get empty_hashes i ) ;
    array

  let get_raw {kvdb; _} key = Kvdb.get kvdb ~key:(Key.serialize key)

  let get_bin mdb key bin_read =
    get_raw mdb key |> Option.map ~f:(fun v -> bin_read v ~pos_ref:(ref 0))

  let get_generic mdb key =
    assert (Key.is_generic key) ;
    get_raw mdb key

  let get_account mdb key =
    assert (Key.is_account key) ;
    get_bin mdb key Account.bin_read_t

  let get_hash mdb key =
    assert (Key.is_hash key) ;
    match get_bin mdb key Hash.bin_read_t with
    | Some hash -> hash
    | None -> Immutable_array.get empty_hashes (Key.height key)

  let set_raw {kvdb; _} key bin =
    Kvdb.set kvdb ~key:(Key.serialize key) ~data:bin

  let set_bin mdb key bin_size bin_write v =
    let size = bin_size v in
    let buf = Bigstring.create size in
    ignore (bin_write buf ~pos:0 v) ;
    set_raw mdb key buf

  let delete_raw {kvdb; _} key = Kvdb.delete kvdb ~key:(Key.serialize key)

  let rec set_hash mdb key new_hash =
    assert (Key.is_hash key) ;
    set_bin mdb key Hash.bin_size_t Hash.bin_write_t new_hash ;
    let height = Key.height key in
    if height < max_depth then
      let sibling_hash = get_hash mdb (Key.sibling key) in
      let parent_hash =
        let left_hash, right_hash =
          Key.order_siblings key new_hash sibling_hash
        in
        assert (height <= Depth.depth) ;
        (* (match key with
        | Hash path -> Core.printf !"Path: %{sexp:Addr.t}\n" path
        | _ -> failwith "Not implemented"); *)
        (* Core.printf !"Height %d : %{sexp:Hash.t} %{sexp:Hash.t}\n" height left_hash right_hash; *)
        Hash.merge ~height left_hash right_hash
      in
      set_hash mdb (Key.parent key) parent_hash

  let get_inner_hash_at_addr_exn mdb address =
    assert (Addr.depth address <= max_depth) ;
    get_hash mdb (Key.Hash address)

  let set_inner_hash_at_addr_exn mdb address hash =
    assert (Addr.depth address <= max_depth) ;
    set_bin mdb (Key.Hash address) Hash.bin_size_t Hash.bin_write_t hash

  module Account_key = struct
    let build_key account =
      Key.build_generic
        (Bigstring.of_string ("$" ^ Account.public_key account))

    let get mdb account =
      match get_generic mdb (build_key account) with
      | None -> Error Account_key_not_found
      | Some key_bin ->
          Key.parse key_bin
          |> Result.map_error ~f:(fun () -> Malformed_database)

    let set mdb account key = set_raw mdb (build_key account) key

    let delete mdb account = delete_raw mdb (build_key account)

    let next_free_key mdb =
      let key =
        Key.build_generic (Bigstring.of_string "next_free_account_key")
      in
      let account_key_result =
        match get_generic mdb key with
        | None -> Result.return (Key.build_empty_account ())
        | Some key -> Key.parse key
      in
      match account_key_result with
      | Error () -> Error Malformed_database
      | Ok account_key ->
          Key.next account_key
          |> Result.of_option ~error:Out_of_leaves
          |> Result.map ~f:(fun next_account_key ->
                 set_raw mdb key (Key.serialize next_account_key) ;
                 account_key )

    let allocate mdb account =
      let key_result =
        match Sdb.pop mdb.sdb with
        | None -> next_free_key mdb
        | Some key ->
            Key.parse key |> Result.map_error ~f:(fun () -> Malformed_database)
      in
      Result.map key_result ~f:(fun key ->
          set mdb account (Key.serialize key) ;
          key )

    let last_free_key_address mdb =
      match
        Key.build_generic (Bigstring.of_string "next_free_account_key")
        |> get_raw mdb
        |> Option.value_map ~f:Key.parse
             ~default:(Result.return @@ Key.build_empty_account ())
      with
      | Error () -> failwith "Could not get retrieve last key"
      | Ok parsed_key -> Key.get_path parsed_key
  end

  let get_key_of_account = Account_key.get

  let update_account mdb key account =
    set_bin mdb key Account.bin_size_t Account.bin_write_t account ;
    set_hash mdb (Key.Hash (Key.path key)) (Hash.hash_account account)

  let delete_account mdb account =
    match Account_key.get mdb account with
    | Error Account_key_not_found -> Ok ()
    | Error err -> Error err
    | Ok key ->
        Kvdb.delete mdb.kvdb ~key:(Key.serialize key) ;
        set_hash mdb (Key.Hash (Key.path key)) Hash.empty ;
        Account_key.delete mdb account ;
        Sdb.push mdb.sdb (Key.serialize key) ;
        Ok ()

  let set_account mdb account =
    if Balance.equal (Account.balance account) Balance.zero then
      delete_account mdb account
    else
      let key_result =
        match Account_key.get mdb account with
        | Error Account_key_not_found -> Account_key.allocate mdb account
        | Error err -> Error err
        | Ok key -> Ok key
      in
      Result.map key_result ~f:(fun key -> update_account mdb key account)

  let num_accounts t =
    Addr.to_int (Account_key.last_free_key_address t) - Sdb.length t.sdb

  let get_all_accounts_rooted_at_exn mdb address =
    let first_node, last_node = Addr.Range.subtree_range address in
    let result =
      Addr.Range.fold (first_node, last_node) ~init:[] ~f:(fun bit_index acc ->
          let account =
            Option.value ~default:Account.empty
              (get_account mdb (Key.Account bit_index))
          in
          account :: acc )
    in
    List.rev result

  let set_all_accounts_rooted_at_exn mdb address (accounts: Account.t list) =
    let first_node, last_node = Addr.Range.subtree_range address in
    Addr.Range.fold (first_node, last_node) ~init:accounts ~f:(fun bit_index ->
        function
      | head :: tail ->
          update_account mdb (Key.Account bit_index) head ;
          tail
      | [] ->
          assert (Addr.equal last_node bit_index) ;
          [] )
    |> ignore

  let merkle_root mdb = get_hash mdb Key.root_hash

  let merkle_path mdb key =
    let key = if Key.is_account key then Key.Hash (Key.path key) else key in
    assert (Key.is_hash key) ;
    let rec loop k =
      let sibling = Key.sibling k in
      let sibling_dir = Key.last_direction (Key.path k) in
      (sibling_dir, get_hash mdb sibling)
      :: (if Key.height key < max_depth then loop (Key.parent k) else [])
    in
    loop key

  let merkle_path_at_addr t addr = merkle_path t (Key.Hash addr)
end
