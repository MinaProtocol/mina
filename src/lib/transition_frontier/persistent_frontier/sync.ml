open Async_kernel

(* TODO: *new* convert into an extension *)
type t = {worker: Worker.t; mailbox: Diff_mailbox.t}

(* NB: the persistent frontier must remain open as
 * long as the synchronization is using it *)
let create ~logger ~time_controller ~base_hash ~db =
  let worker = Worker.create {db; logger} in
  let mailbox = Diff_mailbox.create ~base_hash ~time_controller ~worker in
  {worker; mailbox}

let close t =
  let%bind () = Diff_mailbox.close_gracefully t.mailbox in
  Worker.close t.worker

let notify t ~diffs ~hash_transition =
  Diff_mailbox.send t.mailbox (diffs, hash_transition)
