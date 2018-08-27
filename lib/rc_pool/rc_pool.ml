open Core_kernel

module type S = sig
  type key

  type 'a t

  val incr : 'a t -> key:key -> data:'a -> unit

  val decr : 'a t -> key -> unit

  val find : 'a t -> key -> 'a option
end

module Make (Key : Hashable.S) : S with type key := Key.t = struct
  type 'a t = ('a * int) Key.Table.t

  let incr t ~key ~data =
    Key.Table.change t key ~f:(function
      | None -> Some (data, 1)
      | Some (_, x) -> Some (data, Int.succ x) )

  let decr t key =
    Key.Table.change t key ~f:(function
      | None -> None
      | Some (_, 1) -> None
      | Some (data, x) -> Some (data, Int.pred x) )

  let find t key = Key.Table.find t key |> Option.map ~f:fst
end
