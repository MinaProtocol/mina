open Core
open Unsigned

module type Balance_intf = sig
  type t [@@deriving eq]

  val zero : t
end

module type Account_intf = sig
  type t [@@deriving bin_io, eq]

  type balance

  val empty : t

  val balance : t -> balance

  val set_balance : t -> balance -> t

  val public_key : t -> string

  val gen : t Quickcheck.Generator.t
end

module type Hash_intf = sig
  type t [@@deriving bin_io, eq]

  type account

  val empty : t

  val merge : t * t -> t

  val hash_account : account -> t
end

module type Depth_intf = sig
  val depth : int
end

module type Key_value_database_intf = sig
  type t

  val create : directory:string -> t

  val destroy : t -> unit

  val get : t -> key:Bigstring.t -> Bigstring.t option

  val set : t -> key:Bigstring.t -> data:Bigstring.t -> unit

  val delete : t -> key:Bigstring.t -> unit
end

module type Stack_database_intf = sig
  type t

  val create : filename:string -> t

  val destroy : t -> unit

  val push : t -> Bigstring.t -> unit

  val pop : t -> Bigstring.t option
end

module type S = sig
  type account

  type hash

  type key

  type t

  type error = Account_key_not_found | Out_of_leaves | Malformed_database

  type address

  module MerklePath : sig
    type t = Direction.t * hash

    val implied_root : t list -> hash -> hash
  end

  val create : key_value_db_dir:string -> stack_db_file:string -> t

  val destroy : t -> unit

  val get_key_of_account : t -> account -> (key, error) Result.t

  val get_account : t -> key -> account option

  val set_account : t -> account -> (unit, error) Result.t

  val merkle_root : t -> hash

  val merkle_path : t -> key -> MerklePath.t list

  val set_inner_hash_at_addr_exn : t -> address -> hash -> unit

  val get_inner_hash_at_addr_exn : t -> address -> hash

  val get_all_accounts_rooted_at_exn : t -> address -> account list

  val set_all_accounts_rooted_at_exn : t -> address -> account list -> unit
end

