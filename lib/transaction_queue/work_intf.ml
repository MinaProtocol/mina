module type S = sig
  type proof
  type input

  type t =
    | Merge of proof * proof
    | Base of input
  [@@deriving eq, bin_io]

  val cost : t -> Constraint_count.t
  val prove : t -> proof
end


