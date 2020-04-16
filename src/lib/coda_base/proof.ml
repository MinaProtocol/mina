[%%import
"/src/config.mlh"]

[%%ifdef
consensus_mechanism]

open Snark_params

[%%else]

open Snark_params_nonconsensus

[%%endif]

open Core_kernel
open Module_version

[%%versioned_binable
module Stable = struct
  module V1 = struct
    type t = Tock.Proof.t [@@deriving version {asserted}]

    let to_latest = Fn.id

    module T = struct
      type nonrec t = t

      let to_string = Binable.to_string (module Tock.Proof)

      let of_string = Binable.of_string (module Tock.Proof)
    end

    (* TODO: Figure out what the right thing to do is for conversion failures *)
    include Binable.Of_stringable (T)
    include Sexpable.Of_stringable (T)

    let compare a b = String.compare (T.to_string a) (T.to_string b)

    module Base58_check = Base58_check.Make (struct
      let version_byte = Base58_check.Version_bytes.proof

      let description = "Tock proof"
    end)

    let to_yojson s = `String (Base58_check.encode (T.to_string s))

    let of_yojson = function
      | `String s -> (
        match Base58_check.decode s with
        | Ok decoded ->
            Ok (T.of_string decoded)
        | Error e ->
            Error
              (sprintf "Proof.of_yojson, bad Base58Check: %s"
                 (Error.to_string_hum e)) )
      | _ ->
          Error "Proof.of_yojson expected `String"
  end
end]

type t = Stable.Latest.t

[%%define_locally
Stable.Latest.(to_yojson, of_yojson, sexp_of_t, t_of_sexp)]

[%%ifdef
consensus_mechanism]

let dummy = Tock.Proof.dummy

[%%endif]

let%test_module "proof-tests" =
  ( module struct
    (* we test the serializations, because the Of_stringable functor creates serializations from serializers
       in Tock_backend.Proof, which is not versioned
    *)

    [%%ifdef
    consensus_mechanism]

    let test_proof = Tock_backend.Proof.get_dummy ()

    [%%else]

    let test_proof =
      Tock.Proof.
        { a= Mnt6.G1.one
        ; b= Mnt6.G2.one
        ; c= Mnt6.G1.one
        ; delta_prime= Mnt6.G2.one
        ; z= Mnt6.G1.one }

    [%%endif]

    [%%if
    curve_size = 298]

    let%test "proof serialization v1" =
      let known_good_hash =
        "\x22\x36\x54\x9F\x8A\x0A\xBC\x8C\x4E\x90\x22\x91\x30\x20\x4D\x4C\xE1\x11\x01\xD4\xBA\x6B\x38\xEE\x8B\x95\x51\x7E\x6C\x40\xA7\x88"
      in
      Serialization.check_serialization
        (module Stable.V1)
        test_proof known_good_hash

    [%%elif
    curve_size = 753]

    let%test "proof serialization v1" =
      let known_good_hash =
        "\xA6\x52\x85\xCE\x46\xC0\xB9\x24\x99\xA2\x3C\x90\x54\xC8\xAE\x7B\x17\x3A\x99\x64\x94\x3A\xE7\x6C\x66\xD9\x48\x5E\x5D\xD4\x83\x3F"
      in
      Serialization.check_serialization
        (module Stable.V1)
        test_proof known_good_hash

    [%%else]

    let%test "proof serialization v1" = failwith "No test for this curve size"

    [%%endif]
  end )
