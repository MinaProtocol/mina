open Core
open Async
open Protocols.Coda_transition_frontier
open Pipe_lib
open Coda_base

module Make (Inputs : Inputs.S) :
  Catchup_intf
  with type external_transition := Inputs.External_transition.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t
   and type state_hash := State_hash.t
   and type network := Inputs.Network.t = struct
  open Inputs
  module Worker = Catchup_worker.Make (Inputs)

  let construct_breadcrumb_path ~logger initial_staged_ledger
      external_transitions =
    let open Or_error.Let_syntax in
    let%map _, breadcrumbs =
      List.fold_result external_transitions ~init:(initial_staged_ledger, [])
        ~f:(fun (staged_ledger, acc) transition_with_hash ->
          let external_transition = With_hash.data transition_with_hash in
          let diff =
            External_transition.staged_ledger_diff external_transition
          in
          let%map _, _, `Updated_staged_ledger staged_ledger =
            Staged_ledger.apply ~logger staged_ledger diff
          in
          let new_breadcrumb =
            Transition_frontier.Breadcrumb.create transition_with_hash
              staged_ledger
          in
          (staged_ledger, new_breadcrumb :: acc) )
    in
    List.rev breadcrumbs

  let materilize_breadcrumbs ~frontier ~logger = function
    | [] -> `Success []
    | root_transition :: _ as external_transitions -> (
        let initial_state_hash =
          With_hash.data root_transition
          |> External_transition.protocol_state
          |> External_transition.Protocol_state.previous_state_hash
        in
        match Transition_frontier.find frontier initial_state_hash with
        | None -> `No_matching_root_hash initial_state_hash
        | Some initial_breadcrumb -> (
            let initial_staged_ledger =
              Transition_frontier.Breadcrumb.staged_ledger initial_breadcrumb
            in
            match
              construct_breadcrumb_path ~logger initial_staged_ledger
                external_transitions
            with
            | Ok result -> `Success result
            | Error e -> `Error e ) )

  let choose_first_success (list : 'a option Deferred.t list) :
      'a option Deferred.t =
    let first_success = Ivar.create () in
    List.iter list ~f:(fun x ->
        Deferred.upon x (Option.iter ~f:(Ivar.fill first_success)) ) ;
    Deferred.any
      [ Ivar.read first_success >>| Option.some
      ; Deferred.all list >>| Fn.const None ]

  let get_transitions_from_peers ~logger ~peers hash =
    List.map peers ~f:(fun peer ->
        match%map Catchup_worker.dispatch Worker.Worker_rpc.rpc hash peer with
        | Ok result -> result
        | Error e ->
            Logger.info logger
              !"Connection error with peer %{sexp: Host_and_port.t}: %s"
              peer (Error.to_string_hum e) ;
            None )

  let run ~logger ~network ~frontier ~catchup_job_reader
      ~catchup_breadcrumbs_writer =
    Strict_pipe.Reader.iter catchup_job_reader ~f:(fun transition_with_hash ->
        let hash = With_hash.hash transition_with_hash in
        (* TODO: pass in peers as paramet
        er *)
        let peers =
          Network.peers network |> List.map ~f:Kademlia.Peer.external_rpc
        in
        let breadcrumbs =
          List.map
            (List.zip_exn peers
               (get_transitions_from_peers ~logger ~peers hash))
            ~f:(fun (peer, transitions_deferred) ->
              let open Deferred.Option.Let_syntax in
              let%bind transitions = transitions_deferred in
              Deferred.return
              @@
              match materilize_breadcrumbs ~frontier ~logger transitions with
              | `No_matching_root_hash initial_state_hash ->
                  Logger.info logger
                    !"Could not find initial hash: %{sexp:State_hash.t}."
                    initial_state_hash ;
                  None
              | `Error e ->
                  Logger.faulty_peer logger
                    !"Recieved invalid transitions from bad peer \
                      %{sexp:Host_and_port.t}: %{sexp:Error.t}"
                    peer e ;
                  None
              | `Success result -> Some result )
        in
        match%map choose_first_success breadcrumbs with
        | Some response ->
            Strict_pipe.Writer.write catchup_breadcrumbs_writer response
        | None ->
            Logger.info logger
              !"None of the peers have a transition with state hash \
                %{sexp:State_hash.t}"
              hash )
    |> don't_wait_for ;
    (* TODO: server_port should be passdown as a parameter  *)
    let server_port = 9999 in
    Worker.setup_server ~frontier ~logger server_port
    |> Deferred.ignore |> don't_wait_for
end
