open Core_kernel

type 'a t = T of 'a * 'a t list

let rec of_list_exn = function
  | [] ->
      raise
        (Invalid_argument
           "Rose_tree.of_list_exn: cannot construct rose tree from empty list")
  | [h] -> T (h, [])
  | h :: t -> T (h, [of_list_exn t])

let rec equal ~f (T (value1, children1)) (T (value2, children2)) =
  f value1 value2 && List.equal ~equal:(equal ~f) children1 children2

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

  val map : 'a t -> f:('a -> 'b Monad.t) -> 'b t Monad.t

  val fold_map : 'a t -> init:'b -> f:('b -> 'a -> 'b Monad.t) -> 'b t Monad.t
end

module Make_ops (Monad : Monad_intf) : Ops_intf with module Monad := Monad =
struct
  open Monad.Let_syntax

  let rec iter (T (base, successors)) ~f =
    let%bind () = f base in
    Monad.List.iter successors ~f:(iter ~f)

  let rec map (T (base, successors)) ~f =
    let%bind base' = f base in
    let%map successors' = Monad.List.map successors ~f:(map ~f) in
    T (base', successors')

  let rec fold_map (T (base, successors)) ~init ~f =
    let%bind base' = f init base in
    let%map successors' = Monad.List.map successors ~f:(fold_map ~init ~f) in
    T (base', successors')
end

include Make_ops (struct
  include Monad.Ident
  module List = List
end)

module Deferred = struct
  include Make_ops (struct
    open Async_kernel

    include (Deferred : Monad.S with type +'a t = 'a Deferred.t)

    module List = struct
      open Deferred.List

      let iter ls ~f = iter ~how:`Sequential ls ~f

      let map ls ~f = map ~how:`Sequential ls ~f
    end
  end)

  module Or_error = Make_ops (struct
    open Async_kernel

    include (
      Deferred.Or_error : Monad.S with type +'a t = 'a Deferred.Or_error.t )

    module List = struct
      open Deferred.Or_error.List

      let iter ls ~f = iter ~how:`Sequential ls ~f

      let map ls ~f = map ~how:`Sequential ls ~f
    end
  end)
end

module Or_error = Make_ops (struct
  include Or_error

  module List = struct
    open Or_error.Let_syntax

    let iter ls ~f =
      List.fold_left ls ~init:(return ()) ~f:(fun or_error x ->
          let%bind () = or_error in
          f x )

    let map ls ~f =
      let%map ls' =
        List.fold_left ls ~init:(return []) ~f:(fun or_error x ->
            let%bind t = or_error in
            let%map x' = f x in
            x' :: t )
      in
      List.rev ls'
  end
end)
