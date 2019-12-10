[%%import
"/src/config.mlh"]

open Core_kernel
open Module_version
module T = Functor.Make (Snark_params)

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

      let to_latest = Fn.id

      module Base58 = Codable.Make_base58_check (Arg.Stable.Latest)
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
          "\xDF\x60\x51\x95\x81\xC9\xE5\xC2\xBC\xEB\xD7\xB8\x07\x81\xAE\x17\x66\xC0\xBC\xAF\xD8\x3C\x02\xEC\x9F\x62\x0A\xBA\x55\xC7\xCB\xCA"
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
          "\xA9\x77\x56\x90\x5F\x61\x9B\x27\x43\x4F\x1A\xB7\x94\xD5\x39\x05\xBD\xD6\xCE\x63\x3A\xAF\xA3\x14\x75\x60\x52\x95\xA4\x4E\x2B\x50"
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
      (* TODO *)
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
