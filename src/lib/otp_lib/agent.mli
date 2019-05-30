module type Read_only_intf = sig
  type 'a t

  val get : 'a t -> 'a

  val on_update : 'a t -> f:('a -> unit) -> unit
end

module Read_only : Read_only_intf

include Read_only_intf

val create : f:('a -> 'b) -> 'a -> 'b t

val update : 'a t -> 'a -> unit

val read_only : 'a t -> 'a Read_only.t
