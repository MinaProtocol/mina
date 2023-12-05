(* This file is generated automatically with ocaml_gen. *)

module Bn254Fp = struct
  type nonrec t

  external size_in_bits : unit -> int = "caml_bn254_fp_size_in_bits"

  external size : unit -> Pasta_bindings.BigInt256.t = "caml_bn254_fp_size"

  external add : t -> t -> t = "caml_bn254_fp_add"

  external sub : t -> t -> t = "caml_bn254_fp_sub"

  external negate : t -> t = "caml_bn254_fp_negate"

  external mul : t -> t -> t = "caml_bn254_fp_mul"

  external div : t -> t -> t = "caml_bn254_fp_div"

  external inv : t -> t option = "caml_bn254_fp_inv"

  external square : t -> t = "caml_bn254_fp_square"

  external is_square : t -> bool = "caml_bn254_fp_is_square"

  external sqrt : t -> t option = "caml_bn254_fp_sqrt"

  external of_int : int -> t = "caml_bn254_fp_of_int"

  external to_string : t -> string = "caml_bn254_fp_to_string"

  external of_string : string -> t = "caml_bn254_fp_of_string"

  external print : t -> unit = "caml_bn254_fp_print"

  external print_rust : t -> unit = "caml_bn254_fp_print_rust"

  external copy : t -> t -> unit = "caml_bn254_fp_copy"

  external mut_add : t -> t -> unit = "caml_bn254_fp_mut_add"

  external mut_sub : t -> t -> unit = "caml_bn254_fp_mut_sub"

  external mut_mul : t -> t -> unit = "caml_bn254_fp_mut_mul"

  external mut_square : t -> unit = "caml_bn254_fp_mut_square"

  external compare : t -> t -> int = "caml_bn254_fp_compare"

  external equal : t -> t -> bool = "caml_bn254_fp_equal"

  external random : unit -> t = "caml_bn254_fp_random"

  external rng : int -> t = "caml_bn254_fp_rng"

  external to_bigint : t -> Pasta_bindings.BigInt256.t
    = "caml_bn254_fp_to_bigint"

  external of_bigint : Pasta_bindings.BigInt256.t -> t
    = "caml_bn254_fp_of_bigint"

  external two_adic_root_of_unity : unit -> t
    = "caml_bn254_fp_two_adic_root_of_unity"

  external domain_generator : int -> t = "caml_bn254_fp_domain_generator"

  external to_bytes : t -> bytes = "caml_bn254_fp_to_bytes"

  external of_bytes : bytes -> t = "caml_bn254_fp_of_bytes"

  external deep_copy : t -> t = "caml_bn254_fp_deep_copy"
end

module Bn254Fq = struct
  type nonrec t

  external size_in_bits : unit -> int = "caml_bn254_fq_size_in_bits"

  external size : unit -> Pasta_bindings.BigInt256.t = "caml_bn254_fq_size"

  external add : t -> t -> t = "caml_bn254_fq_add"

  external sub : t -> t -> t = "caml_bn254_fq_sub"

  external negate : t -> t = "caml_bn254_fq_negate"

  external mul : t -> t -> t = "caml_bn254_fq_mul"

  external div : t -> t -> t = "caml_bn254_fq_div"

  external inv : t -> t option = "caml_bn254_fq_inv"

  external square : t -> t = "caml_bn254_fq_square"

  external is_square : t -> bool = "caml_bn254_fq_is_square"

  external sqrt : t -> t option = "caml_bn254_fq_sqrt"

  external of_int : int -> t = "caml_bn254_fq_of_int"

  external to_string : t -> string = "caml_bn254_fq_to_string"

  external of_string : string -> t = "caml_bn254_fq_of_string"

  external print : t -> unit = "caml_bn254_fq_print"

  external print_rust : t -> unit = "caml_bn254_fq_print_rust"

  external copy : t -> t -> unit = "caml_bn254_fq_copy"

  external mut_add : t -> t -> unit = "caml_bn254_fq_mut_add"

  external mut_sub : t -> t -> unit = "caml_bn254_fq_mut_sub"

  external mut_mul : t -> t -> unit = "caml_bn254_fq_mut_mul"

  external mut_square : t -> unit = "caml_bn254_fq_mut_square"

  external compare : t -> t -> int = "caml_bn254_fq_compare"

  external equal : t -> t -> bool = "caml_bn254_fq_equal"

  external random : unit -> t = "caml_bn254_fq_random"

  external rng : int -> t = "caml_bn254_fq_rng"

  external to_bigint : t -> Pasta_bindings.BigInt256.t
    = "caml_bn254_fq_to_bigint"

  external of_bigint : Pasta_bindings.BigInt256.t -> t
    = "caml_bn254_fq_of_bigint"

  external two_adic_root_of_unity : unit -> t
    = "caml_bn254_fq_two_adic_root_of_unity"

  external domain_generator : int -> t = "caml_bn254_fq_domain_generator"

  external to_bytes : t -> bytes = "caml_bn254_fq_to_bytes"

  external of_bytes : bytes -> t = "caml_bn254_fq_of_bytes"

  external deep_copy : t -> t = "caml_bn254_fq_deep_copy"
end

module Bn254 = struct
  module BaseField = struct
    type nonrec t = Bn254Fq.t
  end

  module ScalarField = struct
    type nonrec t = Bn254Fp.t
  end

  module Affine = struct
    type nonrec t = Bn254Fq.t Kimchi_types.or_infinity
  end

  type nonrec t

  external one : unit -> t = "caml_bn254_one"

  external add : t -> t -> t = "caml_bn254_add"

  external sub : t -> t -> t = "caml_bn254_sub"

  external negate : t -> t = "caml_bn254_negate"

  external double : t -> t = "caml_bn254_double"

  external scale : t -> Bn254Fp.t -> t = "caml_bn254_scale"

  external random : unit -> t = "caml_bn254_random"

  external rng : int -> t = "caml_bn254_rng"

  external endo_base : unit -> Bn254Fq.t = "caml_bn254_endo_base"

  external endo_scalar : unit -> Bn254Fp.t = "caml_bn254_endo_scalar"

  external to_affine : t -> Bn254Fq.t Kimchi_types.or_infinity
    = "caml_bn254_to_affine"

  external of_affine : Bn254Fq.t Kimchi_types.or_infinity -> t
    = "caml_bn254_of_affine"

  external of_affine_coordinates : Bn254Fq.t -> Bn254Fq.t -> t
    = "caml_bn254_of_affine_coordinates"

  external deep_copy :
    Bn254Fq.t Kimchi_types.or_infinity -> Bn254Fq.t Kimchi_types.or_infinity
    = "caml_bn254_affine_deep_copy"
end
