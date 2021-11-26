(* Test IPCs with restricted throughput *)

open Core
open Async
open Mina_net2

type status = NotMet | Connected | Disconnected [@@deriving sexp]

type typed_msg = { a : int; b : string option }
[@@deriving bin_io_unversioned, equal, sexp, compare]

exception UnexpectedPeerConnectionStatus of string * bool * string

exception UnexpectedEof of string

exception UnexpectedState

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

    let bob_status =
      "This is major Tom to ground control\nI'm stepping through the door"

    type messages =
      { stream_1_msg_1 : string
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
          assert (String.equal p.peer_id expected_sender) ) ;
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
      let pcLs = [(bobStatus, ad.b_peerid)] in
      let pcIter pred = iteratePcWhile "alice" pc pcLs ~pred in

      (* Connect Alice to Bob *)
      let%bind () = add_peer a ad.b_addr ~is_seed:false >>| Or_error.ok_exn in

      (* Await connection to succeed *)
      let%bind () =
        pcIter (fun () ->
            match !bobStatus with
            | NotMet ->
                false
            | Connected ->
                true
            | _ ->
                raise UnexpectedState)
        |> or_timeout ~msg:"Alice: connect to Bob"
      in

      (* Get addresses of Alice *)
      let%bind lAddrs = listening_addrs a >>| Or_error.ok_exn in
      assert (List.length lAddrs > 0) ;

      (* List peers of Alice *)
      let%bind peers = peers a in
      assert (List.length peers = 1) ;

      assert (
        List.fold [ ad.y_peerid; ad.b_peerid; ad.c_peerid ] ~init:true
          ~f:(fun b_acc pid ->
            b_acc
            && List.fold peers ~init:false ~f:(fun acc p ->
                   acc || String.equal p.peer_id pid)) ) ;

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
          ~unsafe_no_trust_ip:true ~max_connections:50
          ~validation_queue_size:150 ~initial_gating_config:gating_config
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

    let test_def =
      let open Deferred.Let_syntax in
      let on_connected (_, w) s = don't_wait_for (Pipe.write w (true, s)) in
      let on_disconnected (_, w) s = don't_wait_for (Pipe.write w (false, s)) in

      (* Create node `a` without constraints on Pipe size *)
      let a_pipe = Pipe.create () in
      let%bind _, y_peerid, y_addr, y_shutdown =
        setup_node "yota" ~ignore_advertise_error:true ~on_peer_connected:ignore
          ~on_peer_disconnected:ignore
      in

      let%bind a, a_peerid, a_addr, a_shutdown =
        setup_node "alice" (* ~ignore_advertise_error:true *)
          ~seed_peers:[ y_addr ] ~on_peer_connected:(on_connected a_pipe)
          ~on_peer_disconnected:(on_disconnected a_pipe)
      in
      let%bind kp_a = generate_random_keypair a in
      let a_peerid = Keypair.to_peer_id kp_a in

      (* Create node `b` with a restricted Pipe *)
      let b_pipe = Pipe.set_size_budget (Pipe.create ()) 3 in

      let%bind b, b_peerid, b_addr, b_shutdown =
        setup_node "bob" (* ~ignore_advertise_error:true *)
          ~seed_peers:[ y_addr ]
          ~gating_config:(mk_banning_gating_config a_peerid)
          ~on_peer_connected:(on_connected b_pipe)
          ~on_peer_disconnected:(on_disconnected b_pipe)
      in

      let addrs =
        { a_addr; b_addr; a_peerid; b_peerid; y_peerid }
      in
      [%log info] "Alice: $peerId" ~metadata:[ ("peerId", `String a_peerid) ] ;
      [%log info] "Bob: $peerId" ~metadata:[ ("peerId", `String b_peerid) ] ;
      let msgs =
        { stream_1_msg_1 = random_msg ()
        ; stream_1_msg_2 = random_msg ()
        ; stream_2_msg_1 = random_msg ()
        }
      in
      Deferred.all_unit
        [ alice a addrs a_pipe msgs >>= a_shutdown
        ; bob b addrs b_pipe msgs >>= b_shutdown
        ]
      >>= y_shutdown
      >>| fun () -> [%log info] "Test passes :)"

    let%test_unit "restricted ipc test" =
      (* ignore test_def *)
      let () = Core.Backtrace.elide := false in
      Async.Thread_safe.block_on_async_exn (fun () -> test_def)
  end )
