(** These allows you to represent one or another or both while keeping
 * neither unrepresentable *)
type ('a, 'b) t = [`This of 'a | `That of 'b | `Those of 'a * 'b]
