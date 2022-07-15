(* This file is generated automatically with ocaml_gen. *)

  module BigInt256 = struct 
    type nonrec t
    external of_numeral : string -> int -> int -> t = "caml_bigint_256_of_numeral"
    external of_decimal_string : string -> t = "caml_bigint_256_of_decimal_string"
    external num_limbs : unit -> int = "caml_bigint_256_num_limbs"
    external bytes_per_limb : unit -> int = "caml_bigint_256_bytes_per_limb"
    external div : t -> t -> t = "caml_bigint_256_div"
    external compare : t -> t -> int = "caml_bigint_256_compare"
    external print : t -> unit = "caml_bigint_256_print"
    external to_string : t -> string = "caml_bigint_256_to_string"
    external test_bit : t -> int -> bool = "caml_bigint_256_test_bit"
    external to_bytes : t -> bytes = "caml_bigint_256_to_bytes"
    external of_bytes : bytes -> t = "caml_bigint_256_of_bytes"
    external deep_copy : t -> t = "caml_bigint_256_deep_copy"
  end


  module Fp = struct 
    type nonrec t
    external size_in_bits : unit -> int = "caml_pasta_fp_size_in_bits"
    external size : unit -> BigInt256.t = "caml_pasta_fp_size"
    external add : t -> t -> t = "caml_pasta_fp_add"
    external sub : t -> t -> t = "caml_pasta_fp_sub"
    external negate : t -> t = "caml_pasta_fp_negate"
    external mul : t -> t -> t = "caml_pasta_fp_mul"
    external div : t -> t -> t = "caml_pasta_fp_div"
    external inv : t -> (t) option = "caml_pasta_fp_inv"
    external square : t -> t = "caml_pasta_fp_square"
    external is_square : t -> bool = "caml_pasta_fp_is_square"
    external sqrt : t -> (t) option = "caml_pasta_fp_sqrt"
    external of_int : int -> t = "caml_pasta_fp_of_int"
    external to_string : t -> string = "caml_pasta_fp_to_string"
    external of_string : string -> t = "caml_pasta_fp_of_string"
    external print : t -> unit = "caml_pasta_fp_print"
    external copy : t -> t -> unit = "caml_pasta_fp_copy"
    external mut_add : t -> t -> unit = "caml_pasta_fp_mut_add"
    external mut_sub : t -> t -> unit = "caml_pasta_fp_mut_sub"
    external mut_mul : t -> t -> unit = "caml_pasta_fp_mut_mul"
    external mut_square : t -> unit = "caml_pasta_fp_mut_square"
    external compare : t -> t -> int = "caml_pasta_fp_compare"
    external equal : t -> t -> bool = "caml_pasta_fp_equal"
    external random : unit -> t = "caml_pasta_fp_random"
    external rng : int -> t = "caml_pasta_fp_rng"
    external to_bigint : t -> BigInt256.t = "caml_pasta_fp_to_bigint"
    external of_bigint : BigInt256.t -> t = "caml_pasta_fp_of_bigint"
    external two_adic_root_of_unity : unit -> t = "caml_pasta_fp_two_adic_root_of_unity"
    external domain_generator : int -> t = "caml_pasta_fp_domain_generator"
    external to_bytes : t -> bytes = "caml_pasta_fp_to_bytes"
    external of_bytes : bytes -> t = "caml_pasta_fp_of_bytes"
    external deep_copy : t -> t = "caml_pasta_fp_deep_copy"
  end


  module Fq = struct 
    type nonrec t
    external size_in_bits : unit -> int = "caml_pasta_fq_size_in_bits"
    external size : unit -> BigInt256.t = "caml_pasta_fq_size"
    external add : t -> t -> t = "caml_pasta_fq_add"
    external sub : t -> t -> t = "caml_pasta_fq_sub"
    external negate : t -> t = "caml_pasta_fq_negate"
    external mul : t -> t -> t = "caml_pasta_fq_mul"
    external div : t -> t -> t = "caml_pasta_fq_div"
    external inv : t -> (t) option = "caml_pasta_fq_inv"
    external square : t -> t = "caml_pasta_fq_square"
    external is_square : t -> bool = "caml_pasta_fq_is_square"
    external sqrt : t -> (t) option = "caml_pasta_fq_sqrt"
    external of_int : int -> t = "caml_pasta_fq_of_int"
    external to_string : t -> string = "caml_pasta_fq_to_string"
    external of_string : string -> t = "caml_pasta_fq_of_string"
    external print : t -> unit = "caml_pasta_fq_print"
    external copy : t -> t -> unit = "caml_pasta_fq_copy"
    external mut_add : t -> t -> unit = "caml_pasta_fq_mut_add"
    external mut_sub : t -> t -> unit = "caml_pasta_fq_mut_sub"
    external mut_mul : t -> t -> unit = "caml_pasta_fq_mut_mul"
    external mut_square : t -> unit = "caml_pasta_fq_mut_square"
    external compare : t -> t -> int = "caml_pasta_fq_compare"
    external equal : t -> t -> bool = "caml_pasta_fq_equal"
    external random : unit -> t = "caml_pasta_fq_random"
    external rng : int -> t = "caml_pasta_fq_rng"
    external to_bigint : t -> BigInt256.t = "caml_pasta_fq_to_bigint"
    external of_bigint : BigInt256.t -> t = "caml_pasta_fq_of_bigint"
    external two_adic_root_of_unity : unit -> t = "caml_pasta_fq_two_adic_root_of_unity"
    external domain_generator : int -> t = "caml_pasta_fq_domain_generator"
    external to_bytes : t -> bytes = "caml_pasta_fq_to_bytes"
    external of_bytes : bytes -> t = "caml_pasta_fq_of_bytes"
    external deep_copy : t -> t = "caml_pasta_fq_deep_copy"
  end


  module Vesta = struct 

    module BaseField = struct 
      type nonrec t = Fq.t
    end


    module ScalarField = struct 
      type nonrec t = Fp.t
    end


    module Affine = struct 
      type nonrec t = (Fq.t) Kimchi_types.or_infinity
    end

    type nonrec t
    external one : unit -> t = "caml_vesta_one"
    external add : t -> t -> t = "caml_vesta_add"
    external sub : t -> t -> t = "caml_vesta_sub"
    external negate : t -> t = "caml_vesta_negate"
    external double : t -> t = "caml_vesta_double"
    external scale : t -> Fp.t -> t = "caml_vesta_scale"
    external random : unit -> t = "caml_vesta_random"
    external rng : int -> t = "caml_vesta_rng"
    external endo_base : unit -> Fq.t = "caml_vesta_endo_base"
    external endo_scalar : unit -> Fp.t = "caml_vesta_endo_scalar"
    external to_affine : t -> (Fq.t) Kimchi_types.or_infinity = "caml_vesta_to_affine"
    external of_affine : (Fq.t) Kimchi_types.or_infinity -> t = "caml_vesta_of_affine"
    external of_affine_coordinates : Fq.t -> Fq.t -> t = "caml_vesta_of_affine_coordinates"
    external deep_copy : (Fq.t) Kimchi_types.or_infinity -> (Fq.t) Kimchi_types.or_infinity = "caml_vesta_affine_deep_copy"
  end


  module Pallas = struct 

    module BaseField = struct 
      type nonrec t = Fp.t
    end


    module ScalarField = struct 
      type nonrec t = Fq.t
    end


    module Affine = struct 
      type nonrec t = (Fp.t) Kimchi_types.or_infinity
    end

    type nonrec t
    external one : unit -> t = "caml_pallas_one"
    external add : t -> t -> t = "caml_pallas_add"
    external sub : t -> t -> t = "caml_pallas_sub"
    external negate : t -> t = "caml_pallas_negate"
    external double : t -> t = "caml_pallas_double"
    external scale : t -> Fq.t -> t = "caml_pallas_scale"
    external random : unit -> t = "caml_pallas_random"
    external rng : int -> t = "caml_pallas_rng"
    external endo_base : unit -> Fp.t = "caml_pallas_endo_base"
    external endo_scalar : unit -> Fq.t = "caml_pallas_endo_scalar"
    external to_affine : t -> (Fp.t) Kimchi_types.or_infinity = "caml_pallas_to_affine"
    external of_affine : (Fp.t) Kimchi_types.or_infinity -> t = "caml_pallas_of_affine"
    external of_affine_coordinates : Fp.t -> Fp.t -> t = "caml_pallas_of_affine_coordinates"
    external deep_copy : (Fp.t) Kimchi_types.or_infinity -> (Fp.t) Kimchi_types.or_infinity = "caml_pallas_affine_deep_copy"
  end

