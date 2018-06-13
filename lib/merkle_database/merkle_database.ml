open Core
open Stdint

module type Account = sig
  type t [@@deriving bin_io]
end

module type Hash = sig
  type t [@@deriving bin_io]
  type account

  val merge : t -> t -> t
  val merge_account : account -> account -> t
end

module type Depth = sig
  val depth : int
end

module type Database_intf = sig
  type t

  val create : directory:string -> t
  val get : t -> Bigstring.t -> Bigstring.t option
end

module type S = sig
  type account
  type hash

  type key
  type path
  type t

  val lookup_account_key : t -> public_key:string -> key

  val get : t -> key -> account option
  val set : t -> key -> account -> unit
  val update : t -> key -> f:(account option -> account) -> unit

  val merkle_root : t -> hash
  val merkle_path : t -> key -> path
end

module Make
  (Account : Account_intf)
  (Hash : Hash_intf with type account = Account.t)
  (Depth : Depth_intf)
  (Database : Database_intf)
  : S with type account = Account.t 
       and type hash = Hash.t
  = struct

  (* A key in the merkle database is structured as follows:
   *   1 byte  | node depth
   *   N bytes | bitstring where each bit represents the path to reach a node 
   *             from the root (0 for left, 1 for right)
   * (where N is the number of bytes needed to store M bits, and M is the max
   * depth of the tree)
   *)
  module Key = struct
    type t = uint8_t * Bitstring.t
    type serialized = bytes

    type direction = Left | Right
    let bit_of_direction = function
      | Left  -> false
      | Right -> true
    let flip_direction = function
      | Left  -> Right
      | Right -> Left

    let path_byte_count = Depth.depth / 8 + min 1 (Depth.depth % 8)

    let depth ((depth, _) : t) : int = Uint8.to_int depth
    let copy ((depth, path) : t) : t = (depth, BITSTRING { path : bitstring })

    let build (dir_path : direction list) : t =
      let path_len = List.length dir_path in
      let depth = Depth.depth - path_len - 1 in
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
    let build_raw str = (Depth.depth, Bigstring.bigstring_of_string str)

    let last_direction ((_, path) : t) : direction =
      if Bitstring.get path (Bitstring.bitstring_length path - 1) = 0 then
        Left
      else
        Right

    (* returns a slice of the original path, so the returned key needs to byte
     * copied before mutating the path *)
    let parent ((depth, path) : t) : t =
      let path_len = Bitstring.bitstring_length path in
      (depth + 1, Bitstring.subbitstring path 0 (path_len - 1))

    let child ((depth, path) : t) (dir : direction) : t =
      let dir_bit = bit_of_direction dir in
      let child_path = BITSTRING
        { path : bitstring
        ; dir_bit : 1
        }
      in
      (depth - 1, child_path)

    let sibling (key : t) : t =
      let (depth, path) = copy key in
      let last_bit_index = Bitstring.bitstring_length path - 1 in
      let last_bit = Bitstring.get path last_bit_index <> 0 in
      let flip_fn = if last_bit then Bitstring.clear else Bitstring.set in
      flip_fn path last_bit_index;
      (depth, path)

    let serialize ((depth, path) : t) : serialized =
      let path_bytes = Bitstring.string_of_bitstring path in
      let path_bytes_len = Bytes.length path_bytes in
      let bytes = Bytes.make (1 + path_byte_count) '\x00' in
      assert (path_bytes_len <= path_byte_count);
      Bytes.set bytes 0 (Uint8.to_char depth);
      Bytes.blit path_bytes 0 bytes 1 path_bytes_len;
      bytes
  end

  type key = Key.t
  (* TODO: add batched write layer *)
  type t = { db: Database.t }

  let assert_account_key key = assert (Key.depth key = 0)

  let get_raw mdb key = Database.get mdb.db (Key.serialize key)
  let get_raw_exn mdb key =
    Option.value_exn ~error:(Key_not_found key) get_raw mdb key
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

  (* given a key, the node of that key, and it's sibling, return a
   * tuple of the two nodes in the order (left, right) *)
  let order_siblings key base_node sibling_node =
    match Key.last_direction key with
      | Left  -> (base_node, sibling_node)
      | Right -> (sibling_node, base_node)

  let set_raw mdb key bin = Database.set mdb.db (Key.serialize key) bin
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

  let set mdb key account =
    assert_account_key key;
    set_bin mdb key Account.bin_size_t Account.bin_write_t account;
    let sibling = get_exn mdb (Key.sibling key) in
    let parent_hash = Hash.merge_accounts (order_siblings key account sibling) in
    update_hash mdb (Key.parent key) parent_hash

  let update mdb key ~f = get mdb key |> f |> set mdb key

  let lookup_account_key mdb ~public_key =
    Bigstring.to_string (get_raw_exn mdb (Key.build_raw public_key))

  let merkle_root mdb = get_hash_exn mdb (Key.build [])

  let rec merkle_hash_path mdb key =
    let hash = get_hash_exn mdb (Key.sibling key) in
    hash :: if Key.depth key < Depth.depth - 1 then merkle_hash_path mdb (Key.parent key) else []
  let merkle_path mdb key =
    (get_exn mdb (Key.sibling key), merkle_hash_path mdb (Key.parent key))
end
