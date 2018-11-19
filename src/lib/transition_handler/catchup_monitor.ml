open Core_kernel

module Make (Inputs : Inputs.S) = struct
  open Inputs

  type t =
    { catchup_job_writer: External_transition.t Linear_pipe.Writer.t
    ; timeouts: unit Time.Timeout.t State_hash.Table.t }

  let create ~catchup_job_writer =
    {catchup_job_writer; timeouts= State_hash.Table.create ()}

  let watch t transition =
    let timeout = Time.Timeout.create timeout_duration ~f:(fun () ->
        Linear_pipe.write catchup_job_writer transition)
    in
    Hashtbl.add t.timeouts ~key:(parent_state_hash transition) ~data:timeout

  let notify t transition =
    ignore (
      let%map timeout = Hashtbl.find_opt t.timeouts (state_hash transition) in
      Time.Timeout.cancel timeout ())
end
