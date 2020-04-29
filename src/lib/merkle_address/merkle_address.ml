open Core
open Bitstring

module type S = sig
  type t [@@deriving sexp, hash, eq, compare, to_yojson]

  module Stable : sig
    module V1 : sig
      val version : int

      type nonrec t = t
      [@@deriving sexp, bin_io, hash, eq, compare, to_yojson, version]
    end

    module Latest : module type of V1
  end

  include Hashable.S_binable with type t := t

  val of_byte_string : string -> t

  val of_directions : Direction.t list -> t

  val root : unit -> t

  val slice : t -> int -> int -> t

  val get : t -> int -> int

  val copy : t -> t

  val parent : t -> t Or_error.t

  val child : t -> Direction.t -> t Or_error.t

  val child_exn : t -> Direction.t -> t

  val parent_exn : t -> t

  val dirs_from_root : t -> Direction.t list

  val sibling : t -> t

  val next : t -> t Option.t

  val prev : t -> t Option.t

  val is_leaf : t -> bool

  val is_parent_of : t -> maybe_child:t -> bool

  val serialize : t -> Bigstring.t

  val to_string : t -> string

  val pp : Format.formatter -> t -> unit

  module Range : sig
    type nonrec t = t * t

    val fold :
         ?stop:[`Inclusive | `Exclusive]
      -> t
      -> init:'a
      -> f:(Stable.Latest.t -> 'a -> 'a)
      -> 'a

    val subtree_range : Stable.V1.t -> t

    val subtree_range_seq : Stable.V1.t -> Stable.V1.t Sequence.t
  end

  val depth : t -> int

  val height : t -> int

  val to_int : t -> int

  val of_int_exn : int -> t
end

