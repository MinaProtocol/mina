(* snark_params_nonconsensus.ml *)

[%%import
"/src/config.mlh"]

[%%ifdef
consensus_mechanism]

[%%error
"Snark_params_nonconsensus should not be compiled if there's a consensus \
 mechanism"]

[%%endif]

open Snarkette

[%%if
curve_size = 298]

module Mnt4 = Mnt4_80
module Mnt6 = Mnt6_80

[%%elif
curve_size = 753]

module Mnt4 = Mnt4753
module Mnt6 = Mnt6753

[%%else]

[%%show
curve_size]

[%%error
"invalid value for \"curve_size\""]

[%%endif]

module Field0 = Mnt6.Fq
module G1 = Mnt6.G1

[%%inject
"ledger_depth", ledger_depth]

module Field = struct
  include Field0

  let size = order |> Snarkette.Nat.to_string |> Bigint.of_string

  let size_in_bits = length_in_bits

  let unpack t = to_bits t

  let project bits =
    Core_kernel.Option.value_exn ~message:"project: invalid bits"
      (of_bits bits)
end

module Tock = struct
  module Field = struct
    type t = Mnt4.Fq.t

    let unpack t = Mnt4.Fq.to_bits t

    let project bits =
      Core_kernel.Option.value_exn
        ~message:"Snark_params_nonconsensus.Tock.Field.project"
        (Mnt4.Fq.of_bits bits)
  end
end

module Inner_curve = struct
  type t = Mnt6.G1.t

  module Coefficients = Mnt6.G1.Coefficients

  let find_y x =
    let open Mnt6.Fq in
    let y2 = (x * square x) + (Coefficients.a * x) + Coefficients.b in
    if is_square y2 then Some (sqrt y2) else None

  [%%define_locally
  Mnt6.G1.(to_affine, to_affine_exn, of_affine, scale, one, ( + ), negate)]

  let scale_field t x = scale t (Mnt4.Fq.of_bigint x :> Snarkette.Nat.t)

  module Scalar = struct
    (* though we have bin_io, not versioned here; this type exists for Private_key.t,
       where it is versioned-asserted and its serialization tested
       we make linter error a warning
     *)
    type t = Mnt4.Fq.t [@@deriving bin_io, sexp]

    type _unused = unit constraint t = Tock.Field.t

    (* the Inner_curve.Scalar.size for the consensus case is derived from a C++ call; here, we inline the value *)
    let size =
      Bigint.of_string
        "475922286169261325753349249653048451545124879242694725395555128576210262817955800483758081"

    [%%define_locally
    Mnt4.Fq.
      ( to_string
      , of_string
      , equal
      , compare
      , zero
      , one
      , ( + )
      , ( * )
      , negate
      , hash_fold_t )]

    let gen = Mnt4.Fq.gen

    let of_bits bits = Tock.Field.project bits
  end
end
