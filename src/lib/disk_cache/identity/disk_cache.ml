open Async_kernel
open Core_kernel

module Make (Data : sig
  type t
end) =
struct
  type t = int ref

  type id = { data : Data.t }

  let initialize _path ~logger:_ = Deferred.Result.return (ref 0)

  let get _ (id : id) : Data.t = id.data

  let put (counter : t) x : id =
    incr counter ;
    let res = { data = x } in
    (* When this reference is GC'd, decrement the counter. *)
    Core.Gc.Expert.add_finalizer_last_exn res (fun () -> decr counter) ;
    res

  let count (counter : t) = !counter
end
