open Core_kernel

module type Read_only_intf = sig
  type 'a t

  val get : 'a t -> 'a

  val on_update : 'a t -> f:('a -> unit) -> unit
end

module T = struct
  type 'a t = {mutable a: 'a; mutable on_update: 'a -> unit}

  let create ~(f : 'a -> 'b) x : 'b t = {a= f x; on_update= Fn.ignore}

  let get t = t.a

  let update t a =
    t.a <- a ;
    t.on_update a

  let on_update t ~f = t.on_update <- (fun a -> t.on_update a ; f a)
end

include T

module Read_only = struct
  include T
end

let read_only = Fn.id
