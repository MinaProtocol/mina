(* Construction of Rational Points on Elliptic Curves over Finite Fields by Andrew Shallue and Christiaan E. van de Woestijne.
 * found at eg https://works.bepress.com/andrew_shallue/1/download/
 *)

module Field_intf = Field_intf

module Intf (F : sig
  type t
end) : sig
  module type S = sig
    val to_group : F.t -> F.t * F.t
  end
end

module Params : sig
  type 'f t

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type nonrec 'f t = 'f t
    end
  end]

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val a : 'f t -> 'f

  val b : 'f t -> 'f

  val create :
    (module Field_intf.S_unchecked with type t = 'f) -> a:'f -> b:'f -> 'f t
end

module Make
    (Constant : Field_intf.S) (F : sig
        include Field_intf.S

        val constant : Constant.t -> t
    end) (Params : sig
      val params : Constant.t Params.t
    end) : sig
  val potential_xs : F.t -> F.t * F.t * F.t
end

val to_group :
     (module Field_intf.S_unchecked with type t = 'f)
  -> params:'f Params.t
  -> 'f
  -> 'f * 'f
