open! Core
open! Async
open Votie_rpcs

(*
let registrar_connection () =
  let%bind 
  Tcp.with_connection
    (Tcp.Where_to_connect.of_host_and_port
        { port=daemon_port; host = "0.0.0.0" } 
    )
    ~timeout:(Time.Span.of_sec 10.)
    (fun _ r w ->
      let open Deferred.Let_syntax in
      match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
      | Error exn ->
          exitf !"Error connecting to daemon on port %d: %s."
            daemon_port
            (Exn.to_string exn)
      | Ok conn ->
        match%bind
          Rpc.Rpc.dispatch rpc conn query
        with
        | Error e ->
          exitf "Got error from daemon: %s" (Core.Error.to_string_hum e)
        | Ok resp -> 
          print_response resp;
          exit 0 ) )
*)

let connect host_and_port =
  Tcp.with_connection (Tcp.Where_to_connect.of_host_and_port host_and_port)
    ~timeout:(Time.Span.of_sec 10.) (fun _ r w ->
      Deferred.map
        (Rpc.Connection.create r w ~connection_state:(fun _ -> ()))
        ~f:(Result.map_error ~f:Error.of_exn) )

let elections_state conn =
  let rec loop create_or_set_state k =
    let%bind c = Persistent_connection.Rpc.connected conn in
    match%bind
      Deferred.map (Rpc.State_rpc.dispatch Votes.rpc c ()) ~f:Or_error.join
    with
    | Error e ->
        eprintf "Error obtaining votes from the registrar: %s\nRetrying.\n"
          (Error.to_string_hum e) ;
        let%bind () = after (sec 10.) in
        loop create_or_set_state k
    | Ok (s, r, _metadata) ->
        let open Votie_lib in
        let state = create_or_set_state s in
        let iteration_finished =
          Pipe.iter r ~f:(fun u ->
              ( match Elections_state.add_vote !state u with
              | Ok s ->
                  state := s
              | Error e ->
                  eprintf
                    !"Got bad vote from the registrar: %{sexp:Error.t}\n"
                    e ) ;
              Deferred.unit )
        in
        k state
          (Deferred.any [iteration_finished; Rpc.Connection.close_finished c])
  in
  let%map state, go_again = loop ref (fun s i -> return (s, i)) in
  let rec keep_going d =
    let%bind () = d in
    let%bind next =
      loop
        (fun s ->
          state := s ;
          state )
        (fun _ d -> return d)
    in
    keep_going next
  in
  don't_wait_for (keep_going go_again) ;
  state

let dispatch_registrar conn rpc query =
  let%bind c = Persistent_connection.Rpc.connected conn in
  Rpc.Rpc.dispatch rpc c query

let create_daemon_server conn state =
  let log_error = `Call (fun _ e -> eprintf "%s\n" (Exn.to_string e)) in
  let open Votie_lib in
  let open Voter_lib in
  let open Rpc in
  let implementations =
    Implementations.create_exn
      ~implementations:
        [ Rpc.implement Rpcs.Elections_status.rpc (fun () () ->
              return (Elections_state.elections !state) )
        ; Rpc.implement Rpcs.Vote.rpc (fun () {election; witness; vote} ->
              let elections =
                List.filter
                  (Map.keys (Elections_state.elections !state))
                  ~f:(fun desc -> desc.description = election)
              in
              let submit election_description =
                let ballot =
                  Votie_lib.Statement.vote_proof
                    ~proving_key:
                      ((* TODO: Pretty *)
                       Universe.Crypto.Run.Keypair.pk
                         (Elections_state.config !state).keypair)
                    witness election_description vote
                in
                dispatch_registrar conn Votie_rpcs.Submit_vote.rpc ballot
                >>| Or_error.join
              in
              match elections with
              | [e] ->
                  submit e
              | _ :: _ :: _ ->
                  Deferred.Or_error.error_string
                    "Mulitple matching elections found. Not submiting vote."
              | [] ->
                  Core.printf "No such election found. Creating election.\n" ;
                  submit {description= election; timestamp= Time.now ()} ) ]
      ~on_unknown_rpc:`Raise
  in
  let open Tcp in
  Server.create
    (Where_to_listen.bind_to Bind_to_address.Localhost
       (Bind_to_port.On_port Voter_lib.daemon.port))
    ~on_handler_error:log_error (fun _ reader writer ->
      Connection.server_with_close reader writer ~implementations
        ~connection_state:(fun _ -> ())
        ~on_handshake_error:
          (`Call
            (fun e ->
              eprintf "bad handshake: %s\n" (Exn.to_string e) ;
              Deferred.unit )) )

let main () =
  let log =
    Log.create ~level:`Debug ~output:[Log.Output.stderr ()]
      ~on_error:(`Call (fun e -> eprintf "%s\n%!" (Error.to_string_hum e)))
  in
  let conn =
    Persistent_connection.Rpc.create ~server_name:"registrar" ~log ~connect
      (fun () -> Deferred.Or_error.return Votie_rpcs.registrar)
  in
  let%bind state = elections_state conn in
  let%bind _ = create_daemon_server conn state in
  never ()

let () =
  Command.async (Command.Param.return main) ~summary:"voter daemon"
  |> Command.run
