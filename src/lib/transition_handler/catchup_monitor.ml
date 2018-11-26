open Core_kernel
open Pipe_lib.Strict_pipe
open With_hash
module State_hash = Coda_base.State_hash

module Make (Inputs : Inputs.S) = struct
  open Inputs
  open Consensus_mechanism

  type t =
    { catchup_job_writer: (External_transition.t, drop_head buffered, unit) Writer.t
    ; timeouts: unit Time.Timeout.t State_hash.Table.t }

  let create ~catchup_job_writer =
    {catchup_job_writer; timeouts= State_hash.Table.create ()}

  let parent_state_hash t =
    External_transition.protocol_state t
    |> Protocol_state.previous_state_hash

  let watch t ~transition ~time_controller ~timeout_duration =
    let timeout = Time.Timeout.create time_controller timeout_duration ~f:(fun _ ->
        Writer.write t.catchup_job_writer transition)
    in
    Hashtbl.add t.timeouts ~key:(parent_state_hash transition.data) ~data:timeout

  let notify t ~transition ~time_controller =
    let open Option.Let_syntax in
    ignore (
      let%map timeout = Hashtbl.find t.timeouts transition.hash in
      Time.Timeout.cancel time_controller timeout ())
end