module T = struct
  let depth = bitstring_length

  let add_padding path =
    let length = depth path in
    if length mod 8 = 0 then path
    else concat [path; zeroes_bitstring (8 - (length mod 8))]

  let slice = subbitstring

  let to_string path : string =
    let len = depth path in
    let bytes = Bytes.create len in
    for i = 0 to len - 1 do
      let ch = if is_clear path i then '0' else '1' in
      Bytes.set bytes i ch
    done ;
    Bytes.to_string bytes

  let of_directions dirs =
    let path = create_bitstring (List.length dirs) in
    let rec loop i = function
      | [] ->
          ()
      | h :: t ->
          if Direction.to_bool h then set path i ;
          loop (i + 1) t
    in
    loop 0 dirs ; path

  let to_yojson t = `String (to_string t)

  let to_tuple path =
    let length = depth path in
    let padded_bitstring = add_padding path in
    (length, string_of_bitstring padded_bitstring)

  let of_tuple (length, string) = slice (bitstring_of_string string) 0 length

  module Binable_arg = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = int * string

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      type t = Bitstring.t

      let to_latest = Fn.id

      include Binable.Of_binable
                (Binable_arg.Stable.V1)
                (struct
                  type nonrec t = t

                  let to_binable = to_tuple

                  let of_binable = of_tuple
                end)

      let sexp_of_t = Fn.compose sexp_of_string to_string

      let t_of_sexp =
        let of_string buf =
          String.to_list buf
          |> List.map ~f:(Fn.compose Direction.of_int_exn Char.to_int)
          |> of_directions
        in
        Fn.compose of_string string_of_sexp

      let hash = Fn.compose [%hash: int * string] to_tuple

      let hash_fold_t hash_state t =
        [%hash_fold: int * string] hash_state (to_tuple t)

      let compare = compare

      let equal = equals

      let to_yojson = to_yojson
    end
  end]
end

module Stable = T.Stable

module Make (Input : sig
  val depth : int
end) : S = struct
  (* TODO: this "include" puts a stable-versioned type inside a functor
     (hard to detect this statically)
     that should be hoisted outside the functor
  *)

  include T

  let byte_count_of_bits n = (n / 8) + min 1 (n % 8)

  let path_byte_count = byte_count_of_bits Input.depth

  let height path = Input.depth - depth path

  let get = get

  type t = Stable.Latest.t

  [%%define_locally
  Stable.Latest.(t_of_sexp, sexp_of_t, to_yojson, compare, equal)]

  include Hashable.Make_binable (Stable.Latest)

  let of_byte_string = bitstring_of_string

  let pp (fmt : Format.formatter) : t -> unit =
    Fn.compose (Format.pp_print_string fmt) to_string

  let copy (path : t) : t =
    let%bitstring path = {| path: -1: bitstring |} in
    path

  (* returns a slice of the original path, so the returned key needs to be
       copied before mutating the path *)
  let parent (path : t) =
    if bitstring_length path = 0 then
      Or_error.error_string "Address length should be nonzero"
    else Or_error.return (slice path 0 (bitstring_length path - 1))

  let parent_exn = Fn.compose Or_error.ok_exn parent

  let is_leaf path = bitstring_length path >= Input.depth

  let child (path : t) dir : t Or_error.t =
    if is_leaf path then
      Or_error.error_string "The address length cannot be greater than depth"
    else
      let dir_bit = Direction.to_bool dir in
      let%bitstring path = {| path: -1: bitstring; dir_bit: 1|} in
      Or_error.return path

  let child_exn (path : t) dir : t = child path dir |> Or_error.ok_exn

  let to_int (path : t) : int =
    Sequence.range 0 (depth path)
    |> Sequence.fold ~init:0 ~f:(fun acc i ->
           let index = depth path - 1 - i in
           acc + ((if get path index <> 0 then 1 else 0) lsl i) )

  let of_int_exn index =
    if index >= 1 lsl Input.depth then failwith "Index is too large"
    else
      let buf = create_bitstring Input.depth in
      Sequence.range ~stride:(-1) ~start:`inclusive ~stop:`inclusive
        (Input.depth - 1) 0
      |> Sequence.fold ~init:index ~f:(fun i pos ->
             Bitstring.put buf pos (i % 2) ;
             i / 2 )
      |> ignore ;
      buf

  let dirs_from_root t =
    List.init (depth t) ~f:(fun pos -> Direction.of_bool (is_set t pos))

  let root () = create_bitstring 0

  let sibling (path : t) : t =
    let path = copy path in
    let last_bit_index = depth path - 1 in
    let last_bit = if get path last_bit_index = 0 then 1 else 0 in
    put path last_bit_index last_bit ;
    path

  let next (path : t) : t Option.t =
    let open Option.Let_syntax in
    let path = copy path in
    let len = depth path in
    let rec find_rightmost_clear_bit i =
      if i < 0 then None
      else if is_clear path i then Some i
      else find_rightmost_clear_bit (i - 1)
    in
    let rec clear_bits i =
      if i >= len then ()
      else (
        clear path i ;
        clear_bits (i + 1) )
    in
    let%map rightmost_clear_index = find_rightmost_clear_bit (len - 1) in
    set path rightmost_clear_index ;
    clear_bits (rightmost_clear_index + 1) ;
    path

  let prev (path : t) : t Option.t =
    let open Option.Let_syntax in
    let path = copy path in
    let len = depth path in
    let rec find_rightmost_one_bit i =
      if i < 0 then None
      else if is_set path i then Some i
      else find_rightmost_one_bit (i - 1)
    in
    let rec set_bits i =
      if i >= len then ()
      else (
        set path i ;
        set_bits (i + 1) )
    in
    let%map rightmost_clear_index = find_rightmost_one_bit (len - 1) in
    clear path rightmost_clear_index ;
    set_bits (rightmost_clear_index + 1) ;
    path

  let serialize path =
    let path = add_padding path in
    let path_len = depth path in
    let required_bits = 8 * path_byte_count in
    assert (path_len <= required_bits) ;
    let required_padding = required_bits - path_len in
    Bigstring.of_string @@ string_of_bitstring
    @@ concat [path; zeroes_bitstring required_padding]

  let is_parent_of parent ~maybe_child =
    (* yikes! https://github.com/xguerin/bitstring/issues/16 *)
    String.is_prefix
      (Bitstring.string_of_bitstring maybe_child)
      ~prefix:(Bitstring.string_of_bitstring parent)

  module Range = struct
    type nonrec t = t * t

    let rec fold_exl (first, last) ~init ~f =
      let comparison = compare first last in
      if comparison > 0 then
        raise (Invalid_argument "first address needs to precede last address")
      else if comparison = 0 then init
      else
        fold_exl (next first |> Option.value_exn, last) ~init:(f first init) ~f

    let fold_incl (first, last) ~init ~f =
      f last @@ fold_exl (first, last) ~init ~f

    let fold ?(stop = `Inclusive) (first, last) ~init ~f =
      assert (depth first = depth last) ;
      match stop with
      | `Inclusive ->
          fold_incl (first, last) ~init ~f
      | `Exclusive ->
          fold_exl (first, last) ~init ~f

    let subtree_range address =
      let first_node = concat [address; zeroes_bitstring @@ height address] in
      let last_node = concat [address; ones_bitstring @@ height address] in
      (first_node, last_node)

    let subtree_range_seq address =
      let first_node, last_node = subtree_range address in
      Sequence.unfold
        ~init:(first_node, `Don't_stop)
        ~f:(function
          | _, `Stop ->
              None
          | current_node, `Don't_stop ->
              if compare current_node last_node = 0 then
                Some (current_node, (current_node, `Stop))
              else
                Option.map (next current_node) ~f:(fun next_node ->
                    (current_node, (next_node, `Don't_stop)) ) )
  end

  let%test "Bitstring bin_io serialization does not change" =
    (* Bitstring.t is trustlisted as a versioned type. This test assures that serializations of that type haven't changed *)
    let text =
      "Contrary to popular belief, Lorem Ipsum is not simply random text. It \
       has roots in a piece of classical Latin literature."
    in
    let bitstring = Bitstring.bitstring_of_string text in
    let known_good_hash =
      "\x0D\xF3\x25\xCE\xD4\x05\xBD\x6C\xB9\xC6\x88\x9E\x16\xD1\x4A\x1B\xEF\xB8\xBC\x3F\xB7\x16\x58\xCB\xC6\x16\xAC\x4B\xD6\x3B\x70\x5B"
    in
    Module_version.Serialization.check_serialization
      (module Stable.V1)
      bitstring known_good_hash

  let%test "the merkle root should have no path" =
    dirs_from_root (root ()) = []

  let%test_unit "parent_exn(child_exn(node)) = node" =
    Quickcheck.test ~sexp_of:[%sexp_of: Direction.t List.t * Direction.t]
      (Quickcheck.Generator.tuple2
         (Direction.gen_var_length_list Input.depth)
         Direction.gen)
      ~f:(fun (path, direction) ->
        let address = of_directions path in
        [%test_eq: t] (parent_exn (child_exn address direction)) address )

  let%test_unit "to_index(of_index_exn(i)) = i" =
    Quickcheck.test ~sexp_of:[%sexp_of: int]
      (Int.gen_incl 0 ((1 lsl Input.depth) - 1))
      ~f:(fun index ->
        [%test_result: int] ~expect:index (to_int @@ of_int_exn index) )

  let%test_unit "of_index_exn(to_index(addr)) = addr" =
    Quickcheck.test ~sexp_of:[%sexp_of: Direction.t list]
      (Direction.gen_list Input.depth) ~f:(fun directions ->
        let address = of_directions directions in
        [%test_result: t] ~expect:address (of_int_exn @@ to_int address) )

  let%test_unit "nonempty(addr): sibling(sibling(addr)) = addr" =
    Quickcheck.test ~sexp_of:[%sexp_of: Direction.t list]
      (Direction.gen_var_length_list ~start:1 Input.depth)
      ~f:(fun directions ->
        let address = of_directions directions in
        [%test_result: t] ~expect:address (sibling @@ sibling address) )

  let%test_unit "prev(next(addr)) = addr" =
    Quickcheck.test ~sexp_of:[%sexp_of: Direction.t list]
      (Direction.gen_list Input.depth) ~f:(fun directions ->
        let address = of_directions directions in
        match next address with
        | None ->
            ()
        | Some addr' ->
            [%test_result: t option] ~expect:(Some address) (prev addr') )
end

let%test_module "Address" =
  ( module struct
    module Test4 = Make (struct
      let depth = 4
    end)

    module Test16 = Make (struct
      let depth = 16
    end)

    module Test30 = Make (struct
      let depth = 30
    end)
  end )
