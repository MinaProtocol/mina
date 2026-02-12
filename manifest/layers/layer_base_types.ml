(** Mina base types layer: core types that sit above crypto primitives.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

(* This layer is reserved for libraries that need both base and crypto
   dependencies, breaking the base<->crypto cycle. Currently empty as
   the dependency analysis showed these libraries can remain in their
   current layers without causing cycles. *)
