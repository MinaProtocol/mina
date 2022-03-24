open Core_kernel
open Async
module Execution_timer = Execution_timer
module Plugins = Plugins
module Thread = Thread

(* TODO: this should probably go somewhere else (mina_cli_entrypoint or coda_run) *)
let () = Plugins.enable_plugin (module Execution_timer)

let on_job_enter' (fiber : Thread.Fiber.t) =
  Plugins.dispatch (fun (module Plugin : Plugins.Plugin_intf) ->
      Plugin.on_job_enter fiber)

let on_job_exit' fiber elapsed_time =
  Plugins.dispatch (fun (module Plugin : Plugins.Plugin_intf) ->
      Plugin.on_job_exit fiber elapsed_time)

let on_job_enter ctx =
  Option.iter (Thread.Fiber.of_context ctx) ~f:on_job_enter'

let on_job_exit ctx elapsed_time =
  Option.iter (Thread.Fiber.of_context ctx) ~f:(fun thread ->
      on_job_exit' thread elapsed_time)

let current_sync_fiber = ref None

(* grabs the parent fiber, returning the fiber (if available) and a reset function to call after exiting the child fiber *)
let grab_parent_fiber () =
  let ctx = Scheduler.current_execution_context () in
  match !current_sync_fiber with
  | None ->
      Execution_context.find_local ctx Thread.Fiber.ctx_id
  | Some fiber ->
      current_sync_fiber := None ;
      Some fiber

(* look through a fiber stack to find a recursive fiber call *)
let rec find_recursive_fiber thread_name parent_thread_name
    (fiber : Thread.Fiber.t) =
  let thread_matches = String.equal fiber.thread.name thread_name in
  let parent_thread_matches =
    Option.equal String.equal
      (Option.map fiber.parent ~f:(fun p -> p.thread.name))
      parent_thread_name
  in
  if thread_matches && parent_thread_matches then Some fiber
  else
    Option.bind fiber.parent
      ~f:(find_recursive_fiber thread_name parent_thread_name)

let exec_thread ~exec_same_thread ~exec_new_thread name =
  let sync_fiber = !current_sync_fiber in
  let parent = grab_parent_fiber () in
  let parent_name = Option.map parent ~f:(fun p -> p.thread.name) in
  let result =
    if
      Option.value_map parent ~default:false ~f:(fun p ->
          String.equal p.thread.name name)
    then exec_same_thread ()
    else
      let fiber =
        match Option.bind parent ~f:(find_recursive_fiber name parent_name) with
        | Some fiber ->
            fiber
        | None ->
            Thread.Fiber.register name parent
      in
      exec_new_thread fiber
  in
  current_sync_fiber := sync_fiber ;
  result

let thread name f =
  exec_thread name ~exec_same_thread:f ~exec_new_thread:(fun fiber ->
      let ctx = Scheduler.current_execution_context () in
      let ctx = Thread.Fiber.apply_to_context fiber ctx in
      match Scheduler.within_context ctx f with
      | Error () ->
          failwithf
            "timing task `%s` failed, exception reported to parent monitor" name
            ()
      | Ok x ->
          x)

let background_thread name f = don't_wait_for (thread name f)

(* it is unsafe to call into the scheduler directly within a `sync_thread` *)
let sync_thread name f =
  exec_thread name ~exec_same_thread:f ~exec_new_thread:(fun fiber ->
      current_sync_fiber := Some fiber ;
      on_job_enter' fiber ;
      let start_time = Time_ns.now () in
      let result = f () in
      let elapsed_time = Time_ns.abs_diff (Time_ns.now ()) start_time in
      on_job_exit' fiber elapsed_time ;
      result)

let () = Stdlib.(Async_kernel.Tracing.fns := { on_job_enter; on_job_exit })

(*
let () =
  Scheduler.Expert.set_on_end_of_cycle (fun () ->
    Option.iter (Thread.current_thread ()) ~f:(fun thread ->
      dispatch_plugins thread (fun (module Plugin) state -> Plugin.on_cycle_end thread.name state)) ;
    (* this line should probably live inside Async_kernel *)
    sch.cycle_started <- true)
*)

let%test_module "thread tests" =
  ( module struct
    let child_of n =
      match
        let prev_sync_fiber = !current_sync_fiber in
        let%bind.Option fiber = grab_parent_fiber () in
        current_sync_fiber := prev_sync_fiber ;
        fiber.parent
      with
      | Some parent ->
          String.equal parent.thread.name n
      | None ->
          false

    let test' f =
      Hashtbl.clear Thread.threads ;
      Thread_safe.block_on_async_exn (fun () ->
          let s = Ivar.create () in
          f (Ivar.fill s) ;
          let%bind () = Ivar.read s in
          Writer.(flushed (Lazy.force stdout)))

    let test f = test' (fun s -> don't_wait_for (f s))

    let%test_unit "thread > thread > thread" =
      test (fun stop ->
          thread "a" (fun () ->
              thread "b" (fun () ->
                  assert (child_of "a") ;
                  thread "c" (fun () ->
                      assert (child_of "b") ;
                      stop () ;
                      Deferred.unit))))

    let%test_unit "thread > background_thread > thread" =
      test (fun stop ->
          thread "a" (fun () ->
              background_thread "b" (fun () ->
                  assert (child_of "a") ;
                  thread "c" (fun () ->
                      assert (child_of "b") ;
                      stop () ;
                      Deferred.unit)) ;
              Deferred.unit))

    let%test_unit "thread > sync_thread" =
      test (fun stop ->
          thread "a" (fun () ->
              sync_thread "b" (fun () ->
                  assert (child_of "a") ;
                  stop ()) ;
              Deferred.unit))

    let%test_unit "sync_thread > sync_thread" =
      test' (fun stop ->
          sync_thread "a" (fun () ->
              sync_thread "b" (fun () ->
                  assert (child_of "a") ;
                  stop ())))

    let%test_unit "sync_thread > background_thread" =
      test (fun stop ->
          sync_thread "a" (fun () ->
              background_thread "b" (fun () ->
                  assert (child_of "a") ;
                  stop () ;
                  Deferred.unit)) ;
          Deferred.unit)

    let%test_unit "sync_thread > background_thread" =
      test' (fun stop ->
          sync_thread "a" (fun () ->
              background_thread "b" (fun () ->
                  assert (child_of "a") ;
                  stop () ;
                  Deferred.unit)))

    let%test_unit "sync_thread > background_thread > sync_thread > thread" =
      test' (fun stop ->
          sync_thread "a" (fun () ->
              background_thread "b" (fun () ->
                  assert (child_of "a") ;
                  sync_thread "c" (fun () ->
                      assert (child_of "b") ;
                      don't_wait_for
                        (thread "d" (fun () ->
                             assert (child_of "c") ;
                             stop () ;
                             Deferred.unit))) ;
                  Deferred.unit)))

    (* TODO: recursion tests *)
  end )
