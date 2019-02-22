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

let subset ~f xs ys =
  List.(fold xs ~init:true ~f:(fun acc x -> acc && mem ys x ~equal:f))

let bag_equiv ~f xs ys = subset ~f xs ys && subset ~f ys xs

let rec equiv ~f (T (x1, ts1)) (T (x2, ts2)) =
  f x1 x2 && bag_equiv ~f:(equiv ~f) ts1 ts2

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
    let%map successors' =
      Monad.List.map successors ~f:(fold_map ~init:base' ~f)
    in
    T (base', successors')
end

include Make_ops (struct
  include Monad.Ident
  module List = List
end)

let rec flatten (T (x, ts)) = x :: List.concat_map ts ~f:flatten

module Deferred = struct
  open Async_kernel

  include Make_ops (struct
    include (Deferred : Monad.S with type +'a t = 'a Deferred.t)

    module List = struct
      open Deferred.List

      let iter ls ~f = iter ~how:`Sequential ls ~f

      let map ls ~f = map ~how:`Sequential ls ~f
    end
  end)

  let rec all (T (x', ts')) =
    let open Deferred.Let_syntax in
    let%bind x = x' in
    let%bind ts = Deferred.all @@ List.map ~f:all ts' in
    return @@ T (x, ts)
end