module Make
    (Balance : Balance_intf)
    (Account : Account_intf with type balance := Balance.t)
    (Hash : Hash_intf with type account := Account.t)
    (Depth : Depth_intf)
    (Kvdb : Key_value_database_intf)
    (Sdb : Stack_database_intf) :
  sig
    include S

    val with_test_instance : (t -> 'a) -> 'a

    val gen_directions : [`Left | `Right] List.t Quickcheck.Generator.t

    val of_direction : [`Left | `Right] List.t -> address
  end
  with type account := Account.t
   and type hash := Hash.t =
struct
  (* The depth of a merkle tree can never be greater than 253. *)
  let max_depth = Depth.depth

  let () = assert (max_depth < 0xfe)

  type error = Account_key_not_found | Out_of_leaves | Malformed_database

  exception Error_exception of error

  let exn_of_error err = Error_exception err

  module MerklePath = struct
    type t = Direction.t * Hash.t

    let implied_root path leaf_hash =
      let rec loop sibling_hash = function
        | [] -> sibling_hash
        | (Direction.Left, hash) :: t ->
            loop (Hash.merge (hash, sibling_hash)) t
        | (Direction.Right, hash) :: t ->
            loop (Hash.merge (sibling_hash, hash)) t
      in
      loop leaf_hash path
  end

  (* Keys are a bitstring prefixed by a byte. In the case of accounts, the prefix
   * byte is 0xfe. In the case of a hash node in the merkle tree, the prefix is between
   * 0 and N (where N is the depth of the depth of the merkle tree), with 1 representing
   * the leafs of the tree, and N representing the root of the merkle tree. For account
   * and node keys, the bitstring represents the path in the tree where that node exists.
   * For all other keys (generic keys), the prefix is 0xff. Generic keys can contain
   * any bitstring.
   *)
  module Key = struct
    let byte_count_of_bits n = (n / 8) + min 1 (n % 8)

    let path_byte_count = byte_count_of_bits Depth.depth

    module Path = struct
      open Bitstring

      type nonrec t = t

      let show (path: t) : string =
        let len = bitstring_length path in
        let bytes = Bytes.create len in
        for i = 0 to len - 1 do
          let ch = if is_clear path i then '0' else '1' in
          Bytes.set bytes i ch
        done ;
        Bytes.to_string bytes

      let pp (fmt: Format.formatter) : t -> unit =
        Fn.compose (Format.pp_print_string fmt) show

      let build (dirs: Direction.t list) =
        let path = create_bitstring (List.length dirs) in
        let rec loop i = function
          | [] -> ()
          | h :: t ->
              if Direction.to_bool h then set path i ;
              loop (i + 1) t
        in
        loop 0 dirs ; path

      let length = bitstring_length

      let copy (path: t) : t =
        let%bitstring path = {| path: -1: bitstring |} in
        path

      let last_direction path =
        Direction.of_bool (get path (bitstring_length path - 1) = 0)

      (* returns a slice of the original path, so the returned key needs to byte
       * copied before mutating the path *)
      let parent (path: t) : t = subbitstring path 0 (bitstring_length path - 1)

      let child (path: t) (dir: Direction.t) : t =
        let dir_bit = Direction.to_bool dir in
        let%bitstring path = {| path: -1: bitstring; dir_bit: 1 |} in
        path

      let sibling (path: t) : t =
        let path = copy path in
        let last_bit_index = length path - 1 in
        let last_bit = get path last_bit_index <> 0 in
        let flip = if last_bit then clear else set in
        flip path last_bit_index ; path

      let next (path: t) : t Or_error.t =
        let open Result.Let_syntax in
        let path = copy path in
        let len = length path in
        let rec find_first_clear_bit i =
          if i < 0 then
            Or_error.error_string "Cannot index with a negative value"
          else if is_clear path i then Result.Ok i
          else find_first_clear_bit (i - 1)
        in
        let rec clear_bits i =
          if i >= len then ()
          else (
            clear path i ;
            clear_bits (i + 1) )
        in
        let%map first_clear_index = find_first_clear_bit (len - 1) in
        set path first_clear_index ;
        clear_bits (first_clear_index + 1) ;
        path

      let serialize (path: t) : Bigstring.t =
        let path_bstr =
          Bigstring.of_string (Bitstring.string_of_bitstring path)
        in
        let path_bstr_len = Bigstring.length path_bstr in
        assert (path_bstr_len <= path_byte_count) ;
        let required_padding = path_byte_count - path_bstr_len in
        let padding = Bigstring.create required_padding in
        Bigstring.concat [path_bstr; padding]
    end

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
      | Account of Path.t
      | Hash of Path.t
    [@@deriving show]

    type binary = Bigstring.t

    let is_generic = function Generic _ -> true | _ -> false

    let is_account = function Account _ -> true | _ -> false

    let is_hash = function Hash _ -> true | _ -> false

    let depth : t -> int = function
      | Generic _ -> raise (Invalid_argument "depth: generic key has no depth")
      | Account _ -> 0
      | Hash path -> max_depth - Path.length path

    let path : t -> Path.t = function
      | Generic _ ->
          raise
            (Invalid_argument "last_direction: generic key has not directions")
      | Account path | Hash path -> path

    let root_hash : t = Hash (Bitstring.create_bitstring 0)

    let build_generic (data: Bigstring.t) : t = Generic data

    let build_empty_account () : t =
      Account (Bitstring.create_bitstring max_depth)

    let build_account (path: Direction.t list) : t =
      assert (List.length path = max_depth) ;
      Account (Path.build path)

    let parse (str: Bigstring.t) : (t, unit) Result.t =
      let prefix = Bigstring.get str 0 |> Char.to_int |> UInt8.of_int in
      let data = Bigstring.sub str ~pos:1 ~len:(Bigstring.length str - 1) in
      if prefix = Prefix.generic then Result.return (Generic data)
      else
        let path = Bitstring.bitstring_of_string (Bigstring.to_string data) in
        let slice_path = Bitstring.subbitstring path 0 in
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

    let serialize = function
      | Generic data -> prefix_bigstring Prefix.generic data
      | Account path ->
          assert (Path.length path = max_depth) ;
          prefix_bigstring Prefix.account (Path.serialize path)
      | Hash path ->
          assert (Path.length path <= max_depth) ;
          prefix_bigstring
            (Prefix.hash (Path.length path))
            (Path.serialize path)

    let copy_bigstring (bstr: Bigstring.t) : Bigstring.t =
      let len = Bigstring.length bstr in
      let bstr' = Bigstring.create len in
      Bigstring.blit ~src:bstr ~src_pos:0 ~dst:bstr' ~dst_pos:0 ~len ;
      bstr'

    let copy : t -> t = function
      | Generic data -> Generic (copy_bigstring data)
      | Account path -> Account (Path.copy path)
      | Hash path -> Hash (Path.copy path)

    (* returns a slice of the original path, so the returned key needs to byte
     * copied before mutating the path *)
    let parent : t -> t = function
      | Generic _ ->
          raise (Invalid_argument "parent: generic keys have no parent")
      | Account _ ->
          raise (Invalid_argument "parent: account keys have no parent")
      | Hash path ->
          assert (Path.length path > 0) ;
          Hash (Path.parent path)

    let child (key: t) (dir: Direction.t) : t =
      match key with
      | Generic _ ->
          raise (Invalid_argument "child: generic keys have no child")
      | Account _ ->
          raise (Invalid_argument "child: account keys have no child")
      | Hash path ->
          assert (Path.length path < max_depth) ;
          Hash (Path.child path dir)

    let next : t -> t Or_error.t = function
      | Generic _ ->
          raise (Invalid_argument "next: generic keys have no next key")
      | Account path ->
          Path.next path |> Result.map ~f:(fun next -> Account next)
      | Hash path -> Path.next path |> Result.map ~f:(fun next -> Hash next)

    let sibling : t -> t = function
      | Generic _ ->
          raise (Invalid_argument "sibling: generic keys have no sibling")
      | Account path -> Account (Path.sibling path)
      | Hash path -> Hash (Path.sibling path)

    let order_siblings (key: t) (base: 'a) (sibling: 'a) : 'a * 'a =
      match Path.last_direction (path key) with
      | Left -> (base, sibling)
      | Right -> (sibling, base)

    let gen_account =
      let open Quickcheck.Let_syntax in
      let%map dirs =
        Quickcheck.Generator.list_with_length Depth.depth Direction.gen
      in
      build_account dirs
  end

  (* Addr is an adapter for MerkleDB to be compatible with Syncable ledger.
  Syncable ledger assumes that the depth of root is 0 and the depth of the leaves is N - 1 *)
  (* TODO: Refactor Address outside of Merkle_database module so that other modules, like Merkle_ledger, can use this *)
  (* TODO: Refactor code so that [`Left | `Right] and Direction are the same throughout the codebase *)
  module Address = struct
    let of_variant = function
      | `Left -> Direction.Left
      | `Right -> Direction.Right

    let to_variant = function
      | Direction.Left -> `Left
      | Direction.Right -> `Right

    type t = Key.Path.t [@@deriving show]

    let depth t = Depth.depth - Bitstring.bitstring_length t

    let parent = Fn.compose Or_error.return Key.Path.parent

    let parent_exn = Key.Path.parent

    let child t (dir: [`Left | `Right]) =
      Key.Path.child t (of_variant dir) |> Or_error.return

    let child_exn t dir = child t dir |> Or_error.ok_exn

    let dirs_from_root t : [`Left | `Right] list =
      List.init (Key.Path.length t) ~f:(fun pos ->
          Direction.of_bool (Bitstring.is_set t pos) )
      |> List.map ~f:to_variant

    let root = Bitstring.create_bitstring 0

    let of_direction dirs = List.fold dirs ~f:child_exn ~init:root

    let%test "the merkle root should have no path" = dirs_from_root root = []

    let gen_directions =
      let open Quickcheck.Generator in
      let open Let_syntax in
      let%bind l = Int.gen_incl 0 (Depth.depth - 1) in
      list_with_length l (Bool.gen >>| fun b -> if b then `Right else `Left)

    let%test_unit "behaves like Merkle Ledger Address module" =
      let module Merkle_address = Merkle_ledger.Address.Make (Depth) in
      Quickcheck.test ~sexp_of:[%sexp_of : [`Left | `Right] List.t]
        gen_directions ~f:(fun dirs ->
          assert (
            let db_result = dirs_from_root @@ of_direction dirs
            and ledger_result =
              Merkle_address.dirs_from_root
                (List.fold dirs ~f:Merkle_address.child_exn
                   ~init:Merkle_address.root)
            in
            db_result = ledger_result ) )
  end

  type key = Key.t [@@deriving show]

  type t = {kvdb: Kvdb.t; sdb: Sdb.t}

  type address = Address.t

  let gen_directions = Address.gen_directions

  let of_direction = Address.of_direction

  let create ~key_value_db_dir ~stack_db_file =
    let kvdb = Kvdb.create ~directory:key_value_db_dir in
    let sdb = Sdb.create ~filename:stack_db_file in
    {kvdb; sdb}

  let destroy {kvdb; sdb} = Kvdb.destroy kvdb ; Sdb.destroy sdb

  let empty_hashes =
    let empty_hashes = Array.create ~len:max_depth Hash.empty in
    let rec loop last_hash i =
      if i < max_depth then (
        let hash = Hash.merge (last_hash, last_hash) in
        empty_hashes.(i) <- hash ;
        loop hash (i + 1) )
    in
    loop Hash.empty 1 ;
    Immutable_array.of_array empty_hashes

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
    | None -> Immutable_array.get empty_hashes (Key.depth key)

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
    let depth = Key.depth key in
    if depth < max_depth then
      let sibling_hash = get_hash mdb (Key.sibling key) in
      let parent_hash =
        Hash.merge (Key.order_siblings key new_hash sibling_hash)
      in
      set_hash mdb (Key.parent key) parent_hash

  let get_inner_hash_at_addr_exn mdb address =
    assert (Key.Path.length address <= Depth.depth) ;
    get_hash mdb (Key.Hash address)

  let set_inner_hash_at_addr_exn mdb address hash =
    assert (Key.Path.length address <= Depth.depth) ;
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
          |> Result.map_error ~f:(fun _ -> Out_of_leaves)
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

  let rec fold_sequence_exl first last ~init ~f =
    let open Result.Let_syntax in
    let comparison = Bitstring.compare first last in
    if comparison > 0 then
      Or_error.error_string "first address needs to precede last address"
    else if comparison = 0 then return init
    else
      let%bind next = Key.Path.next first in
      fold_sequence_exl next last ~init:(f first init) ~f

  let fold_sequence_incl first last ~init ~f =
    Result.map (fold_sequence_exl first last ~init ~f) ~f:(f last)

  let get_width address =
    let first_node =
      Bitstring.concat
        [ address
        ; Bitstring.zeroes_bitstring @@ (Depth.depth - Key.Path.length address)
        ]
    in
    let last_node =
      Bitstring.concat
        [ address
        ; Bitstring.ones_bitstring @@ (Depth.depth - Key.Path.length address)
        ]
    in
    (first_node, last_node)

  let get_all_accounts_rooted_at mdb address =
    let open Result.Let_syntax in
    let first_node, last_node = get_width address in
    let%map result =
      fold_sequence_incl first_node last_node ~init:[] ~f:(fun bit_index acc ->
          let account =
            Option.value_exn
              ~message:
                (sprintf
                   !"address %s does not have an account"
                   (Bitstring.string_of_bitstring bit_index))
              (get_account mdb (Key.Account bit_index))
          in
          account :: acc )
    in
    List.rev result

  let get_all_accounts_rooted_at_exn mdb address =
    get_all_accounts_rooted_at mdb address |> Or_error.ok_exn

  let set_all_accounts_rooted_at mdb address (accounts: Account.t list) =
    let first_node, last_node = get_width address in
    fold_sequence_incl first_node last_node ~init:accounts ~f:(fun bit_index ->
        function
      | head :: tail ->
          update_account mdb (Key.Account bit_index) head ;
          tail
      | [] ->
          assert (Bitstring.equals last_node bit_index) ;
          [] )
    |> Result.ignore

  let set_all_accounts_rooted_at_exn mdb address accounts =
    set_all_accounts_rooted_at mdb address accounts |> Or_error.ok_exn

  let merkle_root mdb = get_hash mdb Key.root_hash

  let merkle_path mdb key =
    let key = if Key.is_account key then Key.Hash (Key.path key) else key in
    assert (Key.is_hash key) ;
    let rec loop k =
      let sibling = Key.sibling k in
      let sibling_dir = Key.Path.last_direction (Key.path k) in
      (sibling_dir, get_hash mdb sibling)
      :: (if Key.depth key < max_depth then loop (Key.parent k) else [])
    in
    loop key

  let with_test_instance f =
    let uuid = Uuid.create () in
    let tmp_dir = "/tmp/merkle_database_test-" ^ Uuid.to_string uuid in
    let key_value_db_dir = Filename.concat tmp_dir "kvdb" in
    let stack_db_file = Filename.concat tmp_dir "sdb" in
    assert (Unix.system ("rm -rf " ^ tmp_dir) = Result.Ok ()) ;
    Unix.mkdir tmp_dir ;
    let mdb = create ~key_value_db_dir ~stack_db_file in
    let cleanup () =
      destroy mdb ;
      assert (Unix.system ("rm -rf " ^ tmp_dir) = Result.Ok ())
    in
    try
      let result = f mdb in
      cleanup () ; result
    with exn -> cleanup () ; raise exn

  let%test_unit "getting a non existing account returns None" =
    with_test_instance (fun mdb ->
        Quickcheck.test Key.gen_account ~f:(fun key ->
            assert (get_account mdb key = None) ) )

  let%test "add and retrieve an account" =
    with_test_instance (fun mdb ->
        let account = Quickcheck.random_value Account.gen in
        assert (set_account mdb account = Ok ()) ;
        let key =
          Account_key.get mdb account
          |> Result.map_error ~f:exn_of_error
          |> Result.ok_exn
        in
        Account.equal (Option.value_exn (get_account mdb key)) account )

  let%test "accounts are atomic" =
    with_test_instance (fun mdb ->
        let account = Quickcheck.random_value Account.gen in
        assert (set_account mdb account = Ok ()) ;
        let key =
          Account_key.get mdb account
          |> Result.map_error ~f:exn_of_error
          |> Result.ok_exn
        in
        assert (set_account mdb account = Ok ()) ;
        let key' =
          Account_key.get mdb account
          |> Result.map_error ~f:exn_of_error
          |> Result.ok_exn
        in
        key = key' && get_account mdb key = get_account mdb key' )

  let%test "accounts can be deleted" =
    with_test_instance (fun mdb ->
        let account = Quickcheck.random_value Account.gen in
        assert (set_account mdb account = Ok ()) ;
        let key =
          Account_key.get mdb account
          |> Result.map_error ~f:exn_of_error
          |> Result.ok_exn
        in
        assert (Option.is_some (get_account mdb key)) ;
        let account = Account.set_balance account Balance.zero in
        assert (set_account mdb account = Ok ()) ;
        get_account mdb key = None )

  let%test "deleted account keys are reassigned" =
    with_test_instance (fun mdb ->
        let account = Quickcheck.random_value Account.gen in
        let account' = Quickcheck.random_value Account.gen in
        assert (set_account mdb account = Ok ()) ;
        let key =
          Account_key.get mdb account
          |> Result.map_error ~f:exn_of_error
          |> Result.ok_exn
        in
        let account = Account.set_balance account Balance.zero in
        assert (set_account mdb account = Ok ()) ;
        assert (set_account mdb account' = Ok ()) ;
        get_account mdb key = Some account' )
end

let%test_module "test functor on in memory databases" =
  ( module struct
    module UInt64 = struct
      include UInt64
      include Binable.Of_stringable (UInt64)

      let equal x y = UInt64.compare x y = 0
    end

    module Account : Account_intf with type balance := UInt64.t = struct
      type t = {public_key: string; balance: UInt64.t} [@@deriving bin_io, eq]

      let empty = {public_key= ""; balance= UInt64.zero}

      let balance {balance; _} = balance

      let set_balance {public_key; _} balance = {public_key; balance}

      let public_key {public_key; _} = public_key

      let gen =
        let open Quickcheck.Let_syntax in
        let%bind public_key = String.gen in
        let%map int_balance = Int.gen in
        let nat_balance = abs int_balance in
        let balance = UInt64.of_int nat_balance in
        {public_key; balance}
    end

    module Hash = struct
      type t = int [@@deriving bin_io, eq, sexp]

      let create t = t

      let empty = 0

      let merge : t * t -> t = Hashtbl.hash

      let hash_account : Account.t -> t = Hashtbl.hash
    end

    module In_memory_kvdb : Key_value_database_intf = struct
      type t = (string, Bigstring.t) Hashtbl.t

      let create ~directory:_ = Hashtbl.create (module String)

      let destroy _ = ()

      let get tbl ~key = Hashtbl.find tbl (Bigstring.to_string key)

      let set tbl ~key ~data =
        Hashtbl.set tbl ~key:(Bigstring.to_string key) ~data

      let delete tbl ~key = Hashtbl.remove tbl (Bigstring.to_string key)
    end

    module In_memory_sdb : Stack_database_intf = struct
      type t = Bigstring.t list ref

      let create ~filename:_ = ref []

      let destroy _ = ()

      let push ls v = ls := v :: !ls

      let pop ls =
        match !ls with
        | [] -> None
        | h :: t ->
            ls := t ;
            Some h
    end

    module Mdb_d (D : Depth_intf) =
      Make (UInt64) (Account) (Hash) (D) (In_memory_kvdb) (In_memory_sdb)

    module Mdb_d4 = Mdb_d (struct
      let depth = 4
    end)

    module Mdb_syncable_ledger = struct
      let max_depth = 8

      include Mdb_d (struct
        let depth = max_depth
      end)

      let gen_non_empty_directions =
        let open Quickcheck.Generator in
        filter ~f:(Fn.compose not List.is_empty) gen_directions

      (* FIXME: test will fail with a depth greater than 8 due to serialization issues  *)
      let%test_unit "set_inner_hash_at_addr_exn(address,hash); \
                     get_inner_hash_at_addr_exn(address) = hash" =
        with_test_instance (fun mdb ->
            let accounts =
              Quickcheck.random_value
                (Quickcheck.Generator.list_with_length (1 lsl max_depth)
                   Account.gen)
            in
            List.iter accounts ~f:(fun account ->
                ignore @@ set_account mdb account ) ;
            Quickcheck.test
              (Quickcheck.Generator.tuple2 gen_non_empty_directions Account.gen)
              ~sexp_of:
                [%sexp_of : [`Left | `Right] List.t * Account.t sexp_opaque]
              ~f:(fun (direction, account) ->
                let hash_account = Hash.hash_account account in
                let address = of_direction direction in
                set_inner_hash_at_addr_exn mdb address hash_account ;
                let result = get_inner_hash_at_addr_exn mdb address in
                assert (Hash.equal result hash_account) ) )

      let sexp_accounts accounts =
        List.map accounts ~f:(fun account ->
            Int.to_string @@ Hash.hash_account account )
        |> List.intersperse ~sep:" " |> String.concat

      let%test_unit "If the entire database is full,\n \
                     set_all_accounts_rooted_at_exn(address,accounts);get_all_accounts_rooted_at_exn(address) \
                     = accounts" =
        with_test_instance (fun mdb ->
            let initial_accounts =
              Quickcheck.random_value
                (Quickcheck.Generator.list_with_length (1 lsl max_depth)
                   Account.gen)
            in
            List.iter initial_accounts ~f:(fun account ->
                ignore @@ set_account mdb account ) ;
            Quickcheck.test gen_directions
              ~sexp_of:[%sexp_of : [`Left | `Right] List.t] ~f:
              (fun direction ->
                let address = of_direction direction in
                let num_accounts =
                  Int.pow 2 (max_depth - List.length direction)
                in
                let accounts =
                  Quickcheck.random_value
                    (Quickcheck.Generator.list_with_length num_accounts
                       Account.gen)
                in
                set_all_accounts_rooted_at_exn mdb address accounts ;
                let result = get_all_accounts_rooted_at_exn mdb address in
                assert (List.equal ~equal:Account.equal accounts result) ) )
    end

    module Mdb_d30 = Mdb_d (struct
      let depth = 30
    end)
  end )
