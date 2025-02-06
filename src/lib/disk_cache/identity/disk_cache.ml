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

let%test_module "disk_cache identity" =
  ( module struct
    include Disk_cache_test_lib.Make (Make)

    let%test_unit "remove data on gc" = remove_data_on_gc ()

    let%test_unit "simple read/write" = simple_write ()
  end )
