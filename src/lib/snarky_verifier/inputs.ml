open Sgn_type

module type Fqe_intf = sig
  module Impl : Snarky.Snark_intf.S

  open Impl

  type _ t_

  type t = Field.Var.t t_

  val real_part : 'a t_ -> 'a

  val to_list : 'a t_ -> 'a list

  val if_ :
       Boolean.var
    -> then_:Field.Var.t t_
    -> else_:Field.Var.t t_
    -> (Field.Var.t t_, _) Checked.t

  val typ : (Field.Var.t t_, Field.t t_) Typ.t

  val one : t

  val ( - ) : t -> t -> t

  val square : t -> (t, _) Checked.t

  val assert_square : t -> t -> (unit, _) Checked.t

  module Unchecked : sig
    type t = Field.t t_

    val one : t

    val square : t -> t

    val sqrt : t -> t

    val ( - ) : t -> t -> t

    val negate : t -> t
  end
end

module type S = sig
  module Impl : Snarky.Snark_intf.S

  open Impl

  module Fqe : Fqe_intf with module Impl := Impl

  module G1 : sig
    type t

    module Unchecked : sig
      type t

      val to_affine_exn : t -> Field.t * Field.t
    end

    val typ : (t, Unchecked.t) Typ.t

    val decompress : Field.Var.t * Boolean.var -> (t, _) Checked.t

    module Shifted : sig
      module type S =
        Snarky.Curves.Shifted_intf
        with type ('a, 'b) checked := ('a, 'b) Checked.t
         and type curve_var := t
         and type boolean_var := Boolean.var

      type 'a m = (module S with type t = 'a)

      val create : unit -> ((module S), _) Checked.t
    end

    (* This should check if the input is constant and do [scale_known] if so *)
    val scale :
         's Shifted.m
      -> t
      -> Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
      -> init:'s
      -> ('s, _) Checked.t
  end

  module G2 : sig
    type t

    val decompress : Field.Var.t Fqe.t_ * Boolean.var -> (t, _) Checked.t

    module Shifted : sig
      module type S =
        Snarky.Curves.Shifted_intf
        with type ('a, 'b) checked := ('a, 'b) Checked.t
         and type curve_var := t
         and type boolean_var := Boolean.var

      type 'a m = (module S with type t = 'a)

      val create : unit -> ((module S), _) Checked.t
    end

    module Unchecked : sig
      type t

      val one : t

      val to_affine_exn : t -> Fqe.Unchecked.t * Fqe.Unchecked.t
    end

    val typ : (t, Unchecked.t) Typ.t
  end

  module G1_precomputation : sig
    type t

    val create : G1.t -> t
  end

  module G2_precomputation : sig
    type t

    val create : G2.t -> (t, _) Checked.t

    val create_constant : G2.Unchecked.t -> t

    val if_ : Boolean.var -> then_:t -> else_:t -> (t, _) Checked.t
  end

  module Fqk : sig
    type t

    module Unchecked : sig
      type t [@@deriving sexp]
    end

    val typ : (t, Unchecked.t) Typ.t

    val ( * ) : t -> t -> (t, _) Checked.t

    val equal : t -> t -> (Boolean.var, _) Checked.t

    val one : t

    val if_ : Boolean.var -> then_:t -> else_:t -> (t, _) Checked.t
  end

  val batch_miller_loop :
       (Sgn.t * G1_precomputation.t * G2_precomputation.t) list
    -> (Fqk.t, _) Checked.t

  val final_exponentiation : Fqk.t -> (Fqk.t, _) Checked.t
end
