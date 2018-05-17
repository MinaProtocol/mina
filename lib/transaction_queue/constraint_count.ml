open Core_kernel

type t = int
type constraint_count = t
let ( + ) = Int.(+)
let zero = 0
let max_value = Int.max_value

module type Cost_s = sig
  type t
  val cost : t -> constraint_count
end

module type Free_s = sig
  type t
  val free : t -> constraint_count
end
