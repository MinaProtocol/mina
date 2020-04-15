open Core_kernel

module type Field_intf = sig
  type t

  module Vector : Snarky.Vector.S_binable_sexpable with type elt = t

  include Snarky.Field_intf.S with type t := t with module Vector := Vector

  val typ : t Ctypes.typ

  val delete : t -> unit
end

module type Bigint_intf = sig
  type field

  module R : sig
    type t [@@deriving bin_io]

    val typ : t Ctypes.typ

    val of_decimal_string : string -> t

    val of_numeral : string -> base:int -> t

    val of_field : field -> t

    val of_data : Core.Bigstring.t -> bitcount:int -> t

    val length_in_bytes : int

    val div : t -> t -> t

    val to_field : t -> field

    val to_bigstring : t -> Core.Bigstring.t

    val compare : t -> t -> int

    val test_bit : t -> int -> bool

    val find_wnaf : Unsigned.Size_t.t -> t -> Snarky.Long_vector.t
  end

  module Q : sig
    type t

    val typ : t Ctypes.typ

    val test_bit : t -> int -> bool

    val find_wnaf : Unsigned.Size_t.t -> t -> Snarky.Long_vector.t
  end
end

module type Common_intf = sig
  val prefix : string

  module Field : Field_intf

  module Bigint : Bigint_intf with type field := Field.t

  module Var : sig
    type t = Field.t Snarky.Backend_types.Var.t

    val typ : t Ctypes_static.typ

    val index : t -> int

    val create : int -> t
  end

  module R1CS_constraint_system : sig
    type t = Field.t Snarky.Backend_types.R1CS_constraint_system.t

    val typ : t Ctypes_static.typ

    val create : unit -> t

    val clear : t -> unit

    val finalize : t -> unit

    val add_constraint :
         ?label:string
      -> t
      -> Field.t Snarky.Cvar.t Snarky.Constraint.basic
      -> unit

    val digest : t -> Core_kernel.Md5.t

    val set_primary_input_size : t -> int -> unit

    val set_auxiliary_input_size : t -> int -> unit

    val get_primary_input_size : t -> int

    val get_auxiliary_input_size : t -> int

    val to_json :
         t
      -> ([> `Assoc of (string * 'a) list
          | `List of 'a list
          | `String of string ]
          as
          'a)

    val swap_AB_if_beneficial : t -> unit
  end

  val field_size : Bigint.R.t
end

module type Proof_system_intf = sig
  type field_vector

  type r1cs_constraint_system

  module Proving_key : sig
    type t [@@deriving bin_io]

    val func_name : string -> string

    val typ : t Ctypes.typ

    val is_initialized : t -> [`No of r1cs_constraint_system | `Yes]

    val delete : t -> unit

    val to_string : t -> string

    val of_string : string -> t

    val to_bigstring : t -> Bigstring.t

    val of_bigstring : Bigstring.t -> t

    val set_constraint_system : t -> r1cs_constraint_system -> unit
  end

  module Verification_key : sig
    type t

    val typ : t Ctypes.typ

    val delete : t -> unit

    val to_string : t -> string

    val of_string : string -> t

    val to_bigstring : t -> Bigstring.t

    val of_bigstring : Bigstring.t -> t

    val size_in_bits : t -> int

    val get_dummy : input_size:int -> t
  end

  module Keypair : sig
    type t

    val typ : t Ctypes.typ

    val delete : t -> unit

    val pk : t -> Proving_key.t

    val vk : t -> Verification_key.t

    val create : r1cs_constraint_system -> t
  end

  module Proof : sig
    type message = unit

    type t

    val typ : t Ctypes.typ

    val delete : t -> unit

    val create :
         ?message:message
      -> Proving_key.t
      -> primary:field_vector
      -> auxiliary:field_vector
      -> t

    val verify :
      ?message:message -> t -> Verification_key.t -> field_vector -> bool

    val get_dummy : unit -> t

    include Binable.S with type t := t
  end
end

module type Field_extension = sig
  type field_vector

  type t [@@deriving bin_io, sexp]

  val typ : t Ctypes_static.typ

  val delete : t -> unit

  val print : t -> unit

  val random : unit -> t

  val square : t -> t

  val sqrt : t -> t

  val create_zero : unit -> t

  val ( + ) : t -> t -> t

  val inv : t -> t

  val ( * ) : t -> t -> t

  val sub : t -> t -> t

  val equal : t -> t -> bool

  val to_vector : t -> field_vector

  val of_vector : field_vector -> t

  val schedule_delete : t -> unit
end

module type Group_intf = sig
  type fp

  type fq

  type bigint

  module Coefficients : sig
    val a : fq

    val b : fq
  end

  type t [@@deriving bin_io]

  val typ : t Ctypes_static.typ

  val add : t -> t -> t

  val ( + ) : t -> t -> t

  val negate : t -> t

  val double : t -> t

  val scale : t -> bigint -> t

  val scale_field : t -> fp -> t

  val zero : t

  val one : t

  module Affine : sig
    type t = fq * fq [@@deriving bin_io]
  end

  val to_affine_exn : t -> Affine.t

  val to_affine : t -> Affine.t option

  val of_affine : Affine.t -> t

  val equal : t -> t -> bool

  val random : unit -> t

  val delete : t -> unit

  val print : t -> unit

  val subgroup_check : t -> unit

  module Vector : Snarky.Vector.S_binable with type elt := t
end

module type Backend_intf = sig
  module Common : Common_intf

  module Default : sig
    module R1CS_constraint_system : sig
      include module type of Common.R1CS_constraint_system

      val finalize : t -> unit
    end

    include
      Common_intf
      with module Field = Common.Field
      with module R1CS_constraint_system := R1CS_constraint_system

    include
      Proof_system_intf
      with type field_vector := Common.Field.Vector.t
       and type r1cs_constraint_system := R1CS_constraint_system.t
  end

  module GM : sig
    module R1CS_constraint_system : sig
      include module type of Common.R1CS_constraint_system

      val finalize : t -> unit
    end

    include
      Common_intf
      with module Field = Common.Field
      with module R1CS_constraint_system := R1CS_constraint_system

    include
      Proof_system_intf
      with type field_vector := Common.Field.Vector.t
       and type r1cs_constraint_system := R1CS_constraint_system.t
  end

  include
    Common_intf
    with module Field = Common.Field
    with module Bigint = Common.Bigint

  val field_size : Bigint.R.t

  module Fq : Field_intf

  module Fqk : sig
    type t

    val typ : t Ctypes.typ

    val delete :
      (t -> unit Snarky.Ctypes_foreign.return) Snarky.Ctypes_foreign.result

    val one : t

    val to_elts : t -> Fq.Vector.t
  end

  module Fqe : Field_extension with type field_vector := Fq.Vector.t

  module G1 :
    Group_intf
    with type fp := Field.t
     and type fq := Fq.t
     and type bigint := Bigint.R.t

  module G2 :
    Group_intf
    with type fp := Field.t
     and type fq := Fqe.t
     and type bigint := Bigint.R.t

  module GM_proof_accessors : sig
    val a : GM.Proof.t -> G1.t

    val b : GM.Proof.t -> G2.t

    val c : GM.Proof.t -> G1.t
  end

  module GM_verification_key_accessors : sig
    val h : GM.Verification_key.t -> G2.t

    val g_alpha : GM.Verification_key.t -> G1.t

    val h_beta : GM.Verification_key.t -> G2.t

    val g_gamma : GM.Verification_key.t -> G1.t

    val h_gamma : GM.Verification_key.t -> G2.t

    val query : GM.Verification_key.t -> G1.Vector.t

    val g_alpha_h_beta : GM.Verification_key.t -> Fqk.t
  end

  module Groth16_proof_accessors : sig
    val a : Default.Proof.t -> G1.t

    val b : Default.Proof.t -> G2.t

    val c : Default.Proof.t -> G1.t
  end

  module Groth16 : sig
    module R1CS_constraint_system : sig
      include module type of Common.R1CS_constraint_system

      val finalize : t -> unit
    end

    include
      Common_intf
      with module Field = Common.Field
      with module R1CS_constraint_system := R1CS_constraint_system

    module Verification_key : sig
      type t = Default.Verification_key.t

      include module type of Default.Verification_key with type t := t

      val delta : t -> G2.t

      val query : t -> G1.Vector.t

      val alpha_beta : t -> Fqk.t
    end

    module Proving_key : sig
      type t = Default.Proving_key.t

      include module type of Default.Proving_key with type t := t
    end

    module Keypair : sig
      type t = Default.Keypair.t

      include module type of Default.Keypair with type t := t
    end
  end
end

module type Snarkette_elliptic_curve = sig
  module N = Snarkette.Nat

  type fq

  type t = {x: fq; y: fq; z: fq} [@@deriving bin_io, sexp, yojson]

  val zero : t

  module Coefficients : sig
    val a : fq

    val b : fq
  end

  module Affine : sig
    type t = fq * fq
  end

  val of_affine : Affine.t -> t

  val is_zero : t -> bool

  val to_affine_exn : t -> Affine.t

  val to_affine : t -> Affine.t option

  val is_well_formed : t -> bool

  val ( + ) : t -> t -> t

  val scale : t -> N.t -> t

  val ( * ) : N.t -> t -> t

  val negate : t -> t

  val ( - ) : t -> t -> t

  val one : t
end

module type Snarkette_GM_processed_verification_key = sig
  type g1

  type g2

  type fqe

  type g1_precomp

  type g2_precomp

  type verification_key

  type t =
    { g_alpha: g1
    ; h_beta: g2
    ; g_alpha_h_beta: fqe
    ; g_gamma_pc: g1_precomp
    ; h_gamma_pc: g2_precomp
    ; h_pc: g2_precomp
    ; query: g1 array }
  [@@deriving bin_io, sexp]

  val create : verification_key -> t
end

module type Snarkette_BG_processed_verification_key = sig
  type g1

  type fqe

  type g2_precomp

  type verification_key

  type t = {alpha_beta: fqe * fqe; delta_pc: g2_precomp; query: g1 array}
  [@@deriving bin_io, sexp]

  val create : verification_key -> t
end

module type Snarkette_tick_intf = sig
  module N = Snarkette.Nat

  module Fq :
    Snarkette.Fields.Fp_intf with module Nat = N and type t = private N.t

  val non_residue : Fq.t

  module Fq3 : sig
    include
      Snarkette.Fields.Degree_3_extension_intf
      with module Nat = N
      with type base = Fq.t

    val non_residue : Fq.t

    val frobenius : t -> int -> t

    module Params : sig
      val frobenius_coeffs_c1 : Fq.t array

      val frobenius_coeffs_c2 : Fq.t array
    end
  end

  module Fq2 :
    Snarkette.Fields.Degree_2_extension_intf
    with module Nat = N
    with type base = Fq.t

  module Fq6 : sig
    include
      Snarkette.Fields.Degree_2_extension_intf
      with module Nat = N
      with type base = Fq3.t

    val mul_by_2345 : t -> t -> t

    val frobenius : t -> int -> t

    val cyclotomic_exp : t -> N.t -> t

    val unitary_inverse : t -> t

    module Params : sig
      val non_residue : Fq.t

      val frobenius_coeffs_c1 : Fq.t array
    end
  end

  module G1 : Snarkette_elliptic_curve with module N := N with type fq := Fq.t

  module G2 : Snarkette_elliptic_curve with module N := N with type fq := Fq3.t

  module Pairing_info : sig
    val twist : Fq3.t

    val loop_count : N.t

    val is_loop_count_neg : bool

    val final_exponent : N.t

    val final_exponent_last_chunk_abs_of_w0 : N.t

    val final_exponent_last_chunk_is_w0_neg : bool

    val final_exponent_last_chunk_w1 : N.t
  end

  module Pairing : sig
    module G1_precomputation : sig
      type t [@@deriving bin_io, sexp]

      val create : G1.t -> t
    end

    module G2_precomputation : sig
      type t [@@deriving bin_io, sexp]

      val create : G2.t -> t
    end

    val final_exponentiation : Fq6.t -> Fq6.t

    val miller_loop : G1_precomputation.t -> G2_precomputation.t -> Fq6.t

    val unreduced_pairing : G1.t -> G2.t -> Fq6.t

    val reduced_pairing : G1.t -> G2.t -> Fq6.t
  end

  module Inputs : sig
    module N = N
    module G1 = G1
    module G2 = G2
    module Fq = Fq
    module Fqe = Fq3
    module Fq_target = Fq6
    module Pairing = Pairing
  end

  module Groth_maller : sig
    module Verification_key : sig
      type t =
        { h: G2.t
        ; g_alpha: G1.t
        ; h_beta: G2.t
        ; g_alpha_h_beta: Fq6.t
        ; g_gamma: G1.t
        ; h_gamma: G2.t
        ; query: G1.t array }
      [@@deriving bin_io, sexp]

      val map_to_two :
        'a sexp_list -> f:('a -> 'b * 'c) -> 'b sexp_list * 'c sexp_list

      val fold_bits : t -> bool Fold_lib.Fold.t

      val fold : t -> (bool * bool * bool) Fold_lib.Fold.t

      module Processed :
        Snarkette_GM_processed_verification_key
        with type g1 := G1.t
         and type g2 := G2.t
         and type fqe := Fq6.t
         and type g1_precomp := Pairing.G1_precomputation.t
         and type g2_precomp := Pairing.G2_precomputation.t
         and type verification_key := t
    end

    val check : bool -> string -> (unit, Error.t) Result.t

    module Proof : sig
      type t = {a: G1.t; b: G2.t; c: G1.t} [@@deriving bin_io, sexp]

      val is_well_formed : t -> unit Or_error.t
    end

    val verify :
      Verification_key.Processed.t -> N.t List.t -> Proof.t -> unit Or_error.t
  end

  module Groth16 : sig
    module Verification_key : sig
      type t = {query: G1.t array; delta: G2.t; alpha_beta: Fq6.t}
      [@@deriving bin_io, sexp]

      type vk = t

      module Processed : sig
        type t =
          { query: G1.t array
          ; alpha_beta: Fq6.t
          ; delta: Pairing.G2_precomputation.t }
        [@@deriving bin_io, sexp]

        val create : vk -> t
      end
    end

    val check : bool -> string -> (unit, Error.t) Base.Result.t

    module Proof : sig
      type t = {a: G1.t; b: G2.t; c: G1.t} [@@deriving bin_io, sexp]

      val is_well_formed : t -> unit Or_error.t
    end

    val one_pc : Pairing.G2_precomputation.t lazy_t

    val verify :
         Verification_key.Processed.t
      -> N.t sexp_list
      -> Proof.t
      -> unit Or_error.t
  end

  module Make_bowe_gabizon (M : sig
    val hash :
         ?message:Fq.t array
      -> a:G1.t
      -> b:G2.t
      -> c:G1.t
      -> delta_prime:G2.t
      -> G1.t
  end) : sig
    module Verification_key : sig
      type t = {alpha_beta: Fq3.t * Fq3.t; delta: G2.t; query: G1.t array}
      [@@deriving bin_io, sexp]

      val map_to_two :
        'a sexp_list -> f:('a -> 'b * 'c) -> 'b sexp_list * 'c sexp_list

      val fold_bits : t -> bool Fold_lib.Fold.t

      val fold : t -> (bool * bool * bool) Fold_lib.Fold.t

      module Processed :
        Snarkette_BG_processed_verification_key
        with type g1 := G1.t
         and type fqe := Fq3.t
         and type g2_precomp := Pairing.G2_precomputation.t
         and type verification_key := t
    end

    val check : bool -> string -> (unit, Error.t) Pervasives.result

    module Proof : sig
      type t = {a: G1.t; b: G2.t; c: G1.t; delta_prime: G2.t; z: G1.t}
      [@@deriving bin_io, sexp]

      val is_well_formed : t -> unit Or_error.t
    end

    val one_pc : Pairing.G2_precomputation.t lazy_t

    val verify :
         ?message:Fq.t array
      -> Verification_key.Processed.t
      -> N.t sexp_list
      -> Proof.t
      -> unit Or_error.t
  end
end

module type Snarkette_tock_intf = sig
  module N = Snarkette.Nat

  module Fq :
    Snarkette.Fields.Fp_intf with module Nat = N and type t = private N.t

  val non_residue : Fq.t

  module Fq2 : sig
    include
      Snarkette.Fields.Degree_2_extension_intf
      with module Nat = N
      with type base = Fq.t

    module Params : sig
      val non_residue : Fq.t
    end
  end

  module Fq4 : sig
    include
      Snarkette.Fields.Degree_2_extension_intf
      with module Nat = N
      with type base = Fq2.t

    module Params : sig
      val frobenius_coeffs_c1 : Fq.t array

      val non_residue : Fq2.t
    end
  end

  module G1 : Snarkette_elliptic_curve with module N := N with type fq := Fq.t

  module G2 : Snarkette_elliptic_curve with module N := N with type fq := Fq2.t

  module Pairing_info : sig
    val twist : Fq.t * Fq.t

    val loop_count : N.t

    val is_loop_count_neg : bool

    val final_exponent : N.t

    val final_exponent_last_chunk_abs_of_w0 : N.t

    val final_exponent_last_chunk_is_w0_neg : bool

    val final_exponent_last_chunk_w1 : N.t
  end
end
