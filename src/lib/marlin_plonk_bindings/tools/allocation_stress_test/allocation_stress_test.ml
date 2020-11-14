open Core_kernel

(** Stress-tester for allocations in the return values of bindings.

    This interacts with the GC in a deliberately pathalogical way to increase
    the likelihood of hitting any memory issues that may arise while allocating
    the OCaml return values from non-OCaml code. In particular
    * allocations are all held within a long-lived array, so that it is
      promoted to the major heap, so that the allocated values form a minor ->
      major pointer
    * the number of allocations is randomized to increase the chance of a minor
      GC happening between each of the allocations in the binding
    * values in the long-lived array have a chance of not being overwritten, so
      that some of them will be promoted to the major heap before being GC'd
    * values allocated that are not stored in the long-lived array will usually
      remain in the minor heap and be collected as part of a minor GC.

    The intention is that this runs only 1 binding in a tight loop, so that we
    can say for certain that a particular binding is causing the memory issue
    if any are seen.
*)

module type S = sig
  type t

  (** The name that should be passed to the CLI to call the function. *)
  val name : string

  (** Call the binding.
      The first unit argument should setup any inputs to the the binding, if
      necessary, and the second calls the binding itself.
      Accordingly, the first unit argument will only be applied once in a
      'setup' stage, and the result of that call will be called repeatedly to
      exercise the binding.
  *)
  val exercise : unit -> unit -> t
end

let exercises : (module S) list ref = ref []

let register_one x = exercises := x :: !exercises

let register l = List.iter l ~f:register_one

(* Attempt to exercise various different GC scenarios by randomly creating
   and removing arrays filled with the return value of our test function. *)
let run_simple_exercise name count =
  let (module Exercise) =
    List.find_exn !exercises ~f:(fun (module Exercise) ->
        String.equal name Exercise.name )
  in
  let outer_array = Array.init 100 ~f:(fun _ -> None) in
  let state = Splittable_random.State.of_int 13 in
  let allocated_count = ref 0 in
  (* Setup *)
  let exercise = Exercise.exercise () in
  let subcount_ = count / 20 in
  let start_time = Time.now () in
  let rec do_exercise state i count subcount =
    let subcount =
      if subcount = 0 then (
        let now = Time.now () in
        Format.printf "%s: %i iterations remaining after %s@."
          (Time.to_string_iso8601_basic ~zone:Time.Zone.utc now)
          count
          (Time.Span.to_string_hum (Time.diff now start_time)) ;
        subcount_ )
      else subcount
    in
    let state = Splittable_random.State.split state in
    let length = Splittable_random.int state ~lo:3 ~hi:30 in
    let new_array =
      Array.init length ~f:(fun _ ->
          incr allocated_count ;
          Some (exercise ()) )
    in
    let overwrite = Splittable_random.bool state in
    if overwrite then outer_array.(i) <- Some new_array ;
    let i = if i = 99 then 0 else i + 1 in
    let count = count - 1 in
    let subcount = subcount - 1 in
    if count > 0 then do_exercise state i count subcount else ()
  in
  do_exercise state 0 count subcount_ ;
  let now = Time.now () in
  Format.printf
    "%s: Exercised %s for %i iterations in %s. Did %i allocations.@."
    (Time.to_string_iso8601_basic ~zone:Time.Zone.utc now)
    name count
    (Time.Span.to_string_hum (Time.diff now start_time))
    !allocated_count

let get_names () =
  List.map !exercises ~f:(fun (module Exercise) -> Exercise.name)

(** Run as a CLI tool.
    Accepts arguments [name] and [count], corresponding to the name of a
    registered binding and the number of iterations to run respectively.
    Providing any other number of arguments lists the names of the available
    tests registered by [register]/[register_one].

    A log message is printed each time ~5% of the iterations have been
    completed, to give some indication of the progress.
*)
let run () =
  let argc = Array.length Sys.argv in
  if argc <> 3 then
    let open Format in
    printf "%a@."
      (pp_print_list ~pp_sep:pp_print_newline pp_print_string)
      (get_names ())
  else
    let name = Sys.argv.(1) in
    let count = int_of_string Sys.argv.(2) in
    Format.printf "Running %s for %i iterations@." name count ;
    run_simple_exercise name count
