open Core_kernel

module type S = sig
  type t

  type key

  type value

  val create : directory:string -> t

  val close : t -> unit

  val get : t -> key:key -> value option

  val set : t -> key:key -> data:value -> unit

  val remove : t -> key:key -> unit
end

module Make_mock
    (Key : Hashable.S) (Value : sig
        type t
    end) : S with type key := Key.t and type value := Value.t = struct
  type t = Value.t Key.Table.t

  let create ~directory:_ = Key.Table.create ()

  let get t ~key = Key.Table.find t key

  let set = Key.Table.set

  let remove t ~key = Key.Table.remove t key

  let close _ = ()
end
