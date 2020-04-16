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

let dummy = Tock.Proof.dummy

let%test_module "proof-tests" =
  ( module struct
    (* we test the serializations, because the Of_stringable functor creates serializations from serializers
       in Tock_backend.Proof, which is not versioned
    *)

    [%%if
    curve_size = 298]

    let%test "proof serialization v1" =
      let proof = dummy in
      let known_good_hash =
        "\x2B\xD6\xE9\x9E\x7A\xC6\x47\x6E\xB2\x45\xF9\x49\x4A\xD5\x19\x48\x1B\xF2\x72\xE8\xC6\x6A\x44\x37\x6F\x1E\x70\x58\x82\xB2\x7E\xFB"
      in
      Serialization.check_serialization
        (module Stable.V1)
        proof known_good_hash

    [%%elif
    curve_size = 753]

    let%test "proof serialization v1" =
      let proof = dummy in
      let known_good_hash =
        "\x72\x8D\x8A\x9A\xEF\xD7\x61\x78\x73\x07\x0A\xBD\x47\x00\x80\xF8\x12\x2E\x6C\x43\x37\x7A\x24\x20\xA6\x6F\x28\x9E\xAF\xC7\x06\xAE"
      in
      Serialization.check_serialization
        (module Stable.V1)
        proof known_good_hash

    [%%else]

    let%test "proof serialization v1" = failwith "No test for this curve size"

    [%%endif]
  end )
