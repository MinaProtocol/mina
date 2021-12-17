open Async_kernel

module type S = Intf.S

module No_trace = struct
  let measure _ f = f ()

  let trace _ f = f ()

  let trace_event _ = ()

  let trace_recurring = trace

  let trace_task _ f = don't_wait_for (f ())

  let trace_recurring_task = trace_task

  let forget_tid f = f ()
end

let implementation = ref (module No_trace : S)

let set_implementation x = implementation := x

let measure name f =
  let (module M) = !implementation in
  M.measure name f

let trace_event name =
  let (module M) = !implementation in
  M.trace_event name

let trace name f =
  let (module M) = !implementation in
  M.trace name f

let trace_recurring name f =
  let (module M) = !implementation in
  M.trace_recurring name f

let trace_recurring_task name f =
  let (module M) = !implementation in
  M.trace_recurring_task name f

let trace_task name f =
  let (module M) = !implementation in
  M.trace_task name f

let forget_tid f =
  let (module M) = !implementation in
  M.forget_tid f
