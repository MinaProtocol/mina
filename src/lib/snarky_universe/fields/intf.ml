module type Applicative = sig
  type _ t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t
end

module type Basic = sig
  module Impl : Snarky.Snark_intf.Run

  open Impl

  module Base : sig
    type _ t_

    val map_ : 'a t_ -> f:('a -> 'b) -> 'b t_

    module Constant : sig
      type t = Field.Constant.t t_
    end

    type t = Field.t t_
  end

  module A : Applicative

  type 'a t_ = 'a Base.t_ A.t

  val to_list : 'a t_ -> 'a list

  val map_ : 'a t_ -> f:('a -> 'b) -> 'b t_

  val map2_ : 'a t_ -> 'b t_ -> f:('a -> 'b -> 'c) -> 'c t_

  module Constant :
    Snarkette.Fields.Sqrt_field_intf with type t = Base.Constant.t A.t

  type t = Base.t A.t

  val typ : (t, Constant.t) Typ.t

  val constant : Constant.t -> t

  val to_constant : t -> Constant.t option

  val scale : t -> Field.Constant.t -> t

  val mul_field : t -> Field.t -> t

  val assert_r1cs : t -> t -> t -> unit

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val negate : t -> t

  val if_ : Boolean.var -> then_:t -> else_:t -> t

  (* These definitions are shadowed in the below interface *)
  val assert_square : [`Define | `Custom of t -> t -> (unit) ]

  val ( * ) : [`Define | `Custom of t -> t -> t]

  val square : [`Define | `Custom of t -> t]

  val inv_exn : [`Define | `Custom of t -> t]

  val real_part : 'a t_ -> 'a
end

module type S = sig
  include Basic

  open Impl

  val equal : t -> t -> Boolean.var

  val assert_square : t -> t -> unit

  val assert_equal : t -> t -> unit

  val ( * ) : t -> t -> t

  val square : t -> t

  (* This function MUST NOT be called on two arguments which are both potentially
   zero *)
  val div_unsafe : t -> t -> t

  val inv_exn : t -> t

  val zero : t

  val one : t
end

module type S_with_primitive_element = sig
  include S

  val mul_by_primitive_element : t -> t
end
