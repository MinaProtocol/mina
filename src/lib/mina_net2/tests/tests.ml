open Core
open Async
open Mina_net2

let%test_module "coda network tests" =
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
          ~conf_dir:a_tmp ~pids
        >>| Or_error.ok_exn
      in
      let%bind b =
        create ~all_peers_seen_metric:false
          ~logger:(Logger.extend logger [ ("name", `String "b") ])
          ~conf_dir:b_tmp ~pids
        >>| Or_error.ok_exn
      in
      let%bind c =
        create ~all_peers_seen_metric:false
          ~logger:(Logger.extend logger [ ("name", `String "c") ])
          ~conf_dir:c_tmp ~pids
        >>| Or_error.ok_exn
      in
      let%bind kp_a = generate_random_keypair a in
      let%bind kp_b = generate_random_keypair b in
      let%bind kp_c = generate_random_keypair c in
      let maddrs = List.map [ "/ip4/127.0.0.1/tcp/0" ] ~f:Multiaddr.of_string in
      let%bind () =
        configure a ~logger ~external_maddr:(List.hd_exn maddrs) ~me:kp_a
          ~maddrs ~network_id ~peer_exchange:true ~mina_peer_exchange:true
          ~direct_peers:[] ~seed_peers:[] ~on_peer_connected:Fn.ignore
          ~on_peer_disconnected:Fn.ignore ~flooding:false ~metrics_port:None
          ~unsafe_no_trust_ip:true ~max_connections:50
          ~validation_queue_size:150
          ~initial_gating_config:
            { trusted_peers = []; banned_peers = []; isolate = false }
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
        configure b ~logger ~external_maddr:(List.hd_exn maddrs) ~me:kp_b
          ~maddrs ~network_id ~peer_exchange:true ~mina_peer_exchange:true
          ~direct_peers:[] ~seed_peers:[ seed_peer ]
          ~on_peer_connected:Fn.ignore ~on_peer_disconnected:Fn.ignore
          ~flooding:false ~metrics_port:None ~unsafe_no_trust_ip:true
          ~max_connections:50 ~validation_queue_size:150
          ~initial_gating_config:
            { trusted_peers = []; banned_peers = []; isolate = false }
        >>| Or_error.ok_exn
      and () =
        configure c ~logger ~external_maddr:(List.hd_exn maddrs) ~me:kp_c
          ~maddrs ~network_id ~peer_exchange:true ~mina_peer_exchange:true
          ~direct_peers:[] ~seed_peers:[ seed_peer ]
          ~on_peer_connected:Fn.ignore ~on_peer_disconnected:Fn.ignore
          ~flooding:false ~metrics_port:None ~unsafe_no_trust_ip:true
          ~max_connections:50 ~validation_queue_size:150
          ~initial_gating_config:
            { trusted_peers = []; banned_peers = []; isolate = false }
        >>| Or_error.ok_exn
      in
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

    (*
    let%test_unit "does_b_see_c" =
      let () = Core.Backtrace.elide := false in
      ignore testmsg ;
      let test_def =
        let open Deferred.Let_syntax in
        let%bind b, c, shutdown = setup_two_nodes "test_stream" in
        let%bind b_peers = peers b in
        let%bind c_peerid = me c >>| Keypair.to_peer_id in
        assert (
          b_peers
          |> List.map ~f:(fun p -> p.Peer.peer_id)
          |> fun l -> List.mem l c_peerid ~equal:Peer.Id.equal ) ;
        let%bind c_peers = peers c in
        let%bind b_peerid = me b >>| Keypair.to_peer_id in
        assert (
          c_peers
          |> List.map ~f:(fun p -> p.Peer.peer_id)
          |> fun l -> List.mem l b_peerid ~equal:Peer.Id.equal ) ;
        shutdown ()
      in
      Async.Thread_safe.block_on_async_exn (fun () -> test_def)

    let%test_unit "b_stream_c" =
      let () = Core.Backtrace.elide := false in
      ignore testmsg ;
      let test_def =
        let open Deferred.Let_syntax in
        let%bind b, c, shutdown = setup_two_nodes "test_stream" in
        let%bind b_peerid = me b >>| Keypair.to_peer_id in
        let handler_finished = ref false in
        let%bind _echo_handler =
          handle_protocol b ~on_handler_error:`Raise ~protocol:"read_bytes"
            (fun stream ->
              let r, w = Stream.pipes stream in
              let rec go i =
                if i = 0 then return ()
                else
                  let%bind _s =
                    match%map Pipe.read' ~max_queue_length:1 r with
                    | `Eof ->
                        failwith "Eof"
                    | `Ok q ->
                        Base.Queue.peek_exn q
                  in
                  go (i - 1)
              in
              let%map () = go 1000 in
              Pipe.write_without_pushback w "done" ;
              Pipe.close w ;
              handler_finished := true )
          |> Deferred.Or_error.ok_exn
        in
        let%bind stream =
          open_stream c ~protocol:"read_bytes" b_peerid >>| Or_error.ok_exn
        in
        let r, w = Stream.pipes stream in
        for i = 0 to 999 do
          Pipe.write_without_pushback w (Printf.sprintf "%d" i)
        done ;
        Pipe.close w ;
        (* HACK: let our messages send before we reset.
           It would be more principled to add flushing to
           the stream interface. *)
        let%bind () = after (Time.Span.of_sec 5.) in
        let%bind _ = Stream.reset stream in
        let%bind _msgs = Pipe.read_all r in
        assert !handler_finished ;
        shutdown ()
      in
      Async.Thread_safe.block_on_async_exn (fun () -> test_def)
  *)

    let%test_unit "stream" =
      let () = Core.Backtrace.elide := false in
      let test_def =
        let open Deferred.Let_syntax in
        let%bind b, c, shutdown = setup_two_nodes "test_stream" in
        let%bind b_peerid = me b >>| Keypair.to_peer_id in
        let handler_finished = ref false in
        let%bind () =
          open_protocol b ~on_handler_error:`Raise ~protocol:"echo"
            (fun stream ->
              let r, w = Libp2p_stream.pipes stream in
              let%map () = Pipe.transfer r w ~f:Fn.id in
              Pipe.close w ;
              handler_finished := true)
          |> Deferred.Or_error.ok_exn
        in
        let%bind stream =
          open_stream c ~protocol:"echo" b_peerid >>| Or_error.ok_exn
        in
        let r, w = Libp2p_stream.pipes stream in
        Pipe.write_without_pushback w testmsg ;
        Pipe.close w ;
        (* HACK: let our messages send before we reset.
           It would be more principled to add flushing to
           the stream interface. *)
        let%bind () = after (Time.Span.of_sec 1.) in
        let%bind () = reset_stream c stream >>| Or_error.ok_exn in
        let%bind msg = Pipe.read_all r in
        (* give time for [a] to notice the reset finish. *)
        let%bind () = after (Time.Span.of_sec 1.) in
        let msg = Queue.to_list msg |> String.concat in
        assert (String.equal msg testmsg) ;
        assert !handler_finished ;
        let%bind () = close_protocol b ~protocol:"echo" in
        let%map () = shutdown () in
        ()
      in
      Async.Thread_safe.block_on_async_exn (fun () -> test_def)

    (* NOTE: these tests are not relevant in the current libp2p setup
             due to how validation is implemented (see #4796)

       let unwrap_eof = function
       | `Eof ->
          failwith "unexpected EOF"
       | `Ok a ->
          Envelope.Incoming.data a

       module type Pubsub_config = sig
       type msg [@@deriving equal, compare, sexp, bin_io]

       val subscribe :
        net -> string -> msg Pubsub.Subscription.t Deferred.Or_error.t

       val a_sent : msg

       val b_sent : msg
       end

       let make_pubsub_test name (module M : Pubsub_config) =
       let open Deferred.Let_syntax in
       let%bind a, b, shutdown = setup_two_nodes ("test_pubsub_" ^ name) in
       let%bind a_sub = M.subscribe a "test" |> Deferred.Or_error.ok_exn in
       let%bind b_sub = M.subscribe b "test" |> Deferred.Or_error.ok_exn in
       let%bind a_peers = peers a in
       let%bind b_peers = peers b in
       [%log fatal] "a peers = $apeers, b peers = $bpeers"
        ~metadata:
          [ ("apeers", `List (List.map ~f:Peer.to_yojson a_peers))
          ; ("bpeers", `List (List.map ~f:Peer.to_yojson b_peers)) ] ;
       let a_r = Pubsub.Subscription.message_pipe a_sub in
       let b_r = Pubsub.Subscription.message_pipe b_sub in
       (* Give the subscriptions time to propagate *)
       let%bind () = after (sec 2.) in
       let%bind () = Pubsub.Subscription.publish a_sub M.a_sent in
       (* Give the publish time to propagate *)
       let%bind () = after (sec 2.) in
       let%bind a_recv = Strict_pipe.Reader.read a_r in
       let%bind b_recv = Strict_pipe.Reader.read b_r in
       [%test_eq: M.msg] M.a_sent (unwrap_eof a_recv) ;
       [%test_eq: M.msg] M.a_sent (unwrap_eof b_recv) ;
       let%bind () = Pubsub.Subscription.publish b_sub M.b_sent in
       let%bind () = after (sec 2.) in
       let%bind a_recv = Strict_pipe.Reader.read a_r in
       let%bind b_recv = Strict_pipe.Reader.read b_r in
       [%test_eq: M.msg] M.b_sent (unwrap_eof a_recv) ;
       [%test_eq: M.msg] M.b_sent (unwrap_eof b_recv) ;
       shutdown ()

       let should_forward_message _ = return true

       let%test_unit "pubsub_raw" =
       let test_def =
        make_pubsub_test "raw"
          ( module struct
            type msg = string [@@deriving equal, compare, sexp, bin_io]

            let subscribe net topic =
              Pubsub.subscribe ~should_forward_message net topic

            let a_sent = "msg from a"

            let b_sent = "msg from b"
          end )
       in
       Async.Thread_safe.block_on_async_exn (fun () -> test_def)

       let%test_unit "pubsub_bin_prot" =
       let test_def =
        make_pubsub_test "bin_prot"
          ( module struct
            type msg = {a: int; b: string option}
            [@@deriving bin_io, equal, sexp, compare]

            let subscribe net topic =
              Pubsub.subscribe_encode ~should_forward_message ~bin_prot:bin_msg
                ~on_decode_failure:`Ignore net topic

            let a_sent = {a= 0; b= None}

            let b_sent = {a= 1; b= Some "foo"}
          end )
       in
       Async.Thread_safe.block_on_async_exn (fun () -> test_def)
    *)
  end )
