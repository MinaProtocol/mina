open Core_kernel

module Make () = struct
  let digest_size_in_bits = 256

  let digest_size_in_bytes = digest_size_in_bits / 8

  module T0 = struct
    include Digestif.Make_BLAKE2S (struct
      let digest_size = digest_size_in_bytes
    end)

    let hash = Fn.compose String.hash to_raw_string

    let hash_fold_t state t = Hash.fold_string state (to_raw_string t)

    let compare = unsafe_compare

    let of_string = of_raw_string

    let to_string = to_raw_string
  end

  module T1 = struct
    include T0
    include Sexpable.Of_stringable (T0)
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type t = T1.t
        [@@deriving version {asserted; unnumbered}, hash, sexp, compare]
      end

      include T
      include Binable.Of_stringable (T1)
      include Hashable.Make (T1)
      include Comparable.Make (T1)
    end

    module Latest = V1
  end

  type t = T1.t [@@deriving hash, sexp, compare]

  [%%define_locally
  T1.(to_raw_string, digest_string, to_hex)]

  (* do not use Binable.Of_stringable *)
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
    (bits_to_string [|true; false|])
    (String.of_char_list [Char.of_int_exn 1])

let%test_unit "string to bits" =
  Quickcheck.test ~trials:5 String.quickcheck_generator ~f:(fun s ->
      [%test_eq: string] s (bits_to_string (string_to_bits s)) )
