open Stdune

module type S = sig
  val always : (unit -> unit) -> unit
  val once : (unit -> unit) -> unit
  val run : unit -> unit
end

module Hooks_manager = struct
  let persistent_hooks = ref []

  let one_off_hooks = ref []

  let always hook =
    persistent_hooks := hook :: !persistent_hooks

  let once hook =
    one_off_hooks := hook :: !one_off_hooks

  let run () =
    List.iter !one_off_hooks ~f:(fun f -> f ());
    List.iter !persistent_hooks ~f:(fun f -> f ());
    one_off_hooks := []
end

module End_of_build = struct
  include Hooks_manager
end

module End_of_build_not_canceled = struct
  include Hooks_manager

  let clear () =
    one_off_hooks := []
end

let () = at_exit End_of_build.run
let () = at_exit End_of_build_not_canceled.run
