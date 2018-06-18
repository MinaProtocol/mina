open Core
open Unsigned

module ImmutableArray : sig
  type 'a t
  val wrap : 'a array -> 'a t
  val get : 'a t -> int -> 'a
end = struct
  type 'a t = 'a array
  let wrap arr = arr
  let get arr i = arr.(i)
end

module type Account_intf = sig
  type t [@@deriving bin_io, eq]

  val empty : t
  val is_empty : t -> bool
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
  val get : t -> Bigstring.t -> Bigstring.t option
  val set : t -> Bigstring.t -> Bigstring.t -> unit
  val delete : t -> Bigstring.t -> unit
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

  exception Database_keys_exhausted
  exception Key_not_found of key

  val create : key_value_db_dir:string -> stack_db_file:string -> t
  val destroy : t -> unit

  val get_key_of_account : t -> account -> key option

  val get_account : t -> key -> account option
  val set_account : t -> account -> unit

  val merkle_root : t -> hash
  val merkle_path : t -> key -> hash list
end

module Make
  (Account : Account_intf)
  (Hash : Hash_intf with type account = Account.t)
  (Depth : Depth_intf)
  (KVDB : Key_value_database_intf)
  (SDB : Stack_database_intf)
  : S with type account = Account.t 
       and type hash = Hash.t
  = struct

  exception Database_keys_exhausted
  type account = Account.t
  type hash = Hash.t

  (* The depth of a merkle tree can never be greater than 253. *)
  let max_depth = Depth.depth
  let () = assert (max_depth < 0xfe)

  (* Keys are a bitstring prefixed by a byte. In the case of accounts, the prefix
   * byte is 0xfe. In the case of a hash node in the merkle tree, the prefix is between
   * 0 and N (where N is the depth of the depth of the merkle tree), with 1 representing
   * the leafs of the tree, and N representing the root of the merkle tree. For account
   * and node keys, the bitstring represents the path in the tree where that node exists.
   * For all other keys (generic keys), the prefix is 0xff. Generic keys can contain
   * any bitstring.
   *)
  module Key = struct
    exception Invalid_binary_key
    exception Out_of_paths

    let byte_count_of_bits n = n / 8 + min 1 (n % 8)
    let path_byte_count = byte_count_of_bits Depth.depth

    module Path = struct
      module Direction = struct
        type t = Left | Right

        let of_bool = function
          | false -> Left
          | true  -> Right
        let to_bool = function
          | Left  -> false
          | Right -> true

        let flip = function
          | Left  -> Right
          | Right -> Left

        let gen =
          let open Quickcheck.Let_syntax in
          let%map bool = Quickcheck.Generator.bool in
          of_bool bool
      end

      open Bitstring
      type nonrec t = t

      let show (path : t) : string =
        let len = bitstring_length path in
        let bytes = Bytes.create len in
        for i = 0 to len - 1 do
          let ch = if is_clear path i then '0' else '1' in
          Bytes.set bytes i ch
        done;
        Bytes.to_string bytes
      let pp (fmt : Format.formatter) : t -> unit = Fn.compose (Format.pp_print_string fmt) show

      let build (dirs : Direction.t list) =
        let path = create_bitstring (List.length dirs) in
        let rec loop i = function
          | []     -> ()
          | h :: t ->
              (if Direction.to_bool h then set path i);
              loop (i + 1) t
        in
        loop 0 dirs;
        path

      let length = bitstring_length

      let copy (path : t) : t =
        let%bitstring path = {| path: -1: bitstring |} in
        path

      let last_direction path = Direction.of_bool (get path (bitstring_length path - 1) = 0)

      (* returns a slice of the original path, so the returned key needs to byte
       * copied before mutating the path *)
      let parent (path : t) : t = subbitstring path 0 (bitstring_length path - 1)

      let child (path : t) (dir : Direction.t) : t =
        let dir_bit = Direction.to_bool dir in
        let%bitstring path = {| path: -1: bitstring; dir_bit: 1 |} in
        path

      let sibling (path : t) : t =
        let path = copy path in
        let last_bit_index = length path - 1 in
        let last_bit = get path last_bit_index <> 0 in
        let flip = if last_bit then clear else set in
        flip path last_bit_index;
        path

      let next (path : t) : t = 
        let path = copy path in
        let len = length path in

        let rec find_first_clear_bit i =
          if i < 0 then raise Out_of_paths else
            if is_clear path i then i else 
              find_first_clear_bit (i - 1)
        in
        let rec clear_bits i =
          if i >= len then () else (
            clear path i;
            clear_bits (i + 1))
        in

        let first_clear_index = find_first_clear_bit (len - 1) in
        set path first_clear_index;
        clear_bits (first_clear_index + 1);
        path

      let serialize (path : t) : Bigstring.t =
        let path_bstr = Bigstring.of_string (Bitstring.string_of_bitstring path) in
        let path_bstr_len = Bigstring.length path_bstr in
        assert (path_bstr_len <= path_byte_count);
        let required_padding = path_byte_count - path_bstr_len in
        let padding = Bigstring.create required_padding in
        Bigstring.concat [path_bstr; padding]
    end

    module Prefix = struct
      type t = UInt8.t
      let generic = UInt8.of_int 0xff
      let account = UInt8.of_int 0xfe
      let hash depth = UInt8.of_int (max_depth - depth)
    end

    type t =
      | Generic of Bigstring.t
          [@printer (fun fmt bstr -> Format.pp_print_string fmt (Bigstring.to_string bstr))]
      | Account of Path.t
      | Hash    of Path.t
    [@@deriving show]
    type binary = Bigstring.t

    let is_generic = function Generic _ -> true | _ -> false
    let is_account = function Account _ -> true | _ -> false
    let is_hash = function Hash _ -> true | _ -> false

    let depth : t -> int = function
      | Generic _    -> raise (Invalid_argument "depth: generic key has no depth")
      | Account _    -> 0
      | Hash path    -> max_depth - Path.length path
    let path : t -> Path.t = function
      | Generic data -> raise (Invalid_argument "last_direction: generic key has not directions")
      | Account path
      | Hash path    -> path

    let root_hash : t = Hash (Bitstring.create_bitstring 0)
    let build_generic (data : Bigstring.t) : t = Generic data
    let build_empty_account () : t = Account (Bitstring.create_bitstring max_depth)
    let build_account (path : Path.Direction.t list) : t =
      assert (List.length path = max_depth);
      Account (Path.build path)
    let build_hash (path : Path.Direction.t list) : t =
      assert (List.length path <= max_depth);
      Hash (Path.build path)

    let parse (str : Bigstring.t) : t =
      let prefix = Bigstring.get str 0 |> Char.to_int |> UInt8.of_int in
      let data = Bigstring.sub str ~pos:1 ~len:(Bigstring.length str - 1) in
      if prefix = Prefix.generic then
        Generic data
      else
        let path = Bitstring.bitstring_of_string (Bigstring.to_string data) in
        let slice_path = Bitstring.subbitstring path 0 in
        if prefix = Prefix.account then
          Account (slice_path max_depth)
        else if UInt8.to_int prefix <= max_depth then
          Hash (slice_path (max_depth - UInt8.to_int prefix))
        else
          raise Invalid_binary_key

    let prefix_bigstring prefix src =
      let src_len = Bigstring.length src in
      let dst = Bigstring.create (src_len + 1) in
      Bigstring.set dst 0 (Char.of_int_exn (UInt8.to_int prefix));
      Bigstring.blit ~src ~src_pos:0 ~dst ~dst_pos:1 ~len:src_len;
      dst
    let serialize = function
      | Generic data -> prefix_bigstring Prefix.generic data
      | Account path ->
          assert (Path.length path = max_depth);
          prefix_bigstring Prefix.account (Path.serialize path)
      | Hash path    ->
          assert (Path.length path <= max_depth);
          prefix_bigstring (Prefix.hash (Path.length path)) (Path.serialize path)

    let copy_bigstring (bstr : Bigstring.t) : Bigstring.t =
      let len = Bigstring.length bstr in
      let bstr' = Bigstring.create len in
      Bigstring.blit ~src:bstr ~src_pos:0 ~dst:bstr' ~dst_pos:0 ~len;
      bstr'
    let copy : t -> t = function
      | Generic data -> Generic (copy_bigstring data)
      | Account path -> Account (Path.copy path)
      | Hash path    -> Hash (Path.copy path)


    (* returns a slice of the original path, so the returned key needs to byte
     * copied before mutating the path *)
    let parent : t -> t = function
      | Generic _ -> raise (Invalid_argument "parent: generic keys have no parent")
      | Account _ -> raise (Invalid_argument "parent: account keys have no parent")
      | Hash path -> assert (Path.length path > 0); Hash (Path.parent path)

    let child (key : t) (dir : Path.Direction.t) : t =
      match key with
        | Generic _ -> raise (Invalid_argument "child: generic keys have no child")
        | Account _ -> raise (Invalid_argument "child: account keys have no child")
        | Hash path -> assert (Path.length path < max_depth); Hash (Path.child path dir)

    let next : t -> t = function
      | Generic _    -> raise (Invalid_argument "next: generic keys have no next key")
      | Account path -> Account (Path.next path)
      | Hash path    -> Hash (Path.next path)

    let sibling : t -> t = function
      | Generic _    -> raise (Invalid_argument "sibling: generic keys have no sibling")
      | Account path -> Account (Path.sibling path)
      | Hash path    -> Hash (Path.sibling path)

    let order_siblings (key: t) (base: 'a) (sibling: 'a) : 'a * 'a =
      match Path.last_direction (path key) with
        | Left  -> (base, sibling)
        | Right -> (sibling, base)

    let gen_account =
      let open Quickcheck.Let_syntax in
      let%map dirs = Quickcheck.Generator.list_with_length Depth.depth Path.Direction.gen in
      build_account dirs
  end

  type key = Key.t [@@deriving show]
  type t = { kvdb: KVDB.t; sdb: SDB.t }

  exception Key_not_found of key

  let create ~key_value_db_dir ~stack_db_file =
    let kvdb = KVDB.create key_value_db_dir in
    let sdb = SDB.create stack_db_file in
    { kvdb; sdb }

  let destroy { kvdb; sdb } =
    KVDB.destroy kvdb;
    SDB.destroy sdb

  let empty_hashes =
    let empty_hashes = Array.create max_depth Hash.empty in
    let rec loop last_hash i =
      (if i < max_depth then (
        let hash = Hash.merge (last_hash, last_hash) in
        empty_hashes.(i) <- hash;
        loop hash (i + 1)))
    in
    loop Hash.empty 1;
    ImmutableArray.wrap empty_hashes

  let get_raw { kvdb; _ } key = KVDB.get kvdb (Key.serialize key)
  let get_bin mdb key bin_read = get_raw mdb key |> Option.map ~f:(fun v -> bin_read v ~pos_ref:(ref 0))
  let get_generic mdb key = assert (Key.is_generic key); get_raw mdb key
  let get_account mdb key = assert (Key.is_account key); get_bin mdb key Account.bin_read_t
  let get_hash mdb key =
    assert (Key.is_hash key);
    match get_bin mdb key Hash.bin_read_t with
      | Some hash -> hash
      | None      -> ImmutableArray.get empty_hashes (Key.depth key)

  let set_raw { kvdb; _ } key bin = KVDB.set kvdb (Key.serialize key) bin
  let set_bin mdb key bin_size bin_write v =
    let size = bin_size v in
    let buf = Bigstring.create size in
    ignore (bin_write buf ~pos:0 v);
    set_raw mdb key buf

  let delete_raw { kvdb; _ } key = KVDB.delete kvdb (Key.serialize key)

  let rec set_hash mdb key new_hash =
    assert (Key.is_hash key);
    set_bin mdb key Hash.bin_size_t Hash.bin_write_t new_hash;

    let depth = Key.depth key in
    (if depth < max_depth then
      let sibling_hash = get_hash mdb (Key.sibling key) in
      let parent_hash = Hash.merge (Key.order_siblings key new_hash sibling_hash) in
      set_hash mdb (Key.parent key) parent_hash)

  let build_key_of_account_key account =
    Key.build_generic (Bigstring.of_string ("$" ^ Account.public_key account))
  let get_key_of_account mdb account =
    get_generic mdb (build_key_of_account_key account)
      |> Option.map ~f:Key.parse
  let set_key_of_account mdb account key =
    set_raw mdb (build_key_of_account_key account) key
  let delete_key_of_account mdb account =
    delete_raw mdb (build_key_of_account_key account)

  let get_next_free_account_key mdb =
    let key = Key.build_generic (Bigstring.of_string "next_free_account_key") in
    let account_key = match get_generic mdb key with
      | None     -> Key.build_empty_account ()
      | Some key -> Key.parse key
    in
    let next_account_key = Key.next account_key in
    set_raw mdb key (Key.serialize next_account_key);
    account_key
  let allocate_account_key mdb account =
    let key = match SDB.pop mdb.sdb with
      | None     -> get_next_free_account_key mdb
      | Some key -> Key.parse key
    in
    set_key_of_account mdb account (Key.serialize key);
    key

  let update_account mdb key account =
    set_bin mdb key Account.bin_size_t Account.bin_write_t account;
    set_hash mdb (Key.Hash (Key.path key)) (Hash.hash_account account)
  let delete_account mdb account =
    match get_key_of_account mdb account with
      | None     -> ()
      | Some key ->
          update_account mdb key Account.empty;
          delete_key_of_account mdb account;
          SDB.push mdb.sdb (Key.serialize key)
  let set_account mdb account =
    if Account.is_empty account then
      delete_account mdb account
    else (
      let key = match get_key_of_account mdb account with
        | Some key -> key
        | None     -> allocate_account_key mdb account
      in
      update_account mdb key account)

  let merkle_root mdb = get_hash mdb Key.root_hash

  let merkle_path mdb key =
    let key = if Key.is_account key then Key.Hash (Key.path key) else key in
    assert (Key.is_hash key);
    let rec loop k =
      get_hash mdb (Key.sibling k) ::
        if Key.depth key < max_depth then loop (Key.parent k) else []
    in
    loop key

  let with_test_instance f =
    let uuid = Uuid.create () in
    let tmp_dir = "/tmp/merkle_database_test-" ^ Uuid.to_string uuid in
    let key_value_db_dir = Filename.concat tmp_dir "kvdb" in
    let stack_db_file = Filename.concat tmp_dir "sdb" in
    assert (Unix.system ("rm -rf " ^ tmp_dir) = Result.Ok ());
    Unix.mkdir tmp_dir;

    let mdb = create ~key_value_db_dir ~stack_db_file in
    let cleanup () =
      destroy mdb;
      assert (Unix.system ("rm -rf " ^ tmp_dir) = Result.Ok ())
    in

    try
      let result = f mdb in
      cleanup ();
      result
    with exn ->
      cleanup ();
      raise exn

  let%test "getting a non existing account returns None" =
    with_test_instance (fun mdb ->
      let key = Quickcheck.random_value Key.gen_account in
      get_account mdb key = None)

  let%test "add and retrieve an account" =
    with_test_instance (fun mdb ->
      let account = Quickcheck.random_value Account.gen in
      set_account mdb account;
      let key = Option.value_exn (get_key_of_account mdb account) in
      Account.equal (Option.value_exn (get_account mdb key)) account)

  let%test "accounts are atomic" =
    with_test_instance (fun mdb ->
      let account = Quickcheck.random_value Account.gen in
      set_account mdb account;
      let key = Option.value_exn (get_key_of_account mdb account) in
      set_account mdb account;
      let key' = Option.value_exn (get_key_of_account mdb account) in
      key = key' && get_account mdb key = get_account mdb key')
