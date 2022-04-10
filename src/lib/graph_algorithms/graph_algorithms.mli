module Nat = Nat

type 'a adjacency_list = ('a * 'a list) list

module Make : functor (V : Core_kernel.Comparable.S) -> sig
  module G : sig
    type t = V.Set.t V.Map.t
  end

  val connected_component :
       G.t
    -> V.Set.Elt.t
    -> (V.Map.Key.t, V.Set.Elt.comparator_witness) Core_kernel.Set.t

  val choose : G.t -> V.t option

  val connected : G.t -> bool

  val remove_vertex : G.t -> V.Map.Key.t -> G.t

  val connectivity : G.t -> Nat.t
end

val connectivity :
     (module Core_kernel.Comparable.S with type t = 'a)
  -> 'a adjacency_list
  -> Nat.t
