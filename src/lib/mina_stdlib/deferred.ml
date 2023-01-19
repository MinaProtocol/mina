open Core_kernel
open Async_kernel

include (
  Deferred : module type of Deferred with module Result := Deferred.Result )

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
  end
end
