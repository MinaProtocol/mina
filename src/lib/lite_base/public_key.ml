[%%import
"/src/config.mlh"]

open Core_kernel
open Fold_lib
open Sexplib.Std
open Bin_prot.Std
open Module_version
module Field = Crypto_params.Tock.Fq

type t = Crypto_params.Tock.G1.t

module Compressed = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = {x: Field.t; is_odd: bool}
        [@@deriving bin_io, eq, sexp, version {asserted}]

        module Display = struct
          type t = {x: string; is_odd: bool} [@@deriving to_yojson]
        end

        let to_yojson {x; is_odd} =
          Display.to_yojson {Display.x= Field.to_string x; is_odd}
      end

      include T
      include Registration.Make_latest_version (T)

      let gen =
        let open Quickcheck.Let_syntax in
        let%bind x = Field.gen in
        let%map is_odd = Quickcheck.Generator.bool in
        {x; is_odd}
    end

    module Latest = V1

    module Module_decl = struct
      let name = "public_key"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)

    (* see lib/module_version/README-version-asserted.md *)
    module For_tests = struct
      [%%if
      curve_size = 298]

      let%test "public key v1" =
        let pk =
          Quickcheck.random_value ~seed:(`Deterministic "public key") V1.gen
        in
        let known_good_hash =
          "\x7F\x07\x2A\x75\x70\x5C\x9A\x00\x44\x7C\x26\x3B\xC7\x05\xCF\x83\x8D\x2F\x9D\xB6\x2E\x4B\xE7\x64\x8B\x33\xF4\xC8\x08\x56\x1F\x86"
        in
        Serialization.check_serialization (module V1) pk known_good_hash

      [%%elif
      curve_size = 753]

      let%test "public key v1" =
        let pk =
          Quickcheck.random_value ~seed:(`Deterministic "public key") V1.gen
        in
        let known_good_hash =
          "\x45\x3D\x4F\x3B\xE7\x79\x9C\xFD\x18\xFB\x49\x58\xD6\x62\xF7\xCB\xA1\xA6\xEA\x56\x24\x66\x29\x9B\xCE\xF7\x07\x26\x10\xAA\x5B\xB5"
        in
        Serialization.check_serialization (module V1) pk known_good_hash

      [%%else]

      let%test "public key v1" = failwith "No test for this curve size"

      [%%endif]
    end
  end

  type t = Stable.Latest.t = {x: Field.t; is_odd: bool} [@@deriving eq, sexp]

  module Display = struct
    type t = {x: string; is_odd: bool} [@@deriving to_yojson]
  end

  let to_yojson {x; is_odd} =
    Display.to_yojson {Display.x= Field.to_string x; is_odd}

  let fold_bits {is_odd; x} =
    {Fold.fold= (fun ~init ~f -> f ((Field.fold_bits x).fold ~init ~f) is_odd)}

  let fold t = Fold.group3 ~default:false (fold_bits t)

  let length_in_triples = (Field.length_in_bits + 1 + 2) / 3
end
