open Core
open Async
open Mina_net2

(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs

let%test_module "Mina network tests" =
  ( module struct
    let logger = Logger.create ()

    let testmsg =
      "This is a test. This is a test of the Outdoor Warning System. This is \
       only a test."

    let pids = Child_processes.Termination.create_pid_table ()

    let setup_two_nodes network_id =
      let%bind a_tmp = Unix.mkdtemp "p2p_helper_test_a" in
      let%bind b_tmp = Unix.mkdtemp "p2p_helper_test_b" in
      let%bind c_tmp = Unix.mkdtemp "p2p_helper_test_c" in
      let%bind a =
        create ~all_peers_seen_metric:false
          ~logger:(Logger.extend logger [ ("name", `String "a") ])
          ~conf_dir:a_tmp ~pids ~on_peer_connected:Fn.ignore
          ~on_peer_disconnected:Fn.ignore
        >>| Or_error.ok_exn
      in
      let%bind b =
        create ~all_peers_seen_metric:false
          ~logger:(Logger.extend logger [ ("name", `String "b") ])
          ~conf_dir:b_tmp ~pids ~on_peer_connected:Fn.ignore
          ~on_peer_disconnected:Fn.ignore
        >>| Or_error.ok_exn
      in
      let%bind c =
        create ~all_peers_seen_metric:false
          ~logger:(Logger.extend logger [ ("name", `String "c") ])
          ~conf_dir:c_tmp ~pids ~on_peer_connected:Fn.ignore
          ~on_peer_disconnected:Fn.ignore
        >>| Or_error.ok_exn
      in
      let%bind kp_a = generate_random_keypair a in
      let%bind kp_b = generate_random_keypair b in
      let%bind kp_c = generate_random_keypair c in
      let maddrs = List.map [ "/ip4/127.0.0.1/tcp/0" ] ~f:Multiaddr.of_string in
      let%bind () =
        configure a ~external_maddr:(List.hd_exn maddrs) ~me:kp_a ~maddrs
          ~network_id ~peer_exchange:true ~peer_protection_ratio:0.2
          ~direct_peers:[] ~seed_peers:[] ~flooding:false ~metrics_port:None
          ~unsafe_no_trust_ip:true ~max_connections:50 ~min_connections:20
          ~validation_queue_size:150
          ~initial_gating_config:
            { trusted_peers = []; banned_peers = []; isolate = false }
          ~known_private_ip_nets:[] ~topic_config:[]
        >>| Or_error.ok_exn
      in
      let%bind raw_seed_peers = listening_addrs a >>| Or_error.ok_exn in
      let seed_peer =
        Printf.sprintf "%s/p2p/%s"
          (Multiaddr.to_string @@ List.hd_exn raw_seed_peers)
          (Keypair.to_peer_id kp_a)
        |> Multiaddr.of_string
      in
      [%log error]
        ~metadata:[ ("peer", `String (Multiaddr.to_string seed_peer)) ]
        "Seed_peer: $peer" ;
      let%bind () =
        configure b ~external_maddr:(List.hd_exn maddrs) ~me:kp_b ~maddrs
          ~network_id ~peer_exchange:true ~peer_protection_ratio:0.2
          ~direct_peers:[] ~seed_peers:[ seed_peer ] ~flooding:false
          ~min_connections:20 ~metrics_port:None ~unsafe_no_trust_ip:true
          ~max_connections:50 ~validation_queue_size:150
          ~initial_gating_config:
            { trusted_peers = []; banned_peers = []; isolate = false }
          ~known_private_ip_nets:[] ~topic_config:[]
        >>| Or_error.ok_exn
      and () =
        configure c ~external_maddr:(List.hd_exn maddrs) ~me:kp_c ~maddrs
          ~network_id ~peer_exchange:true ~peer_protection_ratio:0.2
          ~direct_peers:[] ~seed_peers:[ seed_peer ] ~flooding:false
          ~metrics_port:None ~unsafe_no_trust_ip:true ~max_connections:50
          ~min_connections:20 ~validation_queue_size:150
          ~initial_gating_config:
            { trusted_peers = []; banned_peers = []; isolate = false }
          ~known_private_ip_nets:[] ~topic_config:[]
        >>| Or_error.ok_exn
      in
      let%bind () = after (Time.Span.of_sec 10.) in
      let%bind b_advert = begin_advertising b in
      Or_error.ok_exn b_advert ;
      let%bind c_advert = begin_advertising c in
      Or_error.ok_exn c_advert ;
      (* Give the helpers time to announce and discover each other on localhost *)
      let%map () = after (Time.Span.of_sec 2.5) in
      let shutdown () =
        let%bind () = shutdown a in
        let%bind () = shutdown b in
        let%bind () = shutdown c in
        let%bind () = File_system.remove_dir a_tmp in
        let%bind () = File_system.remove_dir b_tmp in
        File_system.remove_dir c_tmp
      in
      (b, c, shutdown)

    (* TODO fails occasionally, uncomment after debugging it *)
    let%test_unit "b_stream_c" =
      let () = Core.Backtrace.elide := false in
      let test_def () =
        let open Deferred.Let_syntax in
        let%bind b, c, shutdown = setup_two_nodes "test_stream" in
        let%bind b_peerid = me b >>| Keypair.to_peer_id in
        let handler_finished = Ivar.create () in
        let%bind () =
          open_protocol b ~on_handler_error:`Raise ~protocol:"read_bytes"
            (fun stream ->
              let r, w = Libp2p_stream.pipes stream in
              let rec go i =
                if i = 0 then return ()
                else
                  let%bind s =
                    match%map Pipe.read' ~max_queue_length:1 r with
                    | `Eof ->
                        failwith "Eof"
                    | `Ok q ->
                        Base.Queue.peek_exn q
                  in
                  let s' = ref s in
                  let j = ref i in
                  while not (String.is_empty !s') do
                    let t = Printf.sprintf "%d" !j in
                    if String.is_prefix ~prefix:t !s' then (
                      s' := String.drop_prefix !s' (String.length t) ;
                      j := !j - 1 )
                    else
                      failwith
                        (Printf.sprintf "Unexpected string %s not matches %d" s
                           !j )
                  done ;
                  go !j
              in
              go 1000
              >>| fun () ->
              Pipe.close w ;
              Ivar.fill handler_finished () )
          >>| Or_error.ok_exn
        in
        let%bind stream =
          open_stream c ~protocol:"read_bytes" ~peer:b_peerid
          >>| Or_error.ok_exn
        in
        let r, w = Libp2p_stream.pipes stream in
        let rec go2 i =
          if i = 0 then return ()
          else Pipe.write w (Printf.sprintf "%d" i) >>= fun () -> go2 (i - 1)
        in
        let%bind () = go2 1000 in
        Pipe.close w ;
        let%bind () = Ivar.read handler_finished in
        let%bind () = reset_stream c stream >>| Or_error.ok_exn in
        let%bind _msgs = Pipe.read_all r in
        shutdown ()
      in
      Async.Thread_safe.block_on_async_exn test_def

    let%test_unit "stream" =
      let () = Core.Backtrace.elide := false in
      let test_def () =
        let open Deferred.Let_syntax in
        let%bind b, c, shutdown = setup_two_nodes "test_stream" in
        let%bind b_peerid = me b >>| Keypair.to_peer_id in
        let handler_finished = Ivar.create () in
        let%bind () =
          open_protocol b ~on_handler_error:`Raise ~protocol:"echo"
            (fun stream ->
              let r, w = Libp2p_stream.pipes stream in
              let%map () = Pipe.transfer r w ~f:Fn.id in
              Pipe.close w ;
              Ivar.fill_if_empty handler_finished () )
          |> Deferred.Or_error.ok_exn
        in
        let%bind stream =
          open_stream c ~protocol:"echo" ~peer:b_peerid >>| Or_error.ok_exn
        in
        let r, w = Libp2p_stream.pipes stream in
        Pipe.write_without_pushback w testmsg ;
        Pipe.close w ;
        (* HACK: let our messages send before we reset.
           It would be more principled to add synchronization. *)
        let%bind () = after (Time.Span.of_sec 1.) in
        let%bind () = reset_stream c stream >>| Or_error.ok_exn in
        let%bind msg = Pipe.read_all r in
        let msg = Queue.to_list msg |> String.concat in
        assert (String.equal msg testmsg) ;
        let%bind () = Ivar.read handler_finished in
        let%bind () = close_protocol b ~protocol:"echo" in
        shutdown ()
      in
      Async.Thread_safe.block_on_async_exn test_def
  end )
