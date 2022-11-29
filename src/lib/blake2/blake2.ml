open Core_kernel

module Make () = struct
  let digest_size_in_bits = 256

  let digest_size_in_bytes = digest_size_in_bits / 8

  module T0 = struct
    include Digestif.Make_BLAKE2B (struct
      let digest_size = digest_size_in_bytes
    end)

    let hash = Fn.compose String.hash to_raw_string

    let hash_fold_t state t = Hash.fold_string state (to_raw_string t)

    let compare = unsafe_compare

    let of_string = of_raw_string

    let to_string = to_raw_string

    let gen =
      let char_generator =
        Base_quickcheck.Generator.of_list
          [ '0'
          ; '1'
          ; '2'
          ; '3'
          ; '4'
          ; '5'
          ; '6'
          ; '7'
          ; '8'
          ; '9'
          ; 'A'
          ; 'B'
          ; 'C'
          ; 'D'
          ; 'E'
          ; 'F'
          ]
      in
      String.gen_with_length (digest_size_in_bytes * 2) char_generator
      |> Quickcheck.Generator.map ~f:of_hex
  end

  module T1 = struct
    include T0
    include Sexpable.Of_stringable (T0)
  end

  [%%versioned_binable
  module Stable = struct
    [@@@with_top_version_tag]

    module V1 = struct
      type t = T1.t [@@deriving hash, sexp, compare, equal]

      let to_latest = Fn.id

      let to_yojson t : Yojson.Safe.t = `String (T1.to_hex t)

      let of_yojson (v : Yojson.Safe.t) =
        let open Ppx_deriving_yojson_runtime in
        match v with
        | `String s ->
            Option.value_map ~default:(Result.Error "not a hex string")
              ~f:(fun x -> Result.Ok x)
              (T1.of_hex_opt s)
        | _ ->
            Result.Error "not a string"

      module Arg = struct
        type nonrec t = t

        [%%define_locally T1.(to_string, of_string)]
      end

      include Binable.Of_stringable_without_uuid (Arg)
    end
  end]

  [%%define_locally Stable.Latest.(to_yojson, of_yojson)]

  [%%define_locally
  T1.
    ( of_raw_string
    , to_raw_string
    , digest_string
    , digest_bigstring
    , to_hex
    , of_hex
    , gen )]

  (* do not create bin_io serialization *)
  include Hashable.Make (T1)
  include Comparable.Make (T1)

  (* Little endian *)
  let bits_to_string bits =
    let n = Array.length bits in
    let rec make_byte offset acc (i : int) =
      let finished = Int.(i = 8 || offset + i >= n) in
      if finished then Char.of_int_exn acc
      else
        let acc = if bits.(offset + i) then acc lor (1 lsl i) else acc in
        make_byte offset acc (i + 1)
    in
    let len = (n + 7) / 8 in
    String.init len ~f:(fun i -> make_byte (8 * i) 0 0)

  let string_to_bits s =
    Array.init
      (8 * String.length s)
      ~f:(fun i ->
        let c = Char.to_int s.[i / 8] in
        let j = i mod 8 in
        Int.((c lsr j) land 1 = 1) )
end

include Make ()

let%test_unit "bits_to_string" =
  [%test_eq: string]
    (bits_to_string [| true; false |])
    (String.of_char_list [ Char.of_int_exn 1 ])

let%test_unit "string to bits" =
  Quickcheck.test ~trials:5 String.quickcheck_generator ~f:(fun s ->
      [%test_eq: string] s (bits_to_string (string_to_bits s)) )
