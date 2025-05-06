open Async
open Core
module Work = Snark_work_lib

module Seen_key = struct
  type t = Transaction_snark.Statement.t One_or_two.t
  [@@deriving compare, sexp, to_yojson, hash]
end

let mock_coordinator ~partitioner ~snark_work_fee ~key ~logger ~seed ~port
    ~rpc_handshake_timeout ~rpc_heartbeat_send_every ~rpc_heartbeat_timeout =
  let selector_work_pool : (Seen_key.t, Time.t) Hashtbl_intf.Hashtbl.t =
    Hashtbl.create (module Seen_key)
  in
  let selection_method : (module Work_selector.Selection_method_intf) =
    ( module struct
      module State = Work_selector.State

      let work ~snark_pool:_ ~fee:_ ~logger _state =
        let gen = One_or_two.gen (Work.Selector.Single.Spec.gen ()) in
        let spec = Quickcheck.random_value ~seed gen in
        let key = One_or_two.map ~f:Work.Work.Single.Spec.statement spec in
        Hashtbl.add_exn selector_work_pool ~key ~data:(Time.now ()) ;
        let work_ids_json =
          key |> Transaction_snark_work.Statement.compact_json
        in
        [%log info] "Selector work distributed"
          ~metadata:[ ("work_ids", work_ids_json) ] ;
        Some spec
    end )
  in
  let pipe_r, _ = Pipe_lib.Broadcast_pipe.create None in
  let selector =
    Work_selector.State.init ~logger ~reassignment_wait:9999999999
      ~frontier_broadcast_pipe:pipe_r
  in
  let implement rpc f =
    Rpc.Rpc.implement rpc (fun () input ->
        O1trace.thread ("serve_" ^ Rpc.Rpc.name rpc) (fun () -> f () input) )
  in

  let snark_pool = failwith "TODO" in
  let snark_worker_rpcs_coordinator =
    [ implement Snark_worker.Rpcs.Get_work.Stable.Latest.rpc
        (fun () capability ->
          (let%map.Option work =
             Mina_lib.request_work ~capability ~selection_method ~snark_work_fee
               ~logger ~selector ~snark_pool ~partitioner
           in
           let work_wire =
             Work.Partitioned.Spec.read_all_proofs_from_disk work
           in

           [%log trace]
             ~metadata:
               [ ( "work_spec"
                 , Work.Partitioned.Spec.Stable.Latest.to_yojson work_wire )
               ]
             "responding to a Get_work request with some new work" ;
           (work_wire, key) )
          |> Deferred.return )
    ; implement Snark_worker.Rpcs.Submit_work.Stable.Latest.rpc
        (fun () wire_result ->
          [%log trace] "received completed work from a snark worker"
            ~metadata:
              [ ( "work_spec"
                , Work.Partitioned.(
                    wire_result |> Result.Poly.to_spec
                    |> Spec.Stable.Latest.to_yojson) )
              ] ;
          let proof_cache_db = Proof_cache_tag.create_identity_db () in
          let result : Work.Partitioned.Result.t =
            Work.Partitioned.Result.write_all_proofs_to_disk ~proof_cache_db
              wire_result
          in
          let callback (result : Work.Selector.Result.t) =
            let key =
              One_or_two.map ~f:Work.Work.Single.Spec.statement
                result.spec.instances
            in
            let work_ids_json =
              key |> Transaction_snark_work.Statement.compact_json
            in
            let distributed =
              Hashtbl.find_and_remove selector_work_pool key
              |> Option.value_exn
                   ~message:
                     "Partitioner trying to submit non-existent selector work \
                      result"
            in
            let elapsed_json =
              `Float Time.(diff (now ()) distributed |> Span.to_sec)
            in
            [%log info] "Selector work combined by partitioner"
              ~metadata:
                [ ("work_ids", work_ids_json); ("elapsed", elapsed_json) ] ;
            failwith "TODO: verify the result is valid"
          in
          Work_partitioner.submit_partitioned_work ~result ~callback
            ~partitioner
          |> Deferred.return )
    ]
  in
  let where_to_listen =
    Tcp.Where_to_listen.bind_to All_addresses (On_port port)
  in

  O1trace.background_thread "serve_client_rpcs" (fun () ->
      Deferred.ignore_m
        (Tcp.Server.create
           ~on_handler_error:
             (`Call
               (fun _net exn ->
                 [%log error]
                   "Exception while handling TCP server request: $error"
                   ~metadata:
                     [ ("error", `String (Exn.to_string_mach exn))
                     ; ("context", `String "rpc_tcp_server")
                     ] ) )
           where_to_listen
           (fun address reader writer ->
             let address = Socket.Address.Inet.addr address in
             Rpc.Connection.server_with_close
               ~handshake_timeout:rpc_handshake_timeout
               ~heartbeat_config:
                 (Rpc.Connection.Heartbeat_config.create
                    ~timeout:
                      (Time_ns.Span.of_sec
                         (Time.Span.to_sec rpc_heartbeat_timeout) )
                    ~send_every:
                      (Time_ns.Span.of_sec
                         (Time.Span.to_sec rpc_heartbeat_send_every) )
                    () )
               reader writer
               ~implementations:
                 (Rpc.Implementations.create_exn
                    ~implementations:snark_worker_rpcs_coordinator
                    ~on_unknown_rpc:`Raise )
               ~connection_state:(fun _ -> ())
               ~on_handshake_error:
                 (`Call
                   (fun exn ->
                     [%log warn]
                       "Handshake error while handling RPC server request from \
                        $address"
                       ~metadata:
                         [ ("error", `String (Exn.to_string_mach exn))
                         ; ("context", `String "rpc_server")
                         ; ( "address"
                           , `String (Unix.Inet_addr.to_string address) )
                         ] ;
                     Deferred.unit ) ) ) ) )
