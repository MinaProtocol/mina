open Core
open Bitstring

module Make (Input : sig
  val depth : int
end) =
struct
  let byte_count_of_bits n = (n / 8) + min 1 (n % 8)

  (* [@@deriving sexp, bin_io, hash, eq, compare]

  include Hashable.S with type t := t *)
  (* include Hashable.Make (Bitstring) *)

  let path_byte_count = byte_count_of_bits Input.depth

  type t = (Bitstring.t[@deriving compare, hash])

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
        raise
          (Invalid_argument "first address needs to precede last address")
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
          [ address
          ; Bitstring.zeroes_bitstring @@ (Input.depth - length address) ]
      in
      let last_node =
        Bitstring.concat
          [ address
          ; Bitstring.ones_bitstring @@ (Input.depth - length address) ]
      in
      (first_node, last_node)
end
