open Async_kernel

(* TODO: *new* convert into an extension *)

module Make (Inputs : Intf.Inputs_with_db_intf) = struct
  module Worker = Worker.Make (Inputs)
  module Diff_buffer = Diff_buffer.Make (struct
    include Inputs
    module Worker = Worker
  end)

  type t =
    { worker: Worker.t
    ; buffer: Diff_buffer.t }

  (* NB: the persistent frontier must remain open as
   * long as the synchronization is using it *)
  let create ~logger ~base_hash ~db =
    let worker = Worker.create {db; logger} in
    let buffer = Diff_buffer.create ~base_hash ~worker in
    {worker; buffer}

  let close t =
    let%bind () = Diff_buffer.close_and_finish_copy t.buffer in
    Worker.close t.worker

  let notify t ~diffs ~hash_transition =
    Diff_buffer.write t.buffer ~diffs ~hash_transition
end
