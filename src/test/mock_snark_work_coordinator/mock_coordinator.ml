open Async
open Core

open struct
  module Work = Snark_work_lib
end

let proof_cache_db = Proof_cache_tag.create_identity_db ()

(* NOTE:
   The code here is adapt from Mina_lib & Mina_run.
*)
let start ~sok_message
    ~(predefined_specs : Work.Spec.Single.Stable.Latest.t One_or_two.t Queue.t)
    ~partitioner ~logger ~port ~rpc_handshake_timeout ~rpc_heartbeat_send_every
    ~rpc_heartbeat_timeout ~completed_snark_work_sink =
  [%log info] "Starting mock snark work coordinator"
    ~metadata:[ ("port", `Int port) ] ;
  let work_from_selector () =
    let%map.Option spec = Queue.dequeue predefined_specs in
    let spec =
      One_or_two.map
        ~f:(Snark_work_lib.Spec.Single.write_all_proofs_to_disk ~proof_cache_db)
        spec
    in
    let id = One_or_two.map ~f:Work.Spec.Single.Poly.statement spec in
    let work_ids_json = id |> Transaction_snark_work.Statement.compact_json in
    [%log info] "Selector work distributed to partitioner"
      ~metadata:[ ("work_ids", work_ids_json) ] ;
    spec
  in

  let implement rpc f =
    Rpc.Rpc.implement rpc (fun () input ->
        O1trace.thread ("serve_" ^ Rpc.Rpc.name rpc) (fun () -> f () input) )
  in

  let snark_worker_rpcs_coordinator =
    [ implement Snark_worker.Rpcs.Get_work.Stable.Latest.rpc (fun () `V3 ->
          match
            Work_partitioner.request_partitioned_work ~sok_message ~partitioner
              ~work_from_selector:(lazy (work_from_selector ()))
          with
          | None ->
              Deferred.return None
          | Some (Ok spec) ->
              [%log trace]
                ~metadata:
                  [ ( "work_spec"
                    , Work.Spec.Partitioned.Stable.Latest.to_yojson spec )
                  ]
                "responding to a Get_work request with some new work" ;
              Deferred.return (Some spec)
          | Some (Error e) ->
              [%log error] "Mina_lib.request_work failed"
                ~metadata:[ ("error", `String (Error.to_string_hum e)) ] ;
              Mina_metrics.(Counter.inc_one Snark_work.snark_work_assigned_rpc) ;
              None |> Deferred.return )
    ; implement Snark_worker.Rpcs.Submit_work.Stable.Latest.rpc
        (fun () result ->
          [%log trace] "received completed work from a snark worker"
            ~metadata:
              [ ( "result"
                , Snark_work_lib.Result.Partitioned.Stable.Latest.to_yojson
                    result )
              ] ;
          match
            Work_partitioner.submit_partitioned_work ~result ~partitioner
          with
          | SpecUnmatched ->
              Deferred.return `SpecUnmatched
          | Removed ->
              Deferred.return `Removed
          | Processed None ->
              Deferred.return `Ok
          | Processed (Some combined) ->
              Pipe_lib.Strict_pipe.Writer.write completed_snark_work_sink
                combined ;
              Deferred.return `Ok )
    ]
  in
  let where_to_listen =
    Tcp.Where_to_listen.bind_to All_addresses (On_port port)
  in

  Deferred.ignore_m
    (Tcp.Server.create
       ~on_handler_error:
         (`Call
           (fun _net exn ->
             [%log error] "Exception while handling TCP server request: $error"
               ~metadata:
                 [ ("error", `String (Exn.to_string_mach exn))
                 ; ("context", `String "rpc_tcp_server")
                 ] ) )
       where_to_listen
       (fun address reader writer ->
         let address = Socket.Address.Inet.addr address in
         Rpc.Connection.server_with_close
           ~handshake_timeout:(Time.Span.of_sec rpc_handshake_timeout)
           ~heartbeat_config:
             (Rpc.Connection.Heartbeat_config.create
                ~timeout:(Time_ns.Span.of_sec rpc_heartbeat_timeout)
                ~send_every:(Time_ns.Span.of_sec rpc_heartbeat_send_every)
                () )
           reader writer
           ~implementations:
             (Rpc.Implementations.create_exn
                ~implementations:snark_worker_rpcs_coordinator
                ~on_unknown_rpc:`Raise )
           ~connection_state:ignore
           ~on_handshake_error:
             (`Call
               (fun exn ->
                 [%log warn]
                   "Handshake error while handling RPC server request from \
                    $address"
                   ~metadata:
                     [ ("error", `String (Exn.to_string_mach exn))
                     ; ("context", `String "rpc_server")
                     ; ("address", `String (Unix.Inet_addr.to_string address))
                     ] ;
                 Deferred.unit ) ) ) )
