(* Accumulates the best tip history from mina-best-tip.log files. It gets all the states from the log files passed and generates a rose tree *)

open Core
open Async
open Coda_base

module Node = struct
  module T = struct
    type t =
      { state: Transition_frontier.Extensions.Best_tip_diff.Log_event.t
      ; peer_ids: String.Set.t }
    [@@deriving sexp, compare]
  end

  include T
  include Comparable.Make (T)
end

module Input = struct
  (*all_states: hash table of a parent block and a map of it's successors
   * roots: all the nodes for which there is no block for the parent node
   * peers: set of peers whose logs were processed
   * seen_state_hashes: map of states that were obtained from the logs. Used to keep the roots updated*)
  type t =
    { all_states: (State_hash.t, Node.t State_hash.Map.t) Hashtbl.t
    ; roots: (State_hash.t, Node.t) Hashtbl.t
          (*generate from seen state hashes later on*)
    ; peers: String.Set.t
    ; seen_state_hashes: State_hash.Set.t }

  type added_transitions =
    Transition_frontier.Extensions.Best_tip_diff.Log_event.t list
  [@@deriving yojson]

  let of_logs ~logger ~log_file t =
    [%log info] "Processing log file: %s" log_file ;
    let log_lines = In_channel.read_lines log_file in
    let res =
      List.fold ~init:t log_lines ~f:(fun acc line ->
          match Logger.Message.of_yojson (Yojson.Safe.from_string line) with
          | Ok msg -> (
              let tf_event_id =
                Option.map msg.event_id ~f:(fun e ->
                    Structured_log_events.equal_id e
                      Transition_frontier.Extensions.Best_tip_diff.Log_event
                      .new_best_tip_event_structured_events_id )
              in
              match tf_event_id with
              | Some true ->
                  (*This is a Best_tip_diff log*)
                  let peer_id =
                    match Map.find_exn msg.metadata "peer_id" with
                    | `String p ->
                        p
                    | _ ->
                        failwith "Expected `String for peer_id"
                  in
                  let peers = Set.add acc.peers peer_id in
                  let added_transitions =
                    Map.find_exn msg.metadata "added_transitions"
                    |> added_transitions_of_yojson |> Result.ok_or_failwith
                  in
                  let acc' =
                    List.fold ~init:acc added_transitions ~f:(fun acc'' tr ->
                        let new_node =
                          { Node.state= tr
                          ; peer_ids= String.Set.singleton peer_id }
                        in
                        let parent_hash =
                          Coda_state.Protocol_state.previous_state_hash
                            tr.protocol_state
                        in
                        let new_state_hash = tr.state_hash in
                        let seen_state_hashes =
                          let seen_state_hashes =
                            Set.add acc''.seen_state_hashes new_state_hash
                          in
                          if Set.mem acc''.seen_state_hashes parent_hash |> not
                          then
                            (*Assuming the logs are in order, if the parent hash was not already seen then it is the root*)
                            Hashtbl.update t.roots new_state_hash ~f:(function
                              | None ->
                                  new_node
                              | Some node ->
                                  { state= node.state
                                  ; peer_ids= Set.add node.peer_ids peer_id } ) ;
                          seen_state_hashes
                        in
                        Hashtbl.update t.all_states parent_hash ~f:(function
                          | None ->
                              State_hash.Map.singleton new_state_hash new_node
                          | Some map -> (
                            match Map.find map new_state_hash with
                            | None ->
                                Map.add_exn map ~key:new_state_hash
                                  ~data:new_node
                            | Some {state; peer_ids} ->
                                Map.set map ~key:new_state_hash
                                  ~data:
                                    {state; peer_ids= Set.add peer_ids peer_id}
                            ) ) ;
                        {acc'' with seen_state_hashes} )
                  in
                  (* remove any previous roots for which there are ancestors now*)
                  List.iter (Hashtbl.keys acc'.roots) ~f:(fun root ->
                      let state = Hashtbl.find_exn acc'.roots root in
                      let parent =
                        state.state.protocol_state.previous_state_hash
                      in
                      if State_hash.Set.mem acc'.seen_state_hashes parent then
                        (* no longer a root because a node for it's parent was seen*)
                        Hashtbl.remove acc'.roots root ) ;
                  {acc' with peers}
              | None | Some false ->
                  [%log error] "Could not process log line $line"
                    ~metadata:[("line", `String line)] ;
                  (*skipping any other logs*) acc )
          | Error err ->
              [%log error] "Could not process log line $line: $error"
                ~metadata:[("line", `String line); ("error", `String err)] ;
              acc )
    in
    [%log info] "Finished processing log file: %s" log_file ;
    res
end

module Output = struct
  type t = Node.t Rose_tree.t list

  let of_input (input : Input.t) : t =
    List.fold ~init:[] (Hashtbl.data input.roots)
      ~f:(fun acc_trees root_state ->
        let rec go (node : Node.t) =
          let successors =
            Option.value ~default:State_hash.Map.empty
              (Hashtbl.find input.all_states node.state.state_hash)
            |> Map.data
          in
          List.map successors ~f:(fun s ->
              Rose_tree.T ({Node.state= s.state; peer_ids= s.peer_ids}, go s)
          )
        in
        Rose_tree.T
          ( {Node.state= root_state.state; peer_ids= root_state.peer_ids}
          , go root_state )
        :: acc_trees )
end

module type Display_intf = sig
  type t [@@deriving yojson]

  val of_output : Output.t -> t
end

module Display : Display_intf = struct
  type node =
    { state: Transition_frontier.Extensions.Best_tip_diff.Log_event.t
    ; peers: int }
  [@@deriving yojson]

  type t = node Rose_tree.t list [@@deriving yojson]

  let of_output : Output.t -> t =
   fun t ->
    List.map t ~f:(fun tree ->
        Rose_tree.map tree ~f:(fun (t : Node.t) ->
            {state= t.state; peers= Set.length t.peer_ids} ) )
end

module Compact_display : Display_intf = struct
  type state =
    { current: State_hash.t
    ; parent: State_hash.t
    ; blockchain_length: Coda_numbers.Length.t
    ; global_slot: Coda_numbers.Global_slot.t }
  [@@deriving yojson]

  type node = {state: state; peers: int} [@@deriving yojson]

  type t = node Rose_tree.t list [@@deriving yojson]

  let of_output t =
    List.map t ~f:(fun tree ->
        Rose_tree.map tree ~f:(fun (t : Node.t) ->
            let state : state =
              { current= t.state.state_hash
              ; parent= t.state.protocol_state.previous_state_hash
              ; blockchain_length=
                  Coda_state.Protocol_state.consensus_state
                    t.state.protocol_state
                  |> Consensus.Data.Consensus_state.blockchain_length
              ; global_slot=
                  Coda_state.Protocol_state.consensus_state
                    t.state.protocol_state
                  |> Consensus.Data.Consensus_state.curr_global_slot }
            in
            {state; peers= Set.length t.peer_ids} ) )
end

let main ~input_dir ~output_file ~log_dir ~output_format () =
  let%map files =
    Sys.ls_dir input_dir
    >>| List.filter_map ~f:(fun n ->
            if Filename.check_suffix n ".log" then Some (input_dir ^/ n)
            else None )
  in
  let t : Input.t =
    { Input.all_states= Hashtbl.create (module State_hash)
    ; peers= String.Set.empty
    ; roots= Hashtbl.create (module State_hash)
    ; seen_state_hashes= State_hash.Set.empty }
  in
  let logrotate_max_size = 1024 * 1024 * 1 in
  Logger.Consumer_registry.register ~id:"default"
    ~processor:(Logger.Processor.raw ())
    ~transport:
      (Logger.Transport.File_system.dumb_logrotate ~directory:log_dir
         ~log_filename:"mina-history-accumulator.log"
         ~max_size:logrotate_max_size) ;
  let logger = Logger.create () in
  let t' =
    List.fold ~init:t files ~f:(fun t log_file ->
        Input.of_logs ~logger ~log_file t )
  in
  [%log info] "Accumulating the history.." ;
  let output = Output.of_input t' in
  [%log info] "Generated the resulting rose tree" ;
  let (module D : Display_intf) =
    match output_format with
    | Some "Full" ->
        (module Display)
    | Some "Compact" | _ ->
        (module Compact_display)
  in
  [%log info] "Writing the result (format: %s) to %s"
    (Option.value ~default:"Compact" output_format)
    output_file ;
  Yojson.Safe.to_file output_file D.(to_yojson @@ of_output output) ;
  ()

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async
        ~summary:"Accumulates best tip history from multiple log files"
        (let%map input_dir =
           Param.flag "--input-dir"
             ~doc:
               "PATH Directory containing one or more mina-best-tip.log files"
             Param.(required string)
         and output_file =
           Param.flag "--output-file"
             ~doc:
               "File File containing the accumulated history in a rose tree \
                representation"
             Param.(required string)
         and log_dir =
           Param.flag "--log-dir"
             ~doc:
               "Path Directory where the accumulator's log file can be saved"
             Param.(required string)
         and output_format =
           Param.flag "--output-format"
             ~doc:
               "Full|Compact Information shown for each block. Full= Protocol \
                state and Compact= Current state hash, previous state hash, \
                blockchain length, and global slot. Default: Compact"
             Param.(optional string)
         in
         main ~input_dir ~output_file ~log_dir ~output_format)))
