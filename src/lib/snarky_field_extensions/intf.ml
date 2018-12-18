module type Applicative = sig
  type _ t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t
end

module type Basic = sig
  module Impl : Snarky.Snark_intf.S

  open Impl

  module Base : sig
    type _ t_

    val map_ : 'a t_ -> f:('a -> 'b) -> 'b t_

    module Unchecked : sig
      type t = Field.t t_
    end

    type t = Field.Checked.t t_
  end

  module A : Applicative

  type 'a t_ = 'a Base.t_ A.t

  val map_ : 'a t_ -> f:('a -> 'b) -> 'b t_

  module Unchecked : Snarkette.Fields.Intf with type t = Base.Unchecked.t A.t

  type t = Base.t A.t

  val typ : (t, Unchecked.t) Typ.t

  val constant : Unchecked.t -> t

  val scale : t -> Field.t -> t

  val assert_r1cs : t -> t -> t -> (unit, _) Checked.t

  val assert_square : [`Define | `Custom of t -> t -> (unit, _) Checked.t]

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val negate : t -> t

  val ( * ) : [`Define | `Custom of t -> t -> (t, _) Checked.t]

  val square : [`Define | `Custom of t -> (t, _) Checked.t]

  val inv : [`Define | `Custom of t -> (t, _) Checked.t]
end

module type S = sig
  include Basic

  open Impl

  val assert_square : t -> t -> (unit, _) Checked.t

  val ( * ) : t -> t -> (t, _) Checked.t

  val square : t -> (t, _) Checked.t

  val inv : t -> (t, _) Checked.t

  (* This function MUST NOT be called on two arguments which are both potentially
   zero *)
  val div_unsafe : t -> t -> (t, _) Checked.t

  val zero : t

  val one : t
end
