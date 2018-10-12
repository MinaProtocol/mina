open Core_kernel
open Tuple_lib

module type S = sig
  type 'a t = private 'a list

  include Container.S1 with type 'a t := 'a t

  val of_list : 'a list -> 'a t

  val init : int -> f:(int -> 'a) -> 'a t

  val map : 'a t -> f:('a -> 'b) -> 'b t
end

module rec Msb_first : sig
  include S

  val of_lsb_first : 'a Lsb_first.t -> 'a t
end

and Lsb_first : sig
  include S

  val of_msb_first : 'a Lsb_first.t -> 'a t
end

val pad_to_triple_list : default:'a -> 'a list -> 'a Triple.t list
