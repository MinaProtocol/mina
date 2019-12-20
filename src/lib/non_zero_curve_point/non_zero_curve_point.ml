[%%import
"/src/config.mlh"]

open Core_kernel
open Module_version
module T = Functor.Make (Snark_params.Tick)

(* the Make functor does not supply any bin_prot functions, so 
   we define them here. The base58 and yojson definitions 
   depend on those functions, so they're also in this file
 *)

module Compressed = struct
  open Compressed_poly

  module Arg = struct
    (* module with same type t as Stable below, to give as functor argument *)
    [%%versioned_asserted
    module Stable = struct
      module V1 = struct
        type t = (Snark_params.Tick.Field.t, bool) Poly.Stable.V1.t

        let to_latest = Fn.id

        let description = "Non zero curve point compressed"

        let version_byte =
          Base58_check.Version_bytes.non_zero_curve_point_compressed
      end

      module Tests = struct
        (* actual tests in Stable below *)
      end
    end]
  end

  let compress (x, y) = {Poly.x; is_odd= T.parity y}

  [%%versioned_asserted
  module Stable = struct
    module V1 = struct
      type t = (Snark_params.Tick.Field.t, bool) Poly.Stable.V1.t
      [@@deriving eq, compare, hash]

      (* dummy type for inserting constraint
         adding constraint to t produces "unused rec" error
       *)
      type unused = unit constraint t = Arg.Stable.V1.t

      let to_latest = Fn.id

      module Base58 = Codable.Make_base58_check (Arg.Stable.V1)
      include Base58

      (* sexp representation is a Base58Check string, like the yojson representation *)
      let sexp_of_t t = to_base58_check t |> Sexp.of_string

      let t_of_sexp sexp = Sexp.to_string sexp |> of_base58_check_exn

      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%map uncompressed = T.gen_uncompressed in
        compress uncompressed
    end

    module Tests = struct
      [%%if
      curve_size = 298]

      let%test "nonzero_curve_point_compressed v1" =
        let point =
          Quickcheck.random_value
            ~seed:(`Deterministic "nonzero_curve_point_compressed-seed") V1.gen
        in
        let known_good_hash =
          "\xC3\x5E\x26\x42\xA5\x04\x4A\x9D\x00\x17\xD8\x3E\xED\x84\x08\xDB\xD1\xA0\xCE\x13\x13\x10\x28\x80\x74\xD4\xF1\x25\x6C\x87\x44\x04"
        in
        Serialization.check_serialization (module V1) point known_good_hash

      [%%elif
      curve_size = 753]

      let%test "nonzero_curve_point_compressed v1" =
        let point =
          Quickcheck.random_value
            ~seed:(`Deterministic "nonzero_curve_point_compressed-seed") V1.gen
        in
        let known_good_hash =
          "\x4C\x68\x08\xF4\xC0\xB7\xF1\x41\xFE\xDF\x43\x55\xDA\xB6\x13\xD4\x69\x46\x04\x51\x58\xF7\x92\x51\x02\x5B\x2B\x20\x3F\x6F\x2C\x11"
        in
        Serialization.check_serialization (module V1) point known_good_hash

      [%%else]

      let%test "nonzero_curve_point_compressed v1" =
        failwith "Unknown curve size"

      [%%endif]
    end
  end]

  module Poly = Poly
  include T.Compressed
  include Comparable.Make_binable (Stable.Latest)
  include Hashable.Make_binable (Stable.Latest)
  include Stable.Latest.Base58

  let to_string = to_base58_check

  [%%define_locally
  Stable.Latest.(sexp_of_t, t_of_sexp, gen)]
end

module Uncompressed = struct
  include T.Uncompressed

  [%%versioned_asserted
  module Stable = struct
    module V1 = struct
      type t = Snark_params.Tick.Field.t * Snark_params.Tick.Field.t
      [@@deriving eq, compare, hash]

      let to_latest = Fn.id

      include Binable.Of_binable
                (Compressed.Stable.V1)
                (struct
                  type nonrec t = t

                  let of_binable = decompress_exn

                  let to_binable = compress
                end)

      let gen : t Quickcheck.Generator.t = T.gen_uncompressed

      let of_bigstring bs =
        let open Or_error.Let_syntax in
        let%map elem, _ = Bigstring.read_bin_prot bs bin_reader_t in
        elem

      let to_bigstring elem =
        let bs =
          Bigstring.create (bin_size_t elem + Bin_prot.Utils.size_header_length)
        in
        let _ = Bigstring.write_bin_prot bs bin_writer_t elem in
        bs

      (* We reuse the Base58check-based yojson (de)serialization from the
         compressed representation. *)

      let of_yojson json =
        let open Result in
        Compressed.of_yojson json
        >>= fun compressed ->
        Result.of_option ~error:"couldn't decompress, curve point invalid"
          (decompress compressed)

      let to_yojson t = Compressed.to_yojson @@ compress t

      (* as for yojson, use the Base58check-based sexps from the compressed representation *)
      let sexp_of_t t = Compressed.sexp_of_t @@ compress t

      let t_of_sexp sexp =
        Option.value_exn (decompress @@ Compressed.t_of_sexp sexp)
    end

    module Tests = struct
      [%%if
      curve_size = 298]

      let%test "nonzero_curve_point v1" =
        let point =
          Quickcheck.random_value
            ~seed:(`Deterministic "nonzero_curve_point-seed") V1.gen
        in
        let known_good_hash =
          "\x9F\x36\xA5\x8E\xF2\x0F\x58\xFA\x79\xA4\x47\x18\x79\x43\xE0\x38\xC2\x6B\x6B\x7E\xD3\xF5\xE2\x45\x4E\x20\x19\x64\x62\xCF\x63\x75"
        in
        Serialization.check_serialization (module V1) point known_good_hash

      [%%elif
      curve_size = 753]

      let%test "nonzero_curve_point v1" =
        let point =
          Quickcheck.random_value
            ~seed:(`Deterministic "nonzero_curve_point-seed") V1.gen
        in
        let known_good_hash =
          "\xE2\x8A\xF9\x55\x41\x07\x54\x1F\xF4\x90\x09\x94\xE8\xA5\x7C\x0E\xD3\xED\x8C\xC1\xC9\x1F\x05\x3E\x2C\x39\x28\x9F\x9C\xF1\x10\xCC"
        in
        Serialization.check_serialization (module V1) point known_good_hash

      [%%else]

      let%test "nonzero_curve_point_v1" = failwith "Unknown curve size"

      [%%endif]
    end
  end]

  (* so we can make sets of public keys *)
  include Comparable.Make_binable (Stable.Latest)

  [%%define_locally
  Stable.Latest.
    (of_bigstring, to_bigstring, sexp_of_t, t_of_sexp, to_yojson, of_yojson)]

  let%test_unit "point-compression: decompress . compress = id" =
    Quickcheck.test gen ~f:(fun pk ->
        assert (equal (decompress_exn (compress pk)) pk) )
end

include Uncompressed
