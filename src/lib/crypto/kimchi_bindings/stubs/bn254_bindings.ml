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
