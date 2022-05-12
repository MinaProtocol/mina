(* Test all IPCs.
   This test executes a simulation with 3 nodes: Alice, Bob and Carol.

   Topology of the network:
       * Yota <--> Alice
       * Yota <--> Bob
       * Yota <--> Carol
       * Alice <--> Bob
       * Alice <--> Carol

   Additional libp2p helper Yota is launched to correctly setup routing on
   Alice and Bob. Yota performs no active actions. Note, that there is no connection
   between Bob and Carol (this is implemented by banning Carol's peer id in configuration
   of Bob).

   Each node runs its own sequence of actions. Some actions have an effect of
   synchronizing nodes (see comments in the code).

   All upcalls and RPC request/response pairs are tested this way. *)

open Core
open Async
open Mina_net2

(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs

type status = NotMet | Connected | Disconnected [@@deriving sexp]

type typed_msg = { a : int; b : string option }
[@@deriving bin_io_unversioned, equal, sexp, compare]

exception UnexpectedPeerConnectionStatus of string * bool * string

exception UnexpectedEof of string

exception UnexpectedState

exception UnexpectedGossipSender of string * string

let nonEof msg a = match a with `Ok r -> r | _ -> raise (UnexpectedEof msg)

let expectEof m = match m with `Eof -> () | _ -> raise UnexpectedState

let random_msg () =
  let sz = 32 + Random.int 1024 in
  String.init sz ~f:(fun _ -> Random.char ())

exception Timeout of string

let or_timeout ?(timeout = 60) ~msg action =
  Deferred.(
    (* HACK yield to facilitate scheduler to switch between processes
       This shouldn't be necessary, but is required for test not to stall. *)
    after (Time.Span.of_ms 100.)
    >>= fun () ->
    choose
      [ choice action Fn.id
      ; choice
          (after (Time.Span.of_int_sec timeout))
          (fun () -> Timeout msg |> raise)
      ])

let%test_module "all-ipc test" =
  ( module struct
    let logger = Logger.create ()

    let pids = Child_processes.Termination.create_pid_table ()

    let network_id = "test_network"

    let protocol = "test/1"

    let topic_a = "topic/a"

    let topic_c = "topic/c"

    let bob_status =
      "This is major Tom to ground control\nI'm stepping through the door"

    type messages =
      { topic_a_msg_1 : string
      ; topic_a_msg_2 : string
      ; topic_a_msg_3 : string
      ; topic_c_msg_1 : typed_msg
      ; topic_c_msg_2 : typed_msg
      ; stream_1_msg_1 : string
      ; stream_1_msg_2 : string
      ; stream_2_msg_1 : string
      }

    let check_msg (env : 'a Network_peer.Envelope.Incoming.t) cb has_received
        expected_sender vr =
      assert (not !has_received) ;
      has_received := true ;
      ( match env.sender with
      | Local ->
          raise UnexpectedState
      | Remote p ->
          if not (String.equal p.peer_id expected_sender) then
            raise (UnexpectedGossipSender (expected_sender, p.peer_id)) ) ;
      Validation_callback.fire_if_not_already_fired cb vr

    let mk_banning_gating_config peer_id =
      let fake_peer =
        Network_peer.Peer.create
          (UnixLabels.inet_addr_of_string "8.8.8.8")
          ~libp2p_port:9999 ~peer_id
      in
      { trusted_peers = []; banned_peers = [ fake_peer ]; isolate = false }

    type addrs =
      { a_addr : Multiaddr.t
      ; a_peerid : string
      ; b_addr : Multiaddr.t
      ; b_peerid : string
      ; c_addr : Multiaddr.t
      ; c_peerid : string
      ; y_peerid : string
      }

    let rec iteratePcWhile label pc ls ~pred =
      let checkDo (status, expectedPid) pid conn =
        match (!status, conn, String.equal pid expectedPid) with
        | NotMet, true, true ->
            status := Connected ;
            true
        | NotMet, false, true ->
            status := Disconnected ;
            true
        | Connected, true, true ->
            true
        | Disconnected, false, true ->
            true
        | Connected, false, true ->
            status := Disconnected ;
            true
        | _, _, _ ->
            false
      in
      if pred () then Deferred.unit
      else
        Pipe.read pc
        >>= fun r ->
        match r with
        | `Eof ->
            raise (UnexpectedEof label)
        | `Ok (conn, pid) ->
            [%log info]
              (if conn then "Connected $pid" else "Disconnected $pid")
              ~metadata:[ ("pid", `String pid); ("label", `String label) ] ;
            let allFine : bool =
              List.fold ls ~init:false ~f:(fun b p -> b || checkDo p pid conn)
            in
            if not allFine then
              raise (UnexpectedPeerConnectionStatus (label, conn, pid)) ;
            iteratePcWhile label pc ~pred ls

    let alice a ad (pc, _) msgs =
      let bobStatus = ref NotMet in
      let carolStatus = ref NotMet in
      let yotaStatus = ref NotMet in
      let pcLs =
        [ (bobStatus, ad.b_peerid)
        ; (carolStatus, ad.c_peerid)
        ; (yotaStatus, ad.y_peerid)
        ]
      in
      let pcIter pred = iteratePcWhile "alice" pc pcLs ~pred in
      (* Connect Alice to Bob *)
      let%bind () = add_peer a ad.b_addr ~is_seed:false >>| Or_error.ok_exn in
      (* Await connection from Bob to Alice to succeed *)
      let%bind () =
        pcIter (fun () ->
            match !bobStatus with
            | NotMet ->
                false
            | Connected ->
                true
            | _ ->
                raise UnexpectedState )
        |> or_timeout ~msg:"Alice: connect to Bob"
      in
      (* Get addresses of Alice *)
      let%bind lAddrs = listening_addrs a >>| Or_error.ok_exn in
      assert (List.length lAddrs > 0) ;
      (* Await Carol to connect *)
      (* This is done mainly to test PeerConnected upcall *)
      let%bind () =
        pcIter (fun () ->
            match !carolStatus with
            | NotMet ->
                false
            | Connected ->
                true
            | _ ->
                raise UnexpectedState )
        |> or_timeout ~msg:"Alice: wait for Carol to connect"
      in
      (* Subscribe to topic "c" *)
      let topic_c_received_1 = ref false in
      let topic_c_received_2 = ref false in
      let topic_c_received_ivar = Ivar.create () in
      let%bind _ =
        Pubsub.subscribe_encode a topic_c
          ~on_decode_failure:(`Call (fun _ _ -> raise UnexpectedState))
          ~bin_prot:bin_typed_msg
          ~handle_and_validate_incoming_message:(fun env cb ->
            Deferred.return
              ( if equal_typed_msg env.data msgs.topic_c_msg_1 then
                  check_msg env cb topic_c_received_1 ad.b_peerid `Accept
                else if equal_typed_msg env.data msgs.topic_c_msg_2 then
                  check_msg env cb topic_c_received_2 ad.b_peerid `Accept
                else raise UnexpectedState ;
                if !topic_c_received_1 && !topic_c_received_2 then
                  Ivar.fill_if_empty topic_c_received_ivar () ) )
      in
      (* Subscribe to topic "a" *)
      let topic_a_received_1 = ref false in
      let topic_a_received_2 = ref false in
      let topic_a_received_3 = ref false in
      let topic_a_received_ivar = Ivar.create () in
      let%bind _ =
        Pubsub.subscribe a topic_a
          ~handle_and_validate_incoming_message:(fun env cb ->
            Deferred.return
              ( if String.equal env.data msgs.topic_a_msg_1 then
                  check_msg env cb topic_a_received_1 ad.c_peerid `Accept
                else if String.equal env.data msgs.topic_a_msg_2 then
                  check_msg env cb topic_a_received_2 ad.c_peerid `Reject
                else if String.equal env.data msgs.topic_a_msg_3 then
                  check_msg env cb topic_a_received_3 ad.b_peerid `Accept
                else raise UnexpectedState ;
                if
                  !topic_a_received_1 && !topic_a_received_2
                  && !topic_a_received_3
                then Ivar.fill_if_empty topic_a_received_ivar () ) )
        >>| Or_error.ok_exn
      in
      (* Open stream 1 to Bob *)
      (* By opening the stream Alice notifies Bob that she has subscribed to
         topics "a", "c" and Bob can start publishing *)
      let%bind stream1 =
        open_stream a ~protocol ~peer:ad.b_peerid >>| Or_error.ok_exn
      in
      let stream1_in, stream1_out = Libp2p_stream.pipes stream1 in

      (* Await message 1 on stream 1 *)
      (* This way Bob notifies Alice that he has subscribed to topic "a"
         and set his node status *)
      let%bind s1m1 =
        Pipe.read stream1_in >>| nonEof "stream 1 / msg 1"
        |> or_timeout ~msg:"Receive message 1 on stream 1"
      in
      assert (String.equal s1m1 msgs.stream_1_msg_1) ;

      (* Get bob's node status *)
      let%bind status_b =
        get_peer_node_status a ad.b_addr >>| Or_error.ok_exn
      in
      assert (String.equal status_b bob_status) ;

      (* Open stream 2 to Carol *)
      (* By opening the stream Alice notifies Carol that both Alice and Bob
         have subscribed to topic "a" and Carol can start publishing *)
      let%bind stream2 =
        open_stream a ~protocol ~peer:ad.c_peerid >>| Or_error.ok_exn
      in
      let stream2_in, _ = Libp2p_stream.pipes stream2 in

      (* Read message on stream 2: upon receiving the message
         we know that Carol stopped publishing on topic "a" and is no longer
         accepting new streams *)
      let%bind s2m1 =
        Pipe.read stream2_in >>| nonEof "stream 2 / msg 1"
        |> or_timeout ~msg:"Receive message 1 on stream 2"
      in
      assert (String.equal s2m1 msgs.stream_2_msg_1) ;

      (* Test stream opening to Carol: protocol is closed on Carol,
         hence stream is not to be opened or to be reset immediately. *)
      let%bind () =
        open_stream a ~protocol ~peer:ad.c_peerid
        >>= (fun stream3_res ->
              match stream3_res with
              | Ok s ->
                  let s_in, _ = Libp2p_stream.pipes s in
                  Pipe.read s_in >>| expectEof
              | _ ->
                  Deferred.unit )
        |> or_timeout ~msg:"Stream 3 opening to fail"
      in

      (* Wait for all messages on topic "c" to be received *)
      let%bind () =
        Ivar.read topic_c_received_ivar
        |> or_timeout ~msg:"Alice: all messages on topic C received"
      in
      (* Wait for all messages on topic "a" to be received *)
      let%bind () =
        Ivar.read topic_a_received_ivar
        |> or_timeout ~msg:"Alice: all messages on topic A received"
      in

      (* Send message 2 on stream 1. This way we signal to Bob that he
         can safely close.
         This message may be removed in future after implementing the proper
         stream closing. *)
      let%bind () =
        Pipe.write stream1_out msgs.stream_1_msg_2
        |> or_timeout ~msg:"Send message 2 on stream 1"
      in

      (* TODO replace the statement above with the line below *)
      (* Pipe.close stream1_out ; *)

      (* Reset stream 2: signal Carol that she can proceed to the last step
         (waiting for Alice to disconnect) *)
      let%bind () = reset_stream a stream2 >>| Or_error.ok_exn in

      (* List peers of Alice *)
      let%bind peers = peers a in
      assert (List.length peers >= 2) ;
      assert (
        List.fold [ ad.y_peerid; ad.b_peerid; ad.c_peerid ] ~init:true
          ~f:(fun b_acc pid ->
            b_acc
            && List.fold peers ~init:false ~f:(fun acc p ->
                   acc || String.equal p.peer_id pid ) ) ) ;

      (* Ban Carol in Alice's gating config *)
      let%bind _ =
        set_connection_gating_config a (mk_banning_gating_config ad.c_peerid)
      in

      (* Wait for Carol to disconnect. This will deadlock Alice and Carol
         unless new gating config is put into effect and Carol becomes banned. *)
      let%bind () =
        pcIter (fun () ->
            match !carolStatus with
            | Connected ->
                false
            | Disconnected ->
                true
            | _ ->
                raise UnexpectedState )
        |> or_timeout ~msg:"Alice: wait for Carol to disconnect"
      in

      (* Await Bob to terminate. This statement ensures that Alice doesn't finishes
         before Bob received all of the messages on topic "a" *)
      pcIter (fun () ->
          match !bobStatus with
          | Disconnected ->
              true
          | Connected ->
              false
          | _ ->
              raise UnexpectedState )
      |> or_timeout ~msg:"Alice: wait for Bob to disconnect"

    let bob b ad (pc, _) msgs =
      let aliceStatus = ref NotMet in
      let yotaStatus = ref NotMet in
      let pcLs = [ (aliceStatus, ad.a_peerid); (yotaStatus, ad.y_peerid) ] in
      let pcIter pred = iteratePcWhile "bob" pc pcLs ~pred in
      (* Setup stream handler *)
      let streams_r, streams_w = Pipe.create () in
      let%bind () =
        open_protocol ~protocol ~on_handler_error:`Raise b (fun stream ->
            Pipe.write streams_w stream )
        >>| Or_error.ok_exn
      in
      (* Await connection to succeed *)
      (* This is done mainly to test PeerConnected upcall *)
      let%bind () =
        pcIter (fun () ->
            match !aliceStatus with
            | NotMet ->
                false
            | Connected ->
                true
            | _ ->
                raise UnexpectedState )
        |> or_timeout ~msg:"Bob: Alice connected"
      in
      (* Set Bob's node status *)
      let%bind () = set_node_status b bob_status >>| Or_error.ok_exn in
      (* Subscribe to topic "a" *)
      let topic_a_received_1 = ref false in
      let topic_a_received_ivar = Ivar.create () in
      let%bind subA =
        Pubsub.subscribe b topic_a
          ~handle_and_validate_incoming_message:(fun env cb ->
            Deferred.return
              ( if String.equal env.data msgs.topic_a_msg_1 then
                  check_msg env cb topic_a_received_1 ad.a_peerid `Accept
                else raise UnexpectedState ;
                Ivar.fill topic_a_received_ivar () ) )
        >>| Or_error.ok_exn
      in
      (* Subscribe to topic "c" *)
      let%bind subC =
        Pubsub.subscribe_encode b topic_c
          ~on_decode_failure:(`Call (fun _ _ -> raise UnexpectedState))
          ~bin_prot:bin_typed_msg
          ~handle_and_validate_incoming_message:(fun _ _ ->
            raise UnexpectedState )
        >>| Or_error.ok_exn
      in
      (* Await for stream1 to open *)
      (* This means that Alice subscribed to topics "a", "c" *)
      let%bind stream1 =
        Pipe.read streams_r
        >>| nonEof "bob / incoming stream 1"
        |> or_timeout ~msg:"Bob: waiting for stream 1"
      in
      let stream1_in, stream1_out = Libp2p_stream.pipes stream1 in
      (* Send message 1 on stream 1 *)
      let%bind () =
        Pipe.write stream1_out msgs.stream_1_msg_1
        |> or_timeout ~msg:"Bob: send message 1 to stream 1"
      in

      (* Publish to topic "a" *)
      let%bind () = Pubsub.publish b subA msgs.topic_a_msg_3 in
      (* Publish to topic "c" *)
      let%bind () = Pubsub.publish b subC msgs.topic_c_msg_1 in
      let%bind () = Pubsub.publish b subC msgs.topic_c_msg_2 in

      (* Await message 2 on stream 1 *)
      let%bind s1m2 =
        Pipe.read stream1_in >>| nonEof "stream 1 / msg 2"
        |> or_timeout ~msg:"Bob: receive message 2 on stream 1"
      in
      assert (String.equal s1m2 msgs.stream_1_msg_2) ;
      (* Unsubscribe from a *)
      let%bind () =
        Ivar.read topic_a_received_ivar
        |> or_timeout ~msg:"Bob: all messages on topic A received"
      in
      (* Expect stream 1 to close *)
      (* TODO uncomment after fixing the issue *)
      (* let%bind () = (Pipe.read stream1_in >>| expectEof)
         |> or_timeout ~msg:"Bob: waiting for stream 1 to close" in *)
      Pubsub.unsubscribe b subA >>| Or_error.ok_exn

    let carol c ad (pc, _) msgs =
      let aliceStatus = ref NotMet in
      let bobStatus = ref NotMet in
      let yotaStatus = ref NotMet in
      let pcLs =
        [ (aliceStatus, ad.a_peerid)
        ; (bobStatus, ad.b_peerid)
        ; (yotaStatus, ad.y_peerid)
        ]
      in
      let pcIter pred = iteratePcWhile "carol" pc pcLs ~pred in
      (* Add stream handler *)
      let streams_r, streams_w = Pipe.create () in
      let%bind () =
        open_protocol ~protocol ~on_handler_error:`Raise c (fun stream ->
            Pipe.write streams_w stream )
        >>| Or_error.ok_exn
      in
      (* Await connection to succeed *)
      (* This is being done mainly to test PeerConnected upcall. *)
      let%bind () =
        pcIter (fun () ->
            match !aliceStatus with
            | NotMet ->
                false
            | Connected ->
                true
            | _ ->
                raise UnexpectedState )
        |> or_timeout ~msg:"Carol: Alice connected"
      in

      (* Alice notifies us that both Alice and Bob subscribed to topic "a" *)
      let%bind stream2 =
        Pipe.read streams_r
        >>| nonEof "carol / incoming stream 2"
        |> or_timeout ~msg:"Carol: wait for stream 2"
      in
      let stream2_in, stream2_out = Libp2p_stream.pipes stream2 in

      (* Publish some messages *)
      let%bind () = Pubsub.publish_raw c ~topic:topic_a msgs.topic_a_msg_1 in
      let%bind () = Pubsub.publish_raw c ~topic:topic_a msgs.topic_a_msg_2 in
      let%bind () =
        Pubsub.publish_raw c ~topic:"topic/b" "not to be received"
      in

      (match !bobStatus with Connected -> raise UnexpectedState | _ -> ()) ;

      (* Remove stream handler for the protocol, further stream
         connections will be rejected *)
      let%bind () = close_protocol c ~protocol in

      (* Notify Alice that publishing on topic "a" is finished and
         protocol is closed *)
      let%bind () =
        Pipe.write stream2_out msgs.stream_2_msg_1
        |> or_timeout ~msg:"Carol: send message 1 on stream 2"
      in

      (* Alice received all of the published messages and closed
         the stream 2 *)
      let%bind () =
        Pipe.read stream2_in >>| expectEof
        |> or_timeout ~msg:"Carol: wait for stream 2 to close"
      in

      (* Await disconnect *)
      (* This will hang until either Carol is banned by Alice
         or until Alice finishes *)
      pcIter (fun () ->
          match !aliceStatus with
          | Disconnected ->
              true
          | Connected ->
              false
          | _ ->
              raise UnexpectedState )
      |> or_timeout ~msg:"Carol: wait for Alice to disconnect"

    let def_gating_config =
      { trusted_peers = []; banned_peers = []; isolate = false }

    let setup_node ?keypair ?(seed_peers = [])
        ?(gating_config = def_gating_config) ?(ignore_advertise_error = false)
        local_name ~on_peer_connected ~on_peer_disconnected =
      let%bind conf_dir =
        Unix.mkdtemp (String.concat [ "p2p_helper_test_"; local_name ])
      in
      let%bind node =
        create ~all_peers_seen_metric:false
          ~logger:(Logger.extend logger [ ("name", `String local_name) ])
          ~conf_dir ~pids ~on_peer_connected ~on_peer_disconnected
        >>| Or_error.ok_exn
      in
      let%bind kp_a =
        match keypair with
        | Some kp ->
            return kp
        | None ->
            generate_random_keypair node
      in
      let maddrs = List.map [ "/ip4/127.0.0.1/tcp/0" ] ~f:Multiaddr.of_string in
      let%bind () =
        configure node ~external_maddr:(List.hd_exn maddrs) ~me:kp_a ~maddrs
          ~network_id ~peer_exchange:true ~mina_peer_exchange:true
          ~direct_peers:[] ~seed_peers ~flooding:false ~metrics_port:None
          ~unsafe_no_trust_ip:true ~min_connections:25 ~max_connections:50
          ~validation_queue_size:150 ~initial_gating_config:gating_config
          ~known_private_ip_nets:[]
          ~topic_config:[ [ topic_a; topic_c ] ]
        >>| Or_error.ok_exn
      in
      let%bind raw_seed_peers = listening_addrs node >>| Or_error.ok_exn in
      let peerid = Keypair.to_peer_id kp_a in
      let addr =
        Printf.sprintf "%s/p2p/%s"
          (Multiaddr.to_string @@ List.hd_exn raw_seed_peers)
          peerid
        |> Multiaddr.of_string
      in
      let%bind () =
        begin_advertising node
        >>| if ignore_advertise_error then ignore else Or_error.ok_exn
      in
      (* Give the helpers time to announce and discover each other on localhost *)
      let shutdown () =
        [%log info] "Shutting down $name"
          ~metadata:[ ("name", `String local_name) ] ;
        let%bind () = shutdown node in
        File_system.remove_dir conf_dir
      in
      return (node, peerid, addr, shutdown)

    let test_def () =
      let open Deferred.Let_syntax in
      let on_connected (_, w) s = don't_wait_for (Pipe.write w (true, s)) in
      let on_disconnected (_, w) s = don't_wait_for (Pipe.write w (false, s)) in
      let a_pipe = Pipe.create () in
      let%bind _, y_peerid, y_addr, y_shutdown =
        setup_node "yota" ~ignore_advertise_error:true ~on_peer_connected:ignore
          ~on_peer_disconnected:ignore
      in
      (* Configuration *)
      let%bind a, a_peerid, a_addr, a_shutdown =
        setup_node "alice" (* ~ignore_advertise_error:true *)
          ~seed_peers:[ y_addr ] ~on_peer_connected:(on_connected a_pipe)
          ~on_peer_disconnected:(on_disconnected a_pipe)
      in
      (* Generate keypair *)
      let%bind kp_c = generate_random_keypair a in
      let c_peerid = Keypair.to_peer_id kp_c in
      let b_pipe = Pipe.create () in
      (* Configuration *)
      let%bind b, b_peerid, b_addr, b_shutdown =
        setup_node "bob" (* ~ignore_advertise_error:true *)
          ~seed_peers:[ y_addr ]
          ~gating_config:(mk_banning_gating_config c_peerid)
          ~on_peer_connected:(on_connected b_pipe)
          ~on_peer_disconnected:(on_disconnected b_pipe)
      in
      let c_pipe = Pipe.create () in
      (* Configuration *)
      let%bind c, _, c_addr, c_shutdown =
        setup_node "carol" ~keypair:kp_c ~seed_peers:[ y_addr; a_addr; b_addr ]
          ~on_peer_connected:(on_connected c_pipe)
          ~on_peer_disconnected:(on_disconnected c_pipe)
      in
      let addrs =
        { a_addr; b_addr; c_addr; a_peerid; b_peerid; c_peerid; y_peerid }
      in
      [%log info] "Alice: $peerId" ~metadata:[ ("peerId", `String a_peerid) ] ;
      [%log info] "Bob: $peerId" ~metadata:[ ("peerId", `String b_peerid) ] ;
      [%log info] "Carol: $peerId" ~metadata:[ ("peerId", `String c_peerid) ] ;
      let msgs =
        { topic_a_msg_1 = random_msg ()
        ; topic_a_msg_2 = random_msg ()
        ; topic_a_msg_3 = random_msg ()
        ; topic_c_msg_1 = { a = Random.int 1073741824; b = None }
        ; topic_c_msg_2 =
            { a = Random.int 1073741824; b = random_msg () |> Some }
        ; stream_1_msg_1 = random_msg ()
        ; stream_1_msg_2 = random_msg ()
        ; stream_2_msg_1 = random_msg ()
        }
      in
      Deferred.all_unit
        [ alice a addrs a_pipe msgs >>= a_shutdown
        ; bob b addrs b_pipe msgs >>= b_shutdown
        ; carol c addrs c_pipe msgs >>= c_shutdown
        ]
      >>= y_shutdown
      >>| fun () -> [%log info] "Test passes :)"

    let%test_unit "ipc test" =
      (* ignore test_def *)
      let () = Core.Backtrace.elide := false in
      Async.Thread_safe.block_on_async_exn test_def
  end )
