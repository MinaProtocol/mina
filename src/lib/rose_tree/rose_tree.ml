open Core_kernel

type 'a t = T of 'a * 'a t list

let rec of_list_exn = function
  | [] ->
      raise
        (Invalid_argument
           "Rose_tree.of_list_exn: cannot construct rose tree from empty list")
  | [h] -> T (h, [])
  | h :: t -> T (h, [of_list_exn t])

module type Monad_intf = sig
  include Monad.S

  module List : sig
    val iter : 'a list -> f:('a -> unit t) -> unit t

    val map : 'a list -> f:('a -> 'b t) -> 'b list t
  end
end

module type Ops_intf = sig
  module Monad : Monad_intf

  val iter : 'a t -> f:('a -> unit Monad.t) -> unit Monad.t

  val fold_map : 'a t -> init:'b -> f:('b -> 'a -> 'b Monad.t) -> 'b t Monad.t
end

module Make_ops (Monad : Monad_intf) : Ops_intf with module Monad := Monad =
struct
  open Monad.Let_syntax

  let rec iter (T (base, successors)) ~f =
    let%bind () = f base in
    Monad.List.iter successors ~f:(iter ~f)

  let rec fold_map (T (base, successors)) ~init ~f =
    let%bind base' = f init base in
    let%map successors' = Monad.List.map successors ~f:(fold_map ~init ~f) in
    T (base', successors')
end

include Make_ops (struct
  include Monad.Ident
  module List = List
end)

module Deferred = Make_ops (struct
  open Async_kernel

  include (Deferred : Monad.S with type +'a t = 'a Deferred.t)

  module List = struct
    open Deferred.List

    let iter ls ~f = iter ~how:`Sequential ls ~f

    let map ls ~f = map ~how:`Sequential ls ~f
  end
end)
