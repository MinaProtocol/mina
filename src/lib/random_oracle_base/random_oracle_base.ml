open Core_kernel
open Module_version

module Digest = struct
  open Fold_lib

  module Stable = struct
    module V1 = struct
      module T = struct
        type t = string [@@deriving sexp, bin_io, compare, hash, version]
      end

      include T

      module Base58_check = Base58_check.Make (struct
        let version_byte = Base58_check.Version_bytes.random_oracle_base
      end)

      let to_yojson s = `String (Base58_check.encode s)

      let of_yojson = function
        | `String s -> (
          try Ok (Base58_check.decode_exn s)
          with exn ->
            Error
              (sprintf "of_yojson, bad Base58Check: %s" (Exn.to_string exn)) )
        | _ ->
            Error "expected `String"

      include Comparable.Make (T)
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "random_oracle_digest"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  let fold_bits s =
    { Fold.fold=
        (fun ~init ~f ->
          let n = 8 * String.length s in
          let rec go acc i =
            if i = n then acc
            else
              let b = (Char.to_int s.[i / 8] lsr (i mod 8)) land 1 = 1 in
              go (f acc b) (i + 1)
          in
          go init 0 ) }

  let to_bits = Blake2.string_to_bits

  let length_in_bytes = 32

  let length_in_bits = 8 * length_in_bytes

  let length_in_triples = (length_in_bits + 2) / 3

  let gen = String.gen_with_length length_in_bytes Char.quickcheck_generator

  let%test_unit "to_bits compatible with fold" =
    Quickcheck.test gen ~f:(fun t ->
        assert (Array.of_list (Fold.to_list (fold_bits t)) = to_bits t) )

  let of_bits = Blake2.bits_to_string

  let%test_unit "of_bits . to_bits = id" =
    Quickcheck.test gen ~f:(fun t ->
        assert (String.equal (of_bits (to_bits t)) t) )

  let%test_unit "to_bits . of_bits = id" =
    Quickcheck.test
      (List.gen_with_length length_in_bits Bool.quickcheck_generator)
      ~f:(fun t ->
        assert (Array.to_list (to_bits (of_bits (List.to_array t))) = t) )

  type t = Stable.Latest.t [@@deriving sexp, compare, hash, yojson]

  include Comparable.Make (Stable.Latest)

  let fold t = Fold_lib.Fold.group3 ~default:false (fold_bits t)

  let of_string = Fn.id

  let to_string = Fn.id

  let to_bits (t : t) = Array.to_list (Blake2.string_to_bits (t :> string))
end

let digest_string s = Blake2.(digest_string s |> to_raw_string)
