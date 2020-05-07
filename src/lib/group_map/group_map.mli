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

module type S = sig
  module Spec : sig
    type _ t
  end

  module Params : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type _ t [@@deriving bin_io]
      end
    end]

    type 'f t = 'f Stable.Latest.t

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val spec : 'f t -> 'f Spec.t

    val create :
      (module Field_intf.S_unchecked with type t = 'f) -> 'f Spec.t -> 'f t
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
end

module Bw19 : S

module Spec : sig
  type 'f t = {a: 'f; b: 'f} [@@deriving fields]
end

include S with module Spec := Spec
