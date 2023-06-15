(** Implementing vectors with pre-defined length. For a fixed length version, see
    {!Vector} *)
(* TODO: Check if that's adequate/useful. The module does not provide type level
   encoded theories enforcing properties on the length *)

(** {2 Type definitions} *)

type ('a, 'b) t

type ('a, 'n) at_most = ('a, 'n) t

(** {2 Module signatures} *)

module type S = sig
  type 'a t

  include Sigs.Hash_foldable.S1 with type 'a t := 'a t

  include Sigs.Comparable.S1 with type 'a t := 'a t

  include Sigs.Jsonable.S1 with type 'a t := 'a t

  include Sigs.Sexpable.S1 with type 'a t := 'a t
end

module type VERSIONED = sig
  type 'a ty

  module Stable : sig
    module V1 : sig
      type 'a t = 'a ty

      include Sigs.VERSIONED

      include Sigs.Binable.S1 with type 'a t := 'a t

      include S with type 'a t := 'a t
    end
  end

  type 'a t = 'a Stable.V1.t

  include S with type 'a t := 'a t
end

(** {2 Modules}*)

module At_most_2 : VERSIONED with type 'a ty = ('a, Nat.N2.n) at_most

module At_most_8 : VERSIONED with type 'a ty = ('a, Nat.N8.n) at_most

module With_length (N : Nat.Intf) : S with type 'a t = ('a, N.n) at_most

val of_vector :
  'a 'n 'm. ('a, 'n) Vector.vec -> ('n, 'm) Nat.Lte.t -> ('a, 'm) t

(** [to_vector m] transforms [m] into a vector whose length is forgotten at the
    type level and only contains runtime data *)
val to_vector : 'a 'n. ('a, 'n) t -> 'a Vector.e
