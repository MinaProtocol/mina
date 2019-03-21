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

  val set_batch :
    t -> ?remove_keys:key list -> update_pairs:(key * value) list -> unit

  val to_alist : t -> (key * value) list
end

module type Mock_intf = sig
  include S

  val random_key : t -> key option

  val to_sexp :
    t -> key_sexp:(key -> Sexp.t) -> value_sexp:(value -> Sexp.t) -> Sexp.t
end

module Make_mock
    (Key : Hashable.S) (Value : sig
        type t
    end) :
  Mock_intf
  with type t = Value.t Key.Table.t
  with type key := Key.t
   and type value := Value.t = struct
  type t = Value.t Key.Table.t

  let to_sexp t ~key_sexp ~value_sexp =
    Key.Table.to_alist t
    |> List.map ~f:(fun (key, value) ->
           [%sexp_of: Sexp.t * Sexp.t] (key_sexp key, value_sexp value) )
    |> [%sexp_of: Sexp.t list]

  let create ~directory:_ = Key.Table.create ()

  let get t ~key = Key.Table.find t key

  let set = Key.Table.set

  let remove t ~key = Key.Table.remove t key

  let close _ = ()

  let random_key t =
    let keys = Key.Table.keys t in
    List.random_element keys

  let set_batch t ?(remove_keys = []) ~update_pairs =
    List.iter update_pairs ~f:(fun (key, data) -> set t ~key ~data) ;
    List.iter remove_keys ~f:(fun key -> remove t ~key)

  let to_alist = Key.Table.to_alist
end
