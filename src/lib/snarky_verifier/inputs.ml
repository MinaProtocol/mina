module type S = sig
  module Impl : Snarky.Snark_intf.S

  open Impl

  module G1 : sig
    type t

    module Unchecked : sig
      type t
    end

    val typ : (t, Unchecked.t) Typ.t

    (* This should check if the input is constant and do [scale_known] if so *)
    val scale : t -> Boolean.var list -> (t, _) Checked.t

    val add_exn : t -> t -> (t, _) Checked.t

    module Shifted : sig
      module type S =
        Snarky.Curves.Shifted_intf
        with type ('a, 'b) checked := ('a, 'b) Checked.t
         and type curve_var := t
         and type boolean_var := Boolean.var

      type 'a m = (module S with type t = 'a)

      val create : unit -> ((module S), _) Checked.t
    end
  end

  module G2 : sig
    type t

    val add_exn : t -> t -> (t, _) Checked.t

    module Unchecked : sig
      type t

      val one : t
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
  end

  module Fqk : sig
    type t

    module Unchecked : sig
      type t
    end

    val typ : (t, Unchecked.t) Typ.t

    val ( * ) : t -> t -> (t, _) Checked.t

    val equal : t -> t -> (Boolean.var, _) Checked.t

    val one : t
  end

  val group_miller_loop :
       (Sgn.t * G1_precomputation.t * G2_precomputation.t) list
    -> (Fqk.t, _) Checked.t

  val final_exponentiation : Fqk.t -> (Fqk.t, _) Checked.t
end
