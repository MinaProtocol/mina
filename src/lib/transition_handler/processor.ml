open Protocols.Coda_pow

module Make (Inputs : Inputs_intf.S) : Transaction_handler_processor_intf = struct
  open Inputs

  (* TODO: implement drop old *)
  let run ~logger ~valid_transition_reader ~catchup_job_writer ~catchup_breadcrumbs_reader frontier =
    let logger = Logger.parent logger "Transition_handler.Catchup" in
    let catchup_monitor = Catchup_monitor.create ~catchup_job_writer in
    let reader = Linear_pipe.Priority_reader.create catchup_transitions_reader valid_transition_reader in
    
    Linear_pipe.iter reader ~f:(function
    | `Catchup_transitions [] -> Logger.error logger "read empty catchup transitions"
    | `Catchup_transitions ((root_breadcrumb :: _) as breadcrumbs) ->
        (match Transition_frontier.lookup frontier (breadcrumb_parent_hash root_breadcrumb) with
        | None ->
            Logger.error logger "read catchup transitions which did not fit into frontier"
        | Some parent ->
            List.fold breadcrumbs ~init:parent ~f(fun parent breadcrumb -> 
                Transition_frontier.add frontier ~parent ~breadcrumb))
    | `Valid_transition transition ->
        (match Transition_frontier.lookup frontier (transition_parent_hash transition) with
        | None ->
            Catchup_monitor.watch catchup_monitor transition  
        | Some parent ->
            let breadcrumb = Transition_frontier.Breadcrumb.create frontier ~parent ~transition in
            Transition_frontier.add frontier ~parent ~breadcrumb;
            Catchup_monitor.notify catchup_monitor transition))
end
