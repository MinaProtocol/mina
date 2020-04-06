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
  [%%versioned_asserted
  module Stable = struct
    module V1 = struct
      type t = {x: Field.t; is_odd: bool} [@@deriving eq, sexp]

      let to_latest = Fn.id

      module Display = struct
        type t = {x: string; is_odd: bool} [@@deriving to_yojson]
      end

      let to_yojson {x; is_odd} =
        Display.to_yojson {Display.x= Field.to_string x; is_odd}

      let gen =
        let open Quickcheck.Let_syntax in
        let%bind x = Field.gen in
        let%map is_odd = Quickcheck.Generator.bool in
        {x; is_odd}
    end

    module Tests = struct
      [%%if
      curve_size = 298]

      let%test "public key v1" =
        let pk =
          Quickcheck.random_value ~seed:(`Deterministic "public key") V1.gen
        in
        let known_good_hash =
          "\x20\x1E\xC9\xEC\x67\x5E\x76\x79\x18\xBB\x28\x2C\x51\x5B\x36\x37\x5B\x5F\x39\x18\x21\x3A\x33\x4C\x69\x4B\x8C\xC6\x09\x24\xAD\xE7"
        in
        Serialization.check_serialization (module V1) pk known_good_hash

      [%%elif
      curve_size = 753]

      let%test "public key v1" =
        let pk =
          Quickcheck.random_value ~seed:(`Deterministic "public key") V1.gen
        in
        let known_good_hash =
          "\xBE\x4C\x9B\xAC\xD4\xEA\x2A\x78\xCF\xC6\x70\x70\x8E\xB0\x31\xCA\x6B\x09\xB2\xD5\x28\xB3\x19\xCA\x18\xC8\x4E\x4A\xA2\xCC\xCB\xDF"
        in
        Serialization.check_serialization (module V1) pk known_good_hash

      [%%else]

      let%test "public key v1" = failwith "No test for this curve size"

      [%%endif]
    end
  end]

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
