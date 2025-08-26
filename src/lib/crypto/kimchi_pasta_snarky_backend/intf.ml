module type T0 = sig
  type t
end

module type Type_with_delete = sig
  type t

  val delete : t -> unit
end

module type Vector = sig
  type elt

  include Type_with_delete

  val create : unit -> t

  val emplace_back : t -> elt -> unit

  val length : t -> int

  val get : t -> int -> elt
end

module type Triple = sig
  type elt

  type t

  val f0 : t -> elt

  val f1 : t -> elt

  val f2 : t -> elt
end

module type Pair_basic = sig
  type elt

  type t

  val f0 : t -> elt

  val f1 : t -> elt
end

module type Pair = sig
  include Pair_basic

  module Vector : Vector with type elt = t

  val make : elt -> elt -> t
end
