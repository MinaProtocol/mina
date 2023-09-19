[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      [@@@with_all_version_tags]

      type ('field, 'scalar) t = 'field * 'scalar
      [@@deriving sexp, compare, equal, hash]
    end
  end]
end

[%%versioned
module Stable = struct
  module V1 = struct
    [@@@with_all_version_tags]

    type t =
      ( (Field.t[@version_asserted])
      , (Inner_curve.Scalar.t[@version_asserted]) )
      Poly.Stable.V1.t
    [@@deriving sexp, compare, equal, hash]

    module Codable_arg = struct
      (* version tag for compatibility with pre-Berkeley hard fork
         Base58Check-serialized signatures
      *)
      type t =
        (Field.t, Inner_curve.Scalar.t) Poly.Stable.V1.With_all_version_tags.t
      [@@deriving bin_io_unversioned]

      let description = "Signature"

      let version_byte = Base58_check.Version_bytes.signature
    end

    (* Base58Check encodes t *)
    let (_ : (t, Codable_arg.t) Type_equal.t) = Type_equal.T

    include Codable.Make_base58_check (Codable_arg)

    let to_latest = Fn.id

    let gen = Quickcheck.Generator.tuple2 Field.gen Inner_curve.Scalar.gen
  end
end]

let dummy = (Field.one, Inner_curve.Scalar.one)

let gen = Stable.Latest.gen

module Raw = struct
  open Rosetta_coding.Coding

  let encode (field, scalar) = of_field field ^ of_scalar scalar

  let decode raw =
    let len = String.length raw in
    let field_len = len / 2 in
    let field_enc = String.sub raw ~pos:0 ~len:field_len in
    let scalar_enc = String.sub raw ~pos:field_len ~len:field_len in
    try Some (to_field field_enc, to_scalar scalar_enc) with _ -> None
end

[%%ifdef consensus_mechanism]

type var = Field.Var.t * Inner_curve.Scalar.var

[%%endif]

[%%define_locally
Stable.Latest.
  (of_base58_check_exn, of_base58_check, of_yojson, to_yojson, to_base58_check)]
