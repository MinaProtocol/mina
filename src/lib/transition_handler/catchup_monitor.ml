open Core_kernel
open Pipe_lib.Strict_pipe
open With_hash
open Coda_base

module Make (Inputs : Inputs.S) = struct
  open Inputs
  open Consensus.Mechanism

  type t =
    { catchup_job_writer:
        ( (External_transition.t, State_hash.t) With_hash.t
        , drop_head buffered
        , unit )
        Closed_writer.t
    ; timeouts:
        (State_hash.t, unit Time.Timeout.t) List.Assoc.t State_hash.Table.t }

  let create ~catchup_job_writer =
    {catchup_job_writer; timeouts= State_hash.Table.create ()}

  let watch t ~logger ~time_controller ~timeout_duration ~transition =
    let logger = Logger.child logger "catchup_monitor" in
    let hash = With_hash.hash transition in
    let parent_hash =
      With_hash.data transition |> External_transition.protocol_state
      |> Protocol_state.previous_state_hash
    in
    let make_timeout () =
      Time.Timeout.create time_controller timeout_duration ~f:(fun _ ->
          Closed_writer.write t.catchup_job_writer transition )
    in
    Hashtbl.update t.timeouts parent_hash ~f:(function
      | None -> [(hash, make_timeout ())]
      | Some entries ->
          if List.Assoc.mem entries hash ~equal:State_hash.equal then (
            Logger.info logger
              !"Received request to watch transition for catchup that already \
                was being watched: %{sexp: State_hash.t}"
              hash ;
            entries )
          else (hash, make_timeout ()) :: entries )

  (* TODO: write invalidated transitions back into processor *)
  let notify t ~transition ~time_controller =
    let open Option.Let_syntax in
    ignore
      (let%map entries = Hashtbl.find t.timeouts transition.hash in
       List.iter entries ~f:(fun (_, timeout) ->
           Time.Timeout.cancel time_controller timeout () ))
end
