module type Traversable_applicative = sig
  type _ t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t

  module Impl : Snarky_backendless.Snark_intf.S

  open Impl

  val sequence : ('a, 's) Checked.t t -> ('a t, 's) Checked.t
end

module type Basic = sig
  module Impl : Snarky_backendless.Snark_intf.S

  open Impl

  module Base : sig
    type _ t_

    val map_ : 'a t_ -> f:('a -> 'b) -> 'b t_

    module Unchecked : sig
      type t = Field.t t_ [@@deriving yojson]
    end

    type t = Field.Var.t t_
  end

  module A : Traversable_applicative with module Impl := Impl

  type 'a t_ = 'a Base.t_ A.t

  val to_list : 'a t_ -> 'a list

  val map_ : 'a t_ -> f:('a -> 'b) -> 'b t_

  val map2_ : 'a t_ -> 'b t_ -> f:('a -> 'b -> 'c) -> 'c t_

  module Unchecked :
    Snarkette.Fields.Sqrt_field_intf with type t = Base.Unchecked.t A.t

  type t = Base.t A.t

  val typ : (t, Unchecked.t) Typ.t

  val constant : Unchecked.t -> t

  val to_constant : t -> Unchecked.t option

  val scale : t -> Field.t -> t

  val mul_field : t -> Field.Var.t -> (t, _) Checked.t

  val assert_r1cs : t -> t -> t -> (unit, _) Checked.t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val negate : t -> t

  val if_ : Boolean.var -> then_:t -> else_:t -> (t, _) Checked.t

  (* These definitions are shadowed in the below interface *)
  val assert_square : [`Define | `Custom of t -> t -> (unit, _) Checked.t]

  val ( * ) : [`Define | `Custom of t -> t -> (t, _) Checked.t]

  val square : [`Define | `Custom of t -> (t, _) Checked.t]

  val inv_exn : [`Define | `Custom of t -> (t, _) Checked.t]

  val real_part : 'a t_ -> 'a
end

module type S = sig
  include Basic

  open Impl

  val equal : t -> t -> (Boolean.var, _) Checked.t

  val assert_square : t -> t -> (unit, _) Checked.t

  val assert_equal : t -> t -> (unit, _) Checked.t

  val ( * ) : t -> t -> (t, _) Checked.t

  val square : t -> (t, _) Checked.t

  (* This function MUST NOT be called on two arguments which are both potentially
   zero *)
  val div_unsafe : t -> t -> (t, _) Checked.t

  val inv_exn : t -> (t, _) Checked.t

  val zero : t

  val one : t
end

module type S_with_primitive_element = sig
  include S

  val mul_by_primitive_element : t -> t
end
