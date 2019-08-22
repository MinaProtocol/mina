module type Params = sig
  module N : Snarkette.Nat_intf.S

  val loop_count : N.t

  val loop_count_is_neg : bool

  val final_exponent_last_chunk_w1 : N.t

  val final_exponent_last_chunk_is_w0_neg : bool

  val final_exponent_last_chunk_abs_of_w0 : N.t

  val embedding_degree : [`_4 | `_6]
end

module type Fq =
  Snarky_field_extensions.Intf.S with type 'a A.t = 'a and type 'a Base.t_ = 'a

module type Fqe = Snarky_field_extensions.Intf.S_with_primitive_element

module type G2 = sig
  module Fqe : Fqe

  module Unchecked : sig
    type t

    val to_affine_exn : t -> Fqe.Unchecked.t * Fqe.Unchecked.t
  end
end

module type Fqk = sig
  include Snarky_field_extensions.Intf.S with type 'a A.t = 'a * 'a

  val cyclotomic_square : t -> (t, _) Impl.Checked.t

  val frobenius : t -> int -> t

  val special_mul : t -> t -> (t, _) Impl.Checked.t

  val special_div : t -> t -> (t, _) Impl.Checked.t

  val unitary_inverse : t -> t
end

module type G1_precomputation = sig
  module Fqe : Fqe

  open Fqe.Impl

  type t = {p: Field.Var.t * Field.Var.t; py_twist_squared: Fqe.t}

  val create : Field.Var.t * Field.Var.t -> t
end

module type G2_precomputation = sig
  module Fqe : Fqe

  module G2 : G2 with module Fqe := Fqe

  open Fqe.Impl

  module Coeff : sig
    type t = {rx: Fqe.t; ry: Fqe.t; gamma: Fqe.t; gamma_x: Fqe.t}
  end

  type t = {q: Fqe.t * Fqe.t; coeffs: Coeff.t list}

  val create : Fqe.t * Fqe.t -> (t, _) Checked.t

  val create_constant : G2.Unchecked.t -> t

  val if_ : Boolean.var -> then_:t -> else_:t -> (t, _) Checked.t
end
