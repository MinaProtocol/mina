open Core
open Unsigned

module type Account_intf = sig
  type t [@@deriving bin_io, eq]

  val public_key : t -> string
end

module type Hash_intf = sig
  type t [@@deriving bin_io, eq]
  type account

  val merge : t * t -> t
  val merge_accounts : account * account -> t
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

  val lookup_account_key : t -> public_key:string -> key option

  val get : t -> key -> account option
  val set_key : t -> key -> account -> unit
  val set_account : t -> account -> unit
  val update : t -> key -> f:(account option -> account) -> unit

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

  (* A key in the merkle database is structured as follows:
   *   1 byte  | node depth
   *   N bytes | bitstring where each bit represents the path to reach a node 
   *             from the root (0 for left, 1 for right)
   * (where N is the number of bytes needed to store M bits, and M is the max
   * depth of the tree)
   *)
  module Key = struct
    type t = UInt8.t * Bitstring.t
    type serialized = Bigstring.t

    type direction = Left | Right
    let bit_of_direction = function
      | Left  -> false
      | Right -> true
    let flip_direction = function
      | Left  -> Right
      | Right -> Left

    let path_byte_count = Depth.depth / 8 + min 1 (Depth.depth % 8)

    let depth ((depth, _) : t) : int = UInt8.to_int depth
    let copy ((depth, path) : t) : t =
      let%bitstring new_path = {| path: -1: bitstring |} in
      (depth, new_path)

    let parse (str : Bigstring.t) : t =
      let depth = Bigstring.get str 0 |> Char.to_int |> UInt8.of_int in
      let path =
        Bigstring.sub str ~pos:1 ~len:(Bigstring.length str - 2)
          |> Bigstring.to_string
          |> Bitstring.bitstring_of_string
      in
      (depth, path)

    let build_empty () : t =
      (UInt8.zero, Bitstring.create_bitstring (path_byte_count * 8))

    let build (dir_path : direction list) : t =
      let path_len = List.length dir_path in
      let depth = UInt8.of_int (Depth.depth - path_len - 1) in
      let path = Bitstring.create_bitstring path_len in
      let rec loop i = function
        | [] -> ()
        | dir_head :: dir_tail ->
            (if bit_of_direction dir_head then Bitstring.set path i);
            loop (i + 1) dir_tail
      in
      loop 0 dir_path;
      (depth, path)

    (* Builds a raw key that exists outside of the merkle tree. No key in the
     * merkle tree should have a depth index equal to the max depth, so raw keys
     * are encoded with a depth of that value to ensure uniqueness. *)
    let build_raw (str : string) : t = (UInt8.of_int Depth.depth, Bitstring.bitstring_of_string str)

    let last_direction ((_, path) : t) : direction =
      if Bitstring.get path (Bitstring.bitstring_length path - 1) = 0 then
        Left
      else
        Right

    (* returns a slice of the original path, so the returned key needs to byte
     * copied before mutating the path *)
    let parent ((depth, path) : t) : t =
      let path_len = Bitstring.bitstring_length path in
      (UInt8.Infix.(depth - UInt8.one), Bitstring.subbitstring path 0 (path_len - 1))

    let child ((depth, path) : t) (dir : direction) : t =
      let dir_bit = bit_of_direction dir in
      let%bitstring child_path = {| path: -1: bitstring; dir_bit: 1 |} in
      (UInt8.Infix.(depth - UInt8.one), child_path)

    let next (key : t) : t =
      let (depth, path) = copy key in
      let path_len = Bitstring.bitstring_length path in
      let rec find_first_clear_bit i =
        if i < 0 then raise Database_keys_exhausted else
          if Bitstring.is_clear path i then i else 
            find_first_clear_bit (i - 1)
      in
      let rec clear_bits i =
        if i >= path_len then () else (
          Bitstring.clear path i;
          clear_bits (i + 1))
      in

      let first_clear_index = find_first_clear_bit (path_len - 1) in
      Bitstring.set path first_clear_index;
      clear_bits (first_clear_index + 1);
      (depth, path)

    let sibling (key : t) : t =
      let (depth, path) = copy key in
      let last_bit_index = Bitstring.bitstring_length path - 1 in
      let last_bit = Bitstring.get path last_bit_index <> 0 in
      let flip_fn = if last_bit then Bitstring.clear else Bitstring.set in
      flip_fn path last_bit_index;
      (depth, path)

    let serialize ((depth, path) : t) : serialized =
      let path_bytes = path |> Bitstring.string_of_bitstring |> Bigstring.of_string in
      let path_bytes_len = Bigstring.length path_bytes in
      let bytes = Bigstring.create (1 + path_byte_count) in
      assert (path_bytes_len <= path_byte_count);
      Bigstring.set bytes 0 (depth |> UInt8.to_int |> Char.of_int_exn);
      Bigstring.blit ~src:path_bytes ~src_pos:0 ~dst:bytes ~dst_pos:1 ~len:path_bytes_len;
      bytes
  end

  type key = Key.t
  (* TODO: add batched write layer *)
  type t = { kvdb: KVDB.t; sdb: SDB.t }

  exception Key_not_found of key

  let create kvdb_dir sdb_file =
    let kvdb = KVDB.create kvdb_dir in
    let sdb = SDB.create sdb_file in
    { kvdb; sdb }

  let destroy { kvdb; sdb } =
    KVDB.destroy kvdb;
    SDB.destroy sdb

  let assert_account_key key = assert (Key.depth key = 0)

  let get_raw { kvdb; _ } key = KVDB.get kvdb (Key.serialize key)
  let get_raw_exn mdb key =
    get_raw mdb key |> Option.value_exn ~error:(Base.Error.of_exn (Key_not_found key))
  let get_bin mdb key bin_read =
    Option.map (get_raw mdb key) ~f:(fun bin -> bin_read bin ~pos_ref:(ref 0))
  let get_bin_exn mdb key bin_read =
    bin_read (get_raw_exn mdb key) ~pos_ref:(ref 0)
  let get mdb key =
    assert_account_key key;
    get_bin mdb key Account.bin_read_t
  let get_exn mdb key =
    assert_account_key key;
    get_bin_exn mdb key Account.bin_read_t
  let get_hash_exn mdb key = get_bin_exn mdb key Hash.bin_read_t

  let lookup_account_key mdb ~public_key =
    get_raw mdb (Key.build_raw public_key)
      |> Option.map ~f:Key.parse

  (* given a key, the node of that key, and it's sibling, return a
   * tuple of the two nodes in the order (left, right) *)
  let order_siblings key base_node sibling_node =
    match Key.last_direction key with
      | Left  -> (base_node, sibling_node)
      | Right -> (sibling_node, base_node)

  let set_raw { kvdb; _ } key bin = KVDB.set kvdb (Key.serialize key) bin
  let set_bin mdb key bin_size bin_write v =
    let size = bin_size v in
    let buf = Bigstring.create size in
    ignore (bin_write buf ~pos:0 v);
    set_raw mdb key buf

  (* TODO: batch writes/transactions *)
  let rec update_hash mdb key new_hash =
    set_bin mdb key Hash.bin_size_t Hash.bin_write_t new_hash;
    (if Key.depth key < Depth.depth - 1 then
      let sibling_hash = get_hash_exn mdb (Key.sibling key) in
      let parent_hash = Hash.merge (order_siblings key new_hash sibling_hash) in
      update_hash mdb (Key.parent key) parent_hash)
  let set_key mdb key account =
    assert_account_key key;
    set_bin mdb key Account.bin_size_t Account.bin_write_t account;
    let sibling = get_exn mdb (Key.sibling key) in
    let parent_hash = Hash.merge_accounts (order_siblings key account sibling) in
    update_hash mdb (Key.parent key) parent_hash

  (* TODO: will this always be unique from public keys? *)
  let next_account_key = Key.build_raw "next_account_key"
  let get_next_available_account mdb =
    get_raw mdb next_account_key
      |> Option.map ~f:Key.parse
      |> Option.value ~default:(Key.build_empty ())
  let set_next_available_account_key mdb key =
    set_raw mdb next_account_key (Key.serialize key)
  let allocate_account_key mdb account =
    let key = match SDB.pop mdb.sdb with
      | None     -> get_next_available_account mdb
      | Some key -> Key.parse key
    in
    set_next_available_account_key mdb (Key.next key);
    key

  let set_account mdb account =
    let key = match lookup_account_key mdb (Account.public_key account) with
      | None     -> allocate_account_key mdb account
      | Some key -> key
    in
    set_key mdb key account

  let update mdb key ~f = get mdb key |> f |> set_account mdb

  let merkle_root mdb = get_hash_exn mdb (Key.build [])

  let rec merkle_hash_path mdb key =
    let hash = get_hash_exn mdb (Key.sibling key) in
    hash :: if Key.depth key < Depth.depth - 1 then merkle_hash_path mdb (Key.parent key) else []
  let merkle_path mdb key =
    (get_exn mdb (Key.sibling key), merkle_hash_path mdb (Key.parent key))

  let with_test_instance f =
    let kv_db_dir = "/tmp/merkle_database_kv" in
    let stack_db_file = "/tmp/merkle_database_stack" in
    assert (Unix.system ("rm -rf " ^ kv_db_dir) = Result.Ok ());
    Unix.remove stack_db_file;
    let mdb = create kv_db_dir stack_db_file in
    let result = f mdb in
    destroy mdb;
    result

  let gen_account_key () =
    let gen_dir () = if Random.bool () then Key.Left else Key.Right in
    let rec gen_dir_ls i = if i = Depth.depth then [] else gen_dir () :: gen_dir_ls (i + 1) in
    Key.build (gen_dir_ls 0)

  let%test "getting a non existing account returns None" =
    with_test_instance (fun mdb -> get mdb (gen_account_key ()) = None)

  let%test "add and retrieve and account" =
    with_test_instance (fun mdb ->
      let account = gen_account () in
      set_account mdb account;
      let key = lookup_account_key (Account.public_key account) in
      Account.eq (get_key mdb key) account)

  let%test "accounts are atomic" =
    with_test_instance (fun mdb ->
      let account = gen_account () in
      let pkey = Account.public_key in
      set_account mdb account;
      let key = lookup_account_key pkey in
      set_account mdb account;
      let key' = lookup_account_key pkey in
      key = key' && get_key mdb key = get_key mdb key')
end
