open Core_kernel

module type Data_intf = sig
  type key

  type t

  val to_key : t -> key

  val copy : t -> t
end

module type S = sig
  type key

  type data

  type t

  val create : ?growth_allowed:bool -> ?size:int -> unit -> t

  val save : t -> data -> unit

  val free : t -> key -> unit

  val find : t -> key -> data option
end

exception Free_unsaved_value

module Make (Key : Hashable.S) (Data : Data_intf with type key := Key.t) :
  S with type key := Key.t and type data := Data.t = struct
  type t = (Data.t * int) Key.Table.t

  let create = Key.Table.create

  let save t data =
    let key = Data.to_key data in
    Key.Table.change t key ~f:(function
      | None -> Some (Data.copy data, 1)
      | Some (d, n) -> Some (d, n) )

  let free t key =
    Key.Table.change t key ~f:(function
      | None -> raise Free_unsaved_value
      | Some (_, 1) -> None
      | Some (d, n) -> Some (d, n - 1) )

  let find t key = Key.Table.find t key |> Option.map ~f:fst
end
