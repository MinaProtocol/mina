open Core

(* Addr is an adapter for MerkleDB to be compatible with Syncable ledger.
Syncable ledger assumes that the depth of root is 0 and the depth of the leaves is N - 1 *)
module Make (Input : sig
  val depth : int
end) =
struct
  let of_variant = function
    | `Left -> Direction.Left
    | `Right -> Direction.Right

  let to_variant = function
    | Direction.Left -> `Left
    | Direction.Right -> `Right

  module Addr = Bitstring_address.Make (Input)

  module T = struct
    module Stringable = struct
      type t = (Addr.t[@deriving compare, hash])

      let to_string = Bitstring.string_of_bitstring

      let of_string = Bitstring.bitstring_of_string
    end

    include Stringable
    include Sexpable.Of_stringable (Stringable)
    include Binable.Of_stringable (Stringable)

    let equal a b = compare a b = 0

    let compare = compare

    let hash t = [%hash : string] (Bitstring.string_of_bitstring t)

    let hash_fold_t hash_state t =
      [%hash_fold : string] hash_state (Bitstring.string_of_bitstring t)
  end

  include T
  include Hashable.Make (T)

  let depth t = Input.depth - Bitstring.bitstring_length t

  let parent = Fn.compose Or_error.return Addr.parent

  let parent_exn = Addr.parent

  let child t (dir: [`Left | `Right]) =
    Addr.child t (of_variant dir) |> Or_error.return

  let child_exn t dir = child t dir |> Or_error.ok_exn

  let dirs_from_root t : [`Left | `Right] list =
    List.init (Addr.length t) ~f:(fun pos ->
        Direction.of_bool (Bitstring.is_set t pos) )
    |> List.map ~f:to_variant

  let root = Bitstring.create_bitstring 0

  let of_direction dirs = List.fold dirs ~f:child_exn ~init:root
end
