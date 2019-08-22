module E2
    (F : Intf.S) (Params : sig
        val non_residue : F.Unchecked.t

        val mul_by_non_residue : F.t -> F.t
    end) : sig
  include
    Intf.S_with_primitive_element
    with module Impl = F.Impl
     and module Base = F
     and type 'a A.t = 'a * 'a

  val unitary_inverse : t -> t
end

module F (Impl : Snarky.Snark_intf.S) :
  Intf.S with type 'a Base.t_ = 'a and type 'a A.t = 'a and module Impl = Impl

module E3
    (F : Intf.S) (Params : sig
        val non_residue : F.Unchecked.t

        val frobenius_coeffs_c1 : F.Unchecked.t array

        val frobenius_coeffs_c2 : F.Unchecked.t array

        val mul_by_non_residue : F.t -> F.t
    end) :
  Intf.S_with_primitive_element
  with module Impl = F.Impl
   and module Base = F
   and type 'a A.t = 'a * 'a * 'a

module F3
    (F : Intf.S with type 'a A.t = 'a and type 'a Base.t_ = 'a) (Params : sig
        val non_residue : F.Unchecked.t

        val frobenius_coeffs_c1 : F.Unchecked.t array

        val frobenius_coeffs_c2 : F.Unchecked.t array
    end) :
  Intf.S_with_primitive_element
  with module Impl = F.Impl
   and module Base = F
   and type 'a A.t = 'a * 'a * 'a

module F6
    (Fq : Intf.S with type 'a A.t = 'a and type 'a Base.t_ = 'a)
    (Fq2 : Intf.S_with_primitive_element
           with module Impl = Fq.Impl
            and type 'a A.t = 'a * 'a
            and type 'a Base.t_ = 'a Fq.t_) (Fq3 : sig
        include
          Intf.S_with_primitive_element
          with module Impl = Fq.Impl
           and type 'a A.t = 'a * 'a * 'a
           and type 'a Base.t_ = 'a Fq.t_

        module Params : sig
          val non_residue : Fq.Unchecked.t

          val frobenius_coeffs_c1 : Fq.Unchecked.t array

          val frobenius_coeffs_c2 : Fq.Unchecked.t array
        end
    end) (Params : sig
      val frobenius_coeffs_c1 : Fq.Unchecked.t array
    end) : sig
  include
    Intf.S_with_primitive_element
    with module Impl = Fq.Impl
     and module Base = Fq3
     and type 'a A.t = 'a * 'a

  val unitary_inverse : t -> t

  val special_mul :
    Fq3.t * Fq3.t -> Fq3.t * Fq3.t -> (Fq3.t * Fq3.t, 'a) Impl.Checked.t

  val assert_special_mul : t -> t -> t -> (unit, _) Impl.Checked.t

  val special_div_unsafe : t -> t -> (t, _) Impl.Checked.t

  val special_div : t -> t -> (t, _) Impl.Checked.t

  val cyclotomic_square : t -> (t, _) Impl.Checked.t

  (* By parametricity we can see that frobenius fixes the 
   part lying in the base field :) *)
  val frobenius :
       ('a * Fq.t * Fq.t) * (Fq.t * Fq.t * Fq.t)
    -> int
    -> ('a * Fq.t * Fq.t) * (Fq.t * Fq.t * Fq.t)
end

module F4
    (Fq2 : Intf.S_with_primitive_element
           with type 'a A.t = 'a * 'a
            and type 'a Base.t_ = 'a) (Params : sig
        val frobenius_coeffs_c1 : Fq2.Impl.Field.t array
    end) : sig
  include
    Intf.S_with_primitive_element
    with module Impl = Fq2.Impl
     and module Base = Fq2
     and type 'a A.t = 'a * 'a

  val unitary_inverse : t -> t

  val special_mul : t -> t -> (t, 'a) Impl.Checked.t

  val special_div : t -> t -> (t, 'a) Impl.Checked.t

  val cyclotomic_square :
    Fq2.t * Fq2.t -> (Fq2.t * Fq2.t, 'a) Fq2.Impl.Checked.t

  val frobenius :
       ('a * Impl.field Snarky.Cvar.t)
       * (Impl.field Snarky.Cvar.t * Impl.field Snarky.Cvar.t)
    -> int
    -> ('a * Impl.field Snarky.Cvar.t)
       * (Impl.field Snarky.Cvar.t * Impl.field Snarky.Cvar.t)
end
