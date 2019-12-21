open Async_kernel
open Core
open Pipe_lib
open Network_peer

exception Child_died

module type S = sig
  type t

  type trust_system

  val connect :
       initial_peers:Host_and_port.t list
    -> node_addrs_and_ports:Node_addrs_and_ports.t
    -> logger:Logger.t
    -> conf_dir:string
    -> trust_system:trust_system
    -> t Deferred.Or_error.t

  val peers : t -> Peer.t list

  val first_peers : t -> Peer.t list Deferred.t

  val changes : t -> Peer.Event.t Linear_pipe.Reader.t

  val stop : t -> unit Deferred.t

  module Hacky_glue : sig
    val inject_event : t -> Peer.Event.t -> unit
  end
end

module type Process_intf = sig
  type t

  val kill : t -> unit Deferred.t

  val create :
       initial_peers:Host_and_port.t list
    -> node_addrs_and_ports:Node_addrs_and_ports.t
    -> logger:Logger.t
    -> conf_dir:string
    -> t Deferred.Or_error.t

  (* TODO this doesn't need to be a list, it's always singleton *)
  val output : t -> logger:Logger.t -> string list Strict_pipe.Reader.t
end

module Haskell_process = struct
  open Async

  type t = {process: Child_processes.t; logger: Logger.t}

  let kill {process; logger; _} =
    Deferred.bind (Child_processes.kill process) ~f:(function
      | Ok _ ->
          Deferred.unit
      | Error err ->
          Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
            "Failed to kill kademlia helper: $err"
            ~metadata:[("err", `String (Error.to_string_hum err))] ;
          Deferred.unit )

  let cli_format : Unix.Inet_addr.t -> int -> string =
   fun host discovery_port ->
    Printf.sprintf "(\"%s\", %d)"
      (Unix.Inet_addr.to_string host)
      discovery_port

  let cli_format_initial_peer (addr : Host_and_port.t) : string =
    Printf.sprintf "(\"%s\", %d)" (Host_and_port.host addr)
      (Host_and_port.port addr)

  let filter_initial_peers (initial_peers : Host_and_port.t list)
      (me : Node_addrs_and_ports.t) =
    let external_host_and_port =
      Host_and_port.create
        ~host:(Unix.Inet_addr.to_string me.external_ip)
        ~port:me.discovery_port
    in
    List.filter initial_peers ~f:(fun peer ->
        not (Host_and_port.equal peer external_host_and_port) )

  let%test "filter_initial_peers_test" =
    let ip1 = Unix.Inet_addr.of_string "1.1.1.1" in
    let me =
      Node_addrs_and_ports.
        { external_ip= ip1
        ; bind_ip= ip1
        ; discovery_port= 8000
        ; communication_port= 8001
        ; client_port= 3000
        ; libp2p_port= 8002 }
    in
    let me_discovery = Host_and_port.create ~host:"1.1.1.1" ~port:8000 in
    let other = Host_and_port.create ~host:"1.1.1.2" ~port:8000 in
    filter_initial_peers [me_discovery; other] me = [other]

  let create :
         initial_peers:Host_and_port.t list
      -> node_addrs_and_ports:Node_addrs_and_ports.t
      -> logger:Logger.t
      -> conf_dir:string
      -> t Deferred.Or_error.t =
   fun ~initial_peers
       ~node_addrs_and_ports:( {discovery_port; bind_ip; external_ip; _} as
                             node_addrs_and_ports ) ~logger ~conf_dir ->
    let filtered_initial_peers =
      filter_initial_peers initial_peers node_addrs_and_ports
    in
    let args =
      [ "test"
      ; Unix.Inet_addr.to_string bind_ip
      ; cli_format external_ip discovery_port ]
      @ List.map filtered_initial_peers ~f:cli_format_initial_peer
    in
    Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
      "Kademlia command-line arguments: $argv"
      ~metadata:[("argv", `List (List.map args ~f:(fun arg -> `String arg)))] ;
    match%map
      Child_processes.start_custom
        ~logger:(Logger.extend logger [("helper-process", `String "kademlia")])
        ~name:"kademlia"
        ~git_root_relative_path:"src/app/kademlia-haskell/result/bin/kademlia"
        ~conf_dir ~args
        ~stdout:(`Log Logger.Level.Trace, `Pipe)
        ~stderr:(`Log Logger.Level.Error, `No_pipe)
        ~termination:`Always_raise
    with
    | Ok process ->
        Or_error.return {process; logger}
    | Error e ->
        Or_error.error_string
          ( "If you are a dev, did you forget to `make kademlia` and set \
             CODA_KADEMLIA_PATH? Try \
             CODA_KADEMLIA_PATH=$PWD/src/app/kademlia-haskell/result/bin/kademlia "
          ^ Error.to_string_hum e )

  let output {process; _} ~logger =
    Strict_pipe.Reader.filter_map (Child_processes.stdout_lines process)
      ~f:(fun line ->
        let prefix_name_size = 4 in
        let prefix_size = prefix_name_size + 2 in
        (* a colon and a space *)
        let prefix = String.prefix line prefix_name_size in
        let pass_through () =
          Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
            "Unexpected Kademlia output: %s" line ;
          None
        in
        if String.length line < prefix_size then pass_through ()
        else
          let line_no_prefix =
            String.slice line prefix_size (String.length line)
          in
          match prefix with
          (* These will be logged by the process library so we can ignore them
             here. *)
          | "DBUG" | "EROR" | "TRAC" ->
              None
          | "DATA" ->
              Some [line_no_prefix]
          | _ ->
              pass_through () )
end

module Make
    (P : Process_intf) (Trust_system : sig
        type t

        val lookup :
          t -> Unix.Inet_addr.Blocking_sexp.t -> Trust_system.Peer_status.t
    end) : sig
  include S with type trust_system := Trust_system.t

  module For_tests : sig
    val node :
         Node_addrs_and_ports.t
      -> Host_and_port.t list
      -> string
      -> Trust_system.t
      -> t Deferred.t
  end
end = struct
  open Async

  type t =
    { p: P.t
    ; peers: string Peer.Table.t
    ; changes_reader: Peer.Event.t Linear_pipe.Reader.t
    ; changes_writer: Peer.Event.t Linear_pipe.Writer.t
    ; first_peers: Peer.t list Deferred.t
    ; trust_system: Trust_system.t }

  let host_and_port_to_addr ({host; _} : Host_and_port.t) =
    Unix.Inet_addr.of_string host

  let is_banned trust_system (peer : Host_and_port.t) =
    match Trust_system.lookup trust_system (host_and_port_to_addr peer) with
    | {banned= Banned_until _; _} ->
        true
    | _ ->
        false

  let live t (lives : (Peer.t * string) list) =
    let unbanned_lives =
      List.filter lives ~f:(fun (peer, _) ->
          not (is_banned t.trust_system (Peer.to_discovery_host_and_port peer))
      )
    in
    List.iter unbanned_lives ~f:(fun (peer, kkey) ->
        Peer.Table.set ~key:peer ~data:kkey t.peers ) ;
    if List.length unbanned_lives > 0 then
      Linear_pipe.write t.changes_writer
        (Peer.Event.Connect (List.map unbanned_lives ~f:fst))
    else Deferred.unit

  let dead t (deads : Peer.t list) =
    List.iter deads ~f:(fun peer -> Peer.Table.remove t.peers peer) ;
    if List.length deads > 0 then
      Linear_pipe.write t.changes_writer (Peer.Event.Disconnect deads)
    else Deferred.unit

  let connect ~(initial_peers : Host_and_port.t list)
      ~(node_addrs_and_ports : Node_addrs_and_ports.t) ~logger ~conf_dir
      ~trust_system =
    let open Deferred.Or_error.Let_syntax in
    let filtered_peers =
      List.filter initial_peers ~f:(Fn.compose not (is_banned trust_system))
    in
    let%map p =
      P.create ~initial_peers:filtered_peers ~node_addrs_and_ports ~logger
        ~conf_dir
    in
    let peers = Peer.Table.create () in
    let changes_reader, changes_writer = Linear_pipe.create () in
    let first_peers_ivar = ref None in
    let first_peers =
      Deferred.create (fun ivar -> first_peers_ivar := Some ivar)
    in
    let t =
      {p; peers; changes_reader; changes_writer; first_peers; trust_system}
    in
    don't_wait_for
      (Strict_pipe.Reader.iter (P.output p ~logger) ~f:(fun lines ->
           let lives, deads =
             List.partition_map lines ~f:(fun line ->
                 match String.split ~on:' ' line with
                 | [addr; kademliaKey; "on"] ->
                     let addr = Host_and_port.of_string addr in
                     let discovery_port = Host_and_port.port addr in
                     let peer =
                       Peer.create
                         (Host_and_port.host addr |> Unix.Inet_addr.of_string)
                         ~discovery_port
                         ~communication_port:(discovery_port - 1)
                     in
                     `Fst (peer, kademliaKey)
                 | [addr; _; "off"] ->
                     let addr = Host_and_port.of_string addr in
                     let discovery_port = Host_and_port.port addr in
                     let peer =
                       Peer.create
                         (Host_and_port.host addr |> Unix.Inet_addr.of_string)
                         ~discovery_port
                         ~communication_port:(discovery_port - 1)
                     in
                     `Snd peer
                 | _ ->
                     failwith (Printf.sprintf "Unexpected line %s\n" line) )
           in
           let open Deferred.Let_syntax in
           let () =
             if List.length lives <> 0 then
               (* Update the peers *)
               Ivar.fill_if_empty
                 (Option.value_exn !first_peers_ivar)
                 (List.map ~f:fst lives)
             else ()
           in
           let%map () = live t lives and () = dead t deads in
           () )) ;
    t

  let peers t =
    let rec split ~f = function
      | [] ->
          ([], [])
      | x :: xs ->
          let true_subresult, false_subresult = split ~f xs in
          if f x then (x :: true_subresult, false_subresult)
          else (true_subresult, x :: false_subresult)
    in
    let peers = Peer.Table.keys t.peers in
    let banned_peers, normal_peers =
      split peers
        ~f:
          (Fn.compose (is_banned t.trust_system)
             Peer.to_discovery_host_and_port)
    in
    don't_wait_for (dead t banned_peers) ;
    normal_peers

  let first_peers t = t.first_peers

  let changes t = t.changes_reader

  let stop t = P.kill t.p

  module Hacky_glue = struct
    let inject_event t e =
      Linear_pipe.write t.changes_writer e |> don't_wait_for
  end

  module For_tests = struct
    let node node_addrs_and_ports (peers : Host_and_port.t list) conf_dir
        trust_system =
      connect ~initial_peers:peers ~node_addrs_and_ports
        ~logger:(Logger.null ()) ~conf_dir ~trust_system
      >>| Or_error.ok_exn
  end
end

module Haskell = Make (Haskell_process) (Trust_system)

let%test_module "Tests" =
  ( module struct
    open Core

    module Mocked_trust = struct
      type t = unit

      let lookup (_ : t) (_ : Unix.Inet_addr.t) =
        Trust_system.Peer_status.{trust= 0.0; banned= Unbanned}
    end

    module type S_test = sig
      include S with type trust_system := unit

      val connect :
           initial_peers:Host_and_port.t list
        -> node_addrs_and_ports:Node_addrs_and_ports.t
        -> logger:Logger.t
        -> conf_dir:string
        -> t Deferred.Or_error.t
    end

    module Make_test (P : Process_intf) = struct
      include Make (P) (Mocked_trust)

      let connect = connect ~trust_system:()
    end

    let conf_dir = Filename.temp_dir_name ^/ ".kademlia-test-"

    let fold_membership (module M : S_test) :
        init:'b -> f:('b -> 'a -> 'b) -> 'b =
     fun ~init ~f ->
      Async.Thread_safe.block_on_async_exn (fun () ->
          File_system.with_temp_dir conf_dir ~f:(fun temp_conf_dir ->
              match%bind
                M.connect ~initial_peers:[]
                  ~node_addrs_and_ports:
                    { external_ip= Unix.Inet_addr.localhost
                    ; bind_ip= Unix.Inet_addr.localhost
                    ; discovery_port= 3001
                    ; communication_port= 3000
                    ; client_port= 2000
                    ; libp2p_port= 3002 }
                  ~logger:(Logger.null ()) ~conf_dir:temp_conf_dir
              with
              | Ok t ->
                  let acc = ref init in
                  don't_wait_for
                    (Linear_pipe.iter (M.changes t) ~f:(fun e ->
                         return (acc := f !acc e) )) ;
                  let%bind () = Async.after (Time.Span.of_sec 3.) in
                  let%map () = M.stop t in
                  !acc
              | Error e ->
                  failwith (Printf.sprintf "%s" (Error.to_string_hum e)) ) )

    module Scripted_process (Script : sig
      val s : [`On of int | `Off of int] list
    end) =
    struct
      type t = string list

      let kill _ = return ()

      let create ~initial_peers:_ ~node_addrs_and_ports:_ ~logger:_ ~conf_dir:_
          =
        let on p = Printf.sprintf "127.0.0.1:%d key on" p in
        let off p = Printf.sprintf "127.0.0.1:%d key off" p in
        let render cmds =
          List.map cmds ~f:(function `On p -> on p | `Off p -> off p)
        in
        Deferred.Or_error.return (render Script.s)

      let output t ~logger:_logger =
        let r, w =
          Strict_pipe.create
            (Strict_pipe.Buffered (`Capacity 100, `Overflow Crash))
        in
        List.iter t ~f:(fun line -> Strict_pipe.Writer.write w [line]) ;
        r
    end

    module Dummy_process = struct
      open Async

      type t = Child_processes.t

      let kill t =
        Child_processes.kill t
        |> Deferred.map ~f:Or_error.ok_exn
        |> Deferred.ignore

      let create ~initial_peers:_ ~node_addrs_and_ports:_ ~logger ~conf_dir =
        Child_processes.start_custom ~logger ~name:"dummy.sh"
          ~git_root_relative_path:"src/dummy.sh" ~conf_dir ~args:[]
          ~stdout:(`Don't_log, `Pipe)
          ~stderr:(`Don't_log, `No_pipe)
          ~termination:`Always_raise

      let output t ~logger:_ =
        Child_processes.stdout_lines t |> Strict_pipe.Reader.map ~f:List.return
    end

    let%test_module "Mock Events" =
      ( module struct
        module Script = struct
          let s =
            [ `On 3000
            ; `Off 3001
            ; `On 3001
            ; `On 3002
            ; `On 3003
            ; `On 3003
            ; `Off 3000
            ; `Off 3001
            ; `On 3000 ]
        end

        module M = Make_test (Scripted_process (Script))

        let%test "Membership" =
          let result =
            fold_membership
              (module M)
              ~init:Script.s
              ~f:(fun acc e ->
                match (acc, e) with
                | `On p :: rest, Peer.Event.Connect [peer]
                  when Int.equal peer.discovery_port p ->
                    rest
                | `Off p :: rest, Peer.Event.Disconnect [peer]
                  when Int.equal peer.discovery_port p ->
                    rest
                | _ ->
                    failwith
                      (Printf.sprintf "Unexpected event %s"
                         (Peer.Event.sexp_of_t e |> Sexp.to_string_hum)) )
          in
          List.length result = 0
      end )

    module M = Make_test (Dummy_process)

    let%test "Dummy Script" =
      (* Just make sure the dummy is outputting things *)
      fold_membership (module M) ~init:false ~f:(fun b _e -> b || true)

    let node_addrs_and_ports_of_int i =
      let base = 3005 + (i * 3) in
      Node_addrs_and_ports.
        { external_ip= Unix.Inet_addr.localhost
        ; bind_ip= Unix.Inet_addr.localhost
        ; communication_port= base
        ; discovery_port= base + 1
        ; libp2p_port= base + 2
        ; client_port= 1000 + i }

    let retry n f =
      let rec go i =
        try f () with e -> if i = 0 then raise e else go (i - 1)
      in
      go n

    let wait_sec s =
      let open Core in
      Async.(after (Time.Span.of_sec s))

    let run_connection_test ~f =
      retry 3 (fun () ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              File_system.with_temp_dir (conf_dir ^ "1") ~f:(fun conf_dir_1 ->
                  File_system.with_temp_dir (conf_dir ^ "2")
                    ~f:(fun conf_dir_2 -> f conf_dir_1 conf_dir_2) ) ) )

    let get_temp_dir () =
      let tmpdir = Filename.temp_dir "test_trust_db" "" in
      at_exit (fun () -> Sys.command_exn @@ "rm -rf '" ^ tmpdir ^ "'") ;
      tmpdir

    let create_trust_system () = Trust_system.create (get_temp_dir ())

    let%test_unit "connect" =
      (* This flakes 1 in 20 times, so try a couple times if it fails *)
      run_connection_test ~f:(fun conf_dir_1 conf_dir_2 ->
          let open Deferred.Let_syntax in
          let%bind n0 =
            Haskell.For_tests.node
              (node_addrs_and_ports_of_int 0)
              [] conf_dir_1 (create_trust_system ())
          and n1 =
            Haskell.For_tests.node
              (node_addrs_and_ports_of_int 1)
              [ node_addrs_and_ports_of_int 0
                |> Node_addrs_and_ports.to_discovery_host_and_port ]
              conf_dir_2 (create_trust_system ())
          in
          let%bind n0_peers =
            Deferred.any
              [ Haskell.first_peers n0
              ; Deferred.map (wait_sec 10.) ~f:(fun () -> []) ]
          in
          assert (List.length n0_peers <> 0) ;
          let%bind n1_peers =
            Deferred.any
              [ Haskell.first_peers n1
              ; Deferred.map (wait_sec 5.) ~f:(fun () -> []) ]
          in
          assert (List.length n1_peers <> 0) ;
          assert (
            List.hd_exn n0_peers
            = (node_addrs_and_ports_of_int 1 |> Node_addrs_and_ports.to_peer)
            && List.hd_exn n1_peers
               = (node_addrs_and_ports_of_int 0 |> Node_addrs_and_ports.to_peer)
          ) ;
          let%bind () = Haskell.stop n0 and () = Haskell.stop n1 in
          Deferred.unit )

    let%test_module "Trust" =
      ( module struct
        (* TODO: Re-enable #1725
        let poll wait_time ~f =
          let rec should_continue () =
            let%bind condition = f () in
            if condition then Deferred.unit else wait_sec 0.5 >>= should_continue
          in
          Deferred.any
            [ (should_continue () >>| fun () -> true)
            ; (wait_sec wait_time >>| fun () -> false) ]


        (* Mock trust system *)
        module Trust_system = struct
          type t = Unix.Inet_addr.Set.t ref

          let lookup t addr =
            if Unix.Inet_addr.Set.mem !t addr then
              Peer_trust.Peer_status.
                { trust= -1.
                ; banned= Peer_trust.Banned_status.Banned_until Time.epoch }
            else
              Peer_trust.Peer_status.
                {trust= 0.; banned= Peer_trust.Banned_status.Unbanned}

          let create () = ref Unix.Inet_addr.Set.empty
        end

        module Haskell_trust = Make (Haskell_process) (Trust_system)

        let reset node ~addr ~conf_dir ~trust_system ~peers =
          let%bind () = Haskell_trust.stop node in
          Haskell_trust.For_tests.node addr peers conf_dir trust_system

        let%test_unit "connect with ban logic" =
            (* This flakes 1 in 20 times, so try a couple times if it fails *)
            run_connection_test ~f:(fun banner_conf_dir normal_conf_dir ->
                let banner_addr = node_addrs_and_ports_of_int 0 in
                let normal_addr = node_addrs_and_ports_of_int 1 in
                let normal_peer = Peer.to_discovery_host_and_port normal_addr in
                let trust_system = Trust_system.create () in
                let%bind banner_node =
                  Haskell_trust.For_tests.node banner_addr [normal_peer]
                    banner_conf_dir trust_system
                and normal_node =
                  Haskell.For_tests.node normal_addr [] normal_conf_dir
                    (create_trust_system ())
                in
                let%bind initial_discovered_peers =
                  Deferred.any
                    [ Haskell_trust.first_peers banner_node
                    ; Deferred.map (wait_sec 10.) ~f:(fun () -> []) ]
                in
                assert (List.length initial_discovered_peers <> 0) ;
                trust_system :=
                  Unix.Inet_addr.Set.add !trust_system normal_addr.host ;
                let%bind is_not_connected_to_banned_peer =
                  poll 5. ~f:(fun () ->
                      let peers_after_ban = Haskell_trust.peers banner_node in
                      return (List.length peers_after_ban = 0) )
                in
                assert is_not_connected_to_banned_peer ;
                trust_system := Unix.Inet_addr.Set.empty ;
                let%bind new_banner_node =
                  reset banner_node ~addr:banner_addr ~conf_dir:banner_conf_dir
                    ~trust_system ~peers:[normal_peer]
                in
                let%bind is_reconnecting_to_banned_peer =
                  poll 10. ~f:(fun () ->
                      let peers_after_reconnect =
                        Haskell_trust.peers new_banner_node
                      in
                      Deferred.return
                      @@ Option.is_some
                        (List.find peers_after_reconnect ~f:(fun p ->
                             p = node_addrs_and_ports_of_int 1 )) )
                in
                assert is_reconnecting_to_banned_peer ;
                let%bind () = Haskell_trust.stop new_banner_node
                and () = Haskell.stop normal_node in
                Deferred.unit ) *)
      
      end )
  end )
