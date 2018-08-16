open Core
open Bitstring

module type S = sig
  type t [@@deriving sexp, bin_io, hash, eq, compare]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving sexp, bin_io, hash, eq, compare]
    end
  end

  include Hashable.S with type t := t

  val parent : t -> t Or_error.t

  val child : t -> Direction.t -> t Or_error.t

  val child_exn : t -> Direction.t -> t

  val parent_exn : t -> t

  val dirs_from_root : t -> Direction.t list

  val root : t

  val sibling : t -> t

  val next : t -> t Option.t

  val serialize : t -> Bigstring.t

  val fold_sequence_incl : t -> t -> init:'a -> f:(t -> 'a -> 'a) -> 'a

  val width : t -> t * t

  val depth : t -> int

  val height : t -> int
end

module Make (Input : sig
  val depth : int
end) =
struct
  let byte_count_of_bits n = (n / 8) + min 1 (n % 8)

  let path_byte_count = byte_count_of_bits Input.depth

  let depth = Bitstring.bitstring_length

  let height path = Input.depth - Bitstring.bitstring_length path

  let build (dirs: Direction.t list) =
    let path = create_bitstring (List.length dirs) in
    let rec loop i = function
      | [] -> ()
      | h :: t ->
          if Direction.to_bool h then set path i ;
          loop (i + 1) t
    in
    loop 0 dirs ; path

  let show (path: Bitstring.t) : string =
    let len = bitstring_length path in
    let bytes = Bytes.create len in
    for i = 0 to len - 1 do
      let ch = if is_clear path i then '0' else '1' in
      Bytes.set bytes i ch
    done ;
    Bytes.to_string bytes

  let add_padding path =
    let length = depth path in
    if length mod 8 = 0 then path
    else
      Bitstring.concat [path; Bitstring.zeroes_bitstring (8 - (length mod 8))]

  module Stable = struct
    module V1 = struct
      let to_tuple path =
        let length = depth path in
        let padded_bitstring = add_padding path in
        (length, Bitstring.string_of_bitstring padded_bitstring)

      let of_tuple (length, string) =
        Bitstring.subbitstring (Bitstring.bitstring_of_string string) 0 length

      module T = struct
        type t = (Bitstring.t[@deriving compare])

        let sexp_of_t = Fn.compose sexp_of_string show

        let t_of_sexp =
          let of_string buf =
            String.to_list buf
            |> List.map ~f:(Fn.compose Direction.of_int Char.to_int)
            |> build
          in
          Fn.compose of_string string_of_sexp

        let hash = Fn.compose [%hash : int * string] to_tuple

        let hash_fold_t hash_state t =
          [%hash_fold : int * string] hash_state (to_tuple t)

        let compare = compare

        let equal = equals
      end

      include T
      include Hashable.Make (T)

      include Binable.Of_binable (struct
                  type t = int * string [@@deriving bin_io]
                end)
                (struct
                  type nonrec t = t

                  let to_binable = to_tuple

                  let of_binable = of_tuple
                end)
    end
  end

  include Stable.V1

  let pp (fmt: Format.formatter) : t -> unit =
    Fn.compose (Format.pp_print_string fmt) show

  let equals = equals

  let copy (path: t) : t =
    let%bitstring path = {| path: -1: bitstring |} in
    path

  let last_direction path =
    Direction.of_bool (get path (bitstring_length path - 1) = 0)

  (* returns a slice of the original path, so the returned key needs to byte
       * copied before mutating the path *)
  let parent (path: t) =
    subbitstring path 0 (bitstring_length path - 1) |> Or_error.return

  let parent_exn = Fn.compose Or_error.ok_exn parent

  let child (path: t) dir : t Or_error.t =
    let dir_bit = Direction.to_bool dir in
    let%bitstring path = {| path: -1: bitstring; dir_bit: 1|} in
    Or_error.return path

  let child_exn (path: t) dir : t = child path dir |> Or_error.ok_exn

  let dirs_from_root t =
    List.init (depth t) ~f:(fun pos ->
        Direction.of_bool (Bitstring.is_set t pos) )

  let root = Bitstring.create_bitstring 0

  let sibling (path: t) : t =
    let path = copy path in
    let last_bit_index = depth path - 1 in
    let last_bit = get path last_bit_index <> 0 in
    let flip = if last_bit then clear else set in
    flip path last_bit_index ; path

  let next (path: t) : t Option.t =
    let open Option.Let_syntax in
    let path = copy path in
    let len = depth path in
    let rec find_first_clear_bit i =
      if i < 0 then None
      else if is_clear path i then Some i
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

  let serialize path =
    let path = add_padding path in
    let path_len = depth path in
    let required_bits = 8 * path_byte_count in
    assert (path_len <= required_bits) ;
    let required_padding = required_bits - path_len in
    Bigstring.of_string @@ Bitstring.string_of_bitstring
    @@ Bitstring.concat [path; Bitstring.zeroes_bitstring required_padding]

  let rec fold_sequence_exl first last ~init ~f =
    let comparison = Bitstring.compare first last in
    if comparison > 0 then
      raise (Invalid_argument "first address needs to precede last address")
    else if comparison = 0 then init
    else
      fold_sequence_exl
        (next first |> Option.value_exn)
        last ~init:(f first init) ~f

  let fold_sequence_incl first last ~init ~f =
    f last @@ fold_sequence_exl first last ~init ~f

  let width address =
    let first_node =
      Bitstring.concat [address; Bitstring.zeroes_bitstring @@ height address]
    in
    let last_node =
      Bitstring.concat [address; Bitstring.ones_bitstring @@ height address]
    in
    (first_node, last_node)

  let to_index a =
    List.foldi
      (List.rev @@ dirs_from_root a)
      ~init:0
      ~f:(fun i acc dir -> acc lor (Direction.to_int dir lsl i))

  let%test "the merkle root should have no path" = dirs_from_root root = []

  let%test_unit "parent_exn(child_exn(node)) = node" =
    Quickcheck.test ~sexp_of:[%sexp_of : Direction.t List.t * Direction.t]
      (Quickcheck.Generator.tuple2
         (Direction.gen_list Input.depth)
         Direction.gen)
      ~f:(fun (path, direction) ->
        let address = build path in
        [%test_eq : t] (parent_exn (child_exn address direction)) address )
end

let%test_module "Address" =
  ( module struct
    module Test4 = Make (struct
      let depth = 4
    end)

    module Test16 = Make (struct
      let depth = 16
    end)
  end )
