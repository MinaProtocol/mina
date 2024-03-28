open Core_kernel
open Async_kernel

include (
  Deferred :
    module type of Deferred
      with module List := Deferred.List
       and module Result := Deferred.Result )

module List = struct
  open Deferred.Let_syntax
  include Deferred.List

  let fold_until ls ~init ~f ~finish =
    let open Continue_or_stop in
    match%bind
      fold ls ~init ~f:(fun acc x ->
          match acc with
          | Continue acc' ->
              f acc' x
          | Stop result ->
              return (Stop result) )
    with
    | Continue acc ->
        finish acc
    | Stop result ->
        return result
end

module Result = struct
  include Deferred.Result

  module List = struct
    open Deferred.Result.Let_syntax

    let fold ls ~init ~f =
      Core_kernel.List.fold ls ~init:(return init) ~f:(fun acc x ->
          let%bind acc' = acc in
          f acc' x )

    let map ls ~f =
      fold ls ~init:[] ~f:(fun acc x ->
          let%map x' = f x in
          x' :: acc )
      >>| Core_kernel.List.rev

    let iter ls ~f = fold ls ~init:() ~f:(fun () -> f)
  end
end
