(* imeckler: I had originally implemented this using virtual libraries, which is much nicer,
   but js_of_ocaml had issues linking it properly. *)
module type S = sig
  module Store : Key_cache.S with module M := Core_kernel.Or_error

  val store :
       read:(string -> 'a option)
    -> write:('a -> string -> unit)
    -> (string, 'a) Store.Disk_storable.t

  val run_in_thread : (unit -> 'a) -> 'a Async_kernel.Deferred.t
end

let (get : unit -> (module S)), (set : (module S) -> unit) =
  let m = ref None in
  let get () =
    match !m with
    | None ->
        failwith
          "Zexe_backend platform specific features not set. Add a dependency \
           to zexe_backend.js or zexe_backend.unix"
    | Some m ->
        m
  in
  let set x =
    match !m with
    | Some _ ->
        failwith "Zexe_backend platform specific set multiple times"
    | None ->
        m := Some x
  in
  (get, set)
