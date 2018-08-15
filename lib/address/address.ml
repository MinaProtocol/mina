open Core
open Bitstring
module Direction = struct
  type t = Left | Right

  let of_bool = function false -> Left | true -> Right

  let to_bool = function Left -> false | Right -> true

  let flip = function Left -> Right | Right -> Left

  let gen = Quickcheck.Let_syntax.(Quickcheck.Generator.bool >>| of_bool)

  let gen_list depth =
    let open Quickcheck.Generator in
    let open Let_syntax in
    let%bind l = Int.gen_incl 0 (depth - 1) in
    list_with_length l (Bool.gen >>| fun b -> if b then `Right else `Left)
end

module type S = sig
  type t [@@deriving sexp, bin_io, hash, eq, compare]

  include Hashable.S with type t := t

  val depth : t -> int

  val parent : t -> t Or_error.t

  val child : t -> [`Left | `Right] -> t Or_error.t

  val child_exn : t -> [`Left | `Right] -> t

  val parent_exn : t -> t

  val dirs_from_root : t -> [`Left | `Right] list

  val root : t
end

module Make (Input : sig
  val depth : int
end) =
struct
  let byte_count_of_bits n = (n / 8) + min 1 (n % 8)

  let of_variant = function
    | `Left -> Direction.Left
    | `Right -> Direction.Right

  let to_variant = function
    | Direction.Left -> `Left
    | Direction.Right -> `Right

  let path_byte_count = byte_count_of_bits Input.depth

  type int_rep = (int * string[@deriving hash, bin_io])

  let length = bitstring_length

  let to_intermediate_representation bitstring =
    let size = length bitstring in
    let padded_bitstring =
      if size mod 8 = 0 then bitstring
      else
        Bitstring.concat
          [bitstring; Bitstring.zeroes_bitstring (8 - (size mod 8))]
    in
    (size, Bitstring.string_of_bitstring padded_bitstring)

  let show (path: Bitstring.t) : string =
    let len = bitstring_length path in
    let bytes = Bytes.create len in
    for i = 0 to len - 1 do
      let ch = if is_clear path i then '0' else '1' in
      Bytes.set bytes i ch
    done ;
    Bytes.to_string bytes

  module Stable = struct
    module V1 = struct
      type t = (Bitstring.t[@deriving sexp, bin_io, eq, compare, hash])

      let sexp_of_t = Fn.compose sexp_of_string show

      let t_of_sexp =
        Fn.compose
          (fun (buf: string) ->
            let len = String.length buf in
            let bitstring = Bitstring.create_bitstring (String.length buf) in
            for i = 0 to len - 1 do
              match buf.[i] with
              | '1' -> Bitstring.set bitstring i
              | '0' -> ()
              | char ->
                  failwith
                  @@ sprintf "cannot convert to address (invalid char: %c)"
                       char
            done ;
            bitstring )
          string_of_sexp

      let hash =
        Fn.compose [%hash : int * string] to_intermediate_representation

      let hash_fold_t hash_state t =
        [%hash_fold : int * string] hash_state
          (to_intermediate_representation t)

      let compare = compare

      let equal = equals
    end
  end

  include Stable.V1
  include Hashable.Make (Stable.V1)
  (* TODO: Find a better way to do this *)
  include Binable.Of_sexpable (Stable.V1)

  let pp (fmt: Format.formatter) : t -> unit =
    Fn.compose (Format.pp_print_string fmt) show

  let equals = equals

  let build (dirs: Direction.t list) =
    let path = create_bitstring (List.length dirs) in
    let rec loop i = function
      | [] -> ()
      | h :: t ->
          if Direction.to_bool h then set path i ;
          loop (i + 1) t
    in
    loop 0 dirs ; path

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

  let child (path: t) (dir: [`Left | `Right]) : t Or_error.t =
    let dir_bit = Direction.to_bool (of_variant dir) in
    let%bitstring path = {| path: -1: bitstring; dir_bit: 1|} in
    Or_error.return path

  let child_exn (path: t) (dir: [`Left | `Right]) : t =
    child path dir |> Or_error.ok_exn

  let dirs_from_root t : [`Left | `Right] list =
    List.init (length t) ~f:(fun pos ->
        Direction.of_bool (Bitstring.is_set t pos) )
    |> List.map ~f:to_variant

  let root = Bitstring.create_bitstring 0

  let sibling (path: t) : t =
    let path = copy path in
    let last_bit_index = length path - 1 in
    let last_bit = get path last_bit_index <> 0 in
    let flip = if last_bit then clear else set in
    flip path last_bit_index ; path

  let next (path: t) : t Option.t =
    let open Option.Let_syntax in
    let path = copy path in
    let len = length path in
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

  let depth t = Input.depth - Bitstring.bitstring_length t

  (* TODO: Put serialize into Merkle Database *)
  let serialize (path: t) : Bigstring.t =
    let path =
      if length path mod 8 = 0 then path
      else
        Bitstring.concat
          [path; Bitstring.zeroes_bitstring (8 - (length path mod 8))]
    in
    let path_len = length path in
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

  let compute_width address =
    let first_node =
      Bitstring.concat
        [address; Bitstring.zeroes_bitstring @@ (Input.depth - length address)]
    in
    let last_node =
      Bitstring.concat
        [address; Bitstring.ones_bitstring @@ (Input.depth - length address)]
    in
    (first_node, last_node)
end
