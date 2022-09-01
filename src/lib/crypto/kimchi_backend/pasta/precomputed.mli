(* val g : string -> string *)

module Lagrange_precomputations : sig
  val index_of_domain_log2 : int -> int

  val vesta : (Pasta_bindings.Fq.t * Pasta_bindings.Fq.t) array array array

  val pallas : (Pasta_bindings.Fp.t * Pasta_bindings.Fp.t) array array array
end
