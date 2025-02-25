open Async_kernel

(* TODO: *new* convert into an extension *)
type t = { worker : Worker.t; buffer : Diff_buffer.t }

let buffer t = Diff_buffer.Rev_dyn_array.to_list t.buffer.diff_array

(* NB: the persistent frontier must remain open as
 * long as the synchronization is using it *)
let create ~constraint_constants ~logger ~time_controller ~db
    ~dequeue_snarked_ledger =
  let worker = Worker.create { db; logger; dequeue_snarked_ledger } in
  let buffer =
    Diff_buffer.create ~constraint_constants ~time_controller ~worker
  in
  { worker; buffer }

let close t =
  let%bind () = Diff_buffer.close_and_finish_copy t.buffer in
  Worker.close t.worker

let notify t ~diffs = Diff_buffer.write t.buffer ~diffs