end

let%test_module "test functor on in memory databases" = (module struct
  module Account : Account_intf = struct
    type t = { public_key: string; balance: int }
    [@@deriving bin_io, eq]

    let empty = { public_key = ""; balance = 0 }
    let is_empty { balance; _ } = balance = 0
    let public_key { public_key; _ } = public_key

    let gen =
      let open Quickcheck.Let_syntax in
      let%bind public_key = String.gen in
      let%map balance = Int.gen in
      { public_key; balance }

  end

  module Hash : Hash_intf with type account = Account.t = struct
    type t = int [@@deriving bin_io, eq]
    type account = Account.t

    let empty = 0
    let merge : t * t -> t = Hashtbl.hash
    let hash_account : account -> t = Hashtbl.hash
  end

  module In_memory_KVDB : Key_value_database_intf = struct
    type t = (string, Bigstring.t) Hashtbl.t

    let create ~directory = Hashtbl.create (module String)
    let destroy _ = ()
    let get tbl key = Hashtbl.find tbl (Bigstring.to_string key)
    let set tbl key data = Hashtbl.set tbl ~key:(Bigstring.to_string key) ~data
    let delete tbl key = Hashtbl.remove tbl (Bigstring.to_string key)
  end

  module In_memory_SDB : Stack_database_intf = struct
    type t = Bigstring.t list ref

    let create ~filename = ref []
    let destroy _ = ()
    let push ls v = ls := v :: !ls
    let pop ls =
      match !ls with
        | []     -> None
        | h :: t -> ls := t; Some h
  end

  module MDB_D(D : Depth_intf) = Make(Account)(Hash)(D)(In_memory_KVDB)(In_memory_SDB)
  module MDB_D4 = MDB_D(struct let depth = 4 end)
  module MDB_D30 = MDB_D(struct let depth = 30 end)
end)

(* TODO: test on real databases? *)
