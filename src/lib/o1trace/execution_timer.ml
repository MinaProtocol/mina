open Core_kernel

module T =
  Plugins.Register_plugin
    (struct
      type state = Time_ns.Span.t ref [@@deriving sexp_of]

      let name = "Execution_timer"

      let init_state _thread_name = ref Time_ns.Span.zero
    end)
    ()

include T

let rec record_elapsed_time (fiber : Thread.Fiber.t) elapsed_time =
  let state = Plugins.plugin_state (module T) fiber.thread in
  (state := Time_ns.Span.(!state + elapsed_time)) ;
  match fiber.parent with
  | None ->
      ()
  | Some parent ->
      record_elapsed_time parent elapsed_time

let on_job_enter _fiber = ()

let on_job_exit fiber elapsed_time = record_elapsed_time fiber elapsed_time

let elapsed_time_of_thread thread = !(Plugins.plugin_state (module T) thread)
