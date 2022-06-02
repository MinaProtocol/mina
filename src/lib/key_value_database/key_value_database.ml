open Core_kernel

module Monad = struct
  module type S = sig
    type 'a t

    include Monad.S with type 'a t := 'a t

    module Result : sig
      val lift : 'value t -> ('value, 'err) Result.t t

      type nonrec ('value, 'err) t = ('value, 'err) Result.t t

      include Monad.S2 with type ('value, 'err) t := ('value, 'err) t
    end

    module Option : sig
      type nonrec 'a t = 'a option t

      include Monad.S with type 'a t := 'a t
    end
  end

  module Ident = struct
    include Monad.Ident

    module Result = struct
      let lift = Result.return

      include Result
    end

    module Option = Option
  end
end

module Intf = struct
  module type S = sig
    type t

    type key

    type value

    type config

    module M : Monad.S

    val create : config -> t

    val close : t -> unit

    val get : t -> key:key -> value option M.t

    val get_batch : t -> keys:key list -> value option list M.t

    val set : t -> key:key -> data:value -> unit M.t

    val remove : t -> key:key -> unit M.t

    val set_batch :
      t -> ?remove_keys:key list -> update_pairs:(key * value) list -> unit M.t

    val to_alist : t -> (key * value) list M.t
  end

  module type Ident = S with module M := Monad.Ident

  module type Mock = sig
    include Ident

    val random_key : t -> key option

    val to_sexp :
      t -> key_sexp:(key -> Sexp.t) -> value_sexp:(value -> Sexp.t) -> Sexp.t
  end
end

module Make_mock
    (Key : Hashable.S) (Value : sig
      type t
    end) :
  Intf.Mock
    with type t = Value.t Key.Table.t
     and type key := Key.t
     and type value := Value.t
     and type config := unit = struct
  type t = Value.t Key.Table.t

  let to_sexp t ~key_sexp ~value_sexp =
    Key.Table.to_alist t
    |> List.map ~f:(fun (key, value) ->
           [%sexp_of: Sexp.t * Sexp.t] (key_sexp key, value_sexp value) )
    |> [%sexp_of: Sexp.t list]

  let create _ = Key.Table.create ()

  let get t ~key = Key.Table.find t key

  let get_batch t ~keys = List.map keys ~f:(Key.Table.find t)

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
