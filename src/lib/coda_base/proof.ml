[%%import
"../../config.mlh"]

open Core
open Snark_params
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      type t = Tock.Proof.t [@@deriving version {asserted}]

      let to_string = Binable.to_string (module Tock_backend.Proof)

      let of_string = Binable.of_string (module Tock_backend.Proof)

      let compare a b = String.compare (to_string a) (to_string b)

      let version_byte = Base58_check.Version_bytes.proof

      let description = "Tock proof"

      (* TODO: Figure out what the right thing to do is for conversion failures *)
      let ( { Bin_prot.Type_class.reader= bin_reader_t
            ; writer= bin_writer_t
            ; shape= bin_shape_t } as bin_t ) =
        Bin_prot.Type_class.cnv Fn.id to_string of_string String.bin_t

      let {Bin_prot.Type_class.read= bin_read_t; vtag_read= __bin_read_t__} =
        bin_reader_t

      let {Bin_prot.Type_class.write= bin_write_t; size= bin_size_t} =
        bin_writer_t
    end

    include T
    include Sexpable.Of_stringable (T)
    module Base58_check = Base58_check.Make (T)

    let to_yojson s = `String (Base58_check.encode (to_string s))

    let of_yojson = function
      | `String s -> (
        match Base58_check.decode s with
        | Ok decoded ->
            Ok (of_string decoded)
        | Error e ->
            Error
              (sprintf "Proof.of_yojson, bad Base58Check: %s"
                 (Error.to_string_hum e)) )
      | _ ->
          Error "Proof.of_yojson expected `String"

    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "coda_base_proof"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)

  module For_tests = struct
    (* if this test fails, it means the type has changed; in that case, create a new version for the type,
       and a new serialization test for the new version; delete the old version and its test
     *)

    [%%if
    curve_size = 298]

    let%test "proof serialization v1" =
      (* TODO get stable value *)
      let proof = Tock.Proof.dummy in
      let known_good_hash =
        "\xA1\xD0\xF3\x3C\x58\x60\xB1\x3F\xE2\xCD\x56\x89\x01\x2F\xE7\xF1\x8E\x5E\x7B\xA9\x4F\x21\x4C\xEC\x29\x79\x72\x95\x9A\x2E\x16\x33"
      in
      Serialization.check_serialization (module V1) proof known_good_hash

    [%%elif
    curve_size = 753]

    let%test "proof serialization v1" =
      let proof = Tock.Proof.dummy in
      let known_good_hash =
        "\xB8\x2A\x05\xFB\x15\x8B\xE3\x15\xDB\xD1\x0B\xEA\x2F\x84\x67\x91\x8F\x6B\xD0\x03\x1E\xB7\x03\x45\x7B\x0D\xCE\x17\xAE\xAC\x34\x3E"
      in
      Serialization.check_serialization (module V1) proof known_good_hash

    [%%else]

    let%test "proof serialization v1" = failwith "No test for this curve size"

    [%%endif]
  end
end

type t = Stable.Latest.t

let dummy = Tock.Proof.dummy

include Sexpable.Of_stringable (Stable.Latest)

[%%define_locally
Stable.Latest.(to_yojson, of_yojson)]
