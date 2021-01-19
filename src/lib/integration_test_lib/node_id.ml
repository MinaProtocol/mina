(* HOLD UP: I think we don't need this if we introduce a `From_node.t` type outside. *)

(* Node ids are represented as strings in all integration test engines.
 * This eschews the type safety of having a node id type defined by each
 * test engine, but alleviates the complexity of wiring the node id into
 * components of the base library. We are ok with eschewing this type
 * safety because there is no real danger in doing so; with how this
 * integration test library will be used, we shouldn't need to worry
 * ourselves about protecting type boundaries across multiple engines.
 *)

open Core_kernel

type t = string

let of_string = Fn.id

let to_string = Fn.id
