[%%import
"/src/config.mlh"]

open Core_kernel
open Snark_params

[%%versioned_binable
module Stable = struct
  module V1 = struct
    type t = Tock.Proof.t [@@deriving version {asserted}]

    let to_latest = Fn.id

    module T = struct
      type nonrec t = t

      let to_string = Binable.to_string (module Tock_backend.Proof)

      let of_string = Binable.of_string (module Tock_backend.Proof)
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

let dummy = Tock.Proof.dummy

include Sexpable.Of_stringable (Stable.Latest.T)

[%%define_locally
Stable.Latest.(to_yojson, of_yojson)]

let%test_module "proof-tests" =
  ( module struct
    (* we test the serializations, because the Of_stringable functor creates serializations from serializers
       in Tock_backend.Proof, which is not versioned
    *)

    [%%if
    curve_size = 298]

    let%test "proof serialization v1" =
      let proof = Tock_backend.Proof.get_dummy () in
      let known_good_digest = "7b2f3495a9b190a72e134bc5a5c7d53f" in
      Ppx_version_runtime.Serialization.check_serialization
        (module Stable.V1)
        proof known_good_digest

    [%%elif
    curve_size = 753]

    let%test "proof serialization v1" =
      let proof = Tock_backend.Proof.get_dummy () in
      let known_good_digest = "4e54b20026fe9e66fcb432ff6772bd7c" in
      Ppx_version_runtime.Serialization.check_serialization
        (module Stable.V1)
        proof known_good_digest

    [%%else]

    let%test "proof serialization v1" = failwith "No test for this curve size"

    [%%endif]
  end )
