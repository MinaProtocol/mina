module type Basic = sig
  module Impl : Snarky.Snark_intf.S

  open Impl

  module Unchecked : Snarkette.Fields.Intf

  type t

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

  val zero : t

  val one : t
end

module type Applicative = sig
  type _ t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t
end
