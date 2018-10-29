open Async_kernel
open Core_kernel
open Banlist_lib

module type S = sig
  type t

  type banlist

  val connect :
       initial_peers:Host_and_port.t list
    -> me:Peer.t
    -> parent_log:Logger.t
    -> conf_dir:string
    -> banlist:banlist
    -> t Deferred.Or_error.t

  val peers : t -> Peer.t list

  val first_peers : t -> Peer.t list Deferred.t

  val changes : t -> Peer.Event.t Linear_pipe.Reader.t

  val stop : t -> unit Deferred.t
end

module type Process_intf = sig
  type t

  val kill : t -> unit Deferred.t

  val create :
       initial_peers:Host_and_port.t list
    -> me:Peer.t
    -> log:Logger.t
    -> conf_dir:string
    -> t Deferred.Or_error.t

  val output : t -> log:Logger.t -> string list Pipe.Reader.t
end

(* Unfortunately, `dune runtest` runs in a pwd deep inside the build
 * directory, this prefix normalizes it to working-dir *)
let test_prefix = "../../../../"

let lock_file = "kademlia.lock"

let write_lock_file lock_path pid =
  Async.Writer.save lock_path ~contents:(Pid.to_string pid)

let keep_trying :
    f:('a -> 'b Deferred.Or_error.t) -> 'a list -> 'b Deferred.Or_error.t =
 fun ~f xs ->
  let open Deferred.Let_syntax in
  let rec go e xs : 'b Deferred.Or_error.t =
    match xs with
    | [] -> return e
    | x :: xs -> (
        match%bind f x with
        | Ok r -> return (Ok r)
        | Error e -> go (Error e) xs )
  in
  go (Or_error.error_string "empty input") xs

module Haskell_process = struct
  open Async

  type t = {process: Process.t; lock_path: string}

  let kill {process; lock_path} =
    let%bind _ =
      Process.run_exn ~prog:"kill"
        ~args:[Pid.to_string (Process.pid process)]
        ()
    in
    Sys.remove lock_path

  let cli_format (addr, port) : string =
    (* assertion for discovery_port = external_port - 1 *)
    assert (Host_and_port.port addr - 1 = port) ;
    Printf.sprintf "(\"%s\", %d)" (Host_and_port.host addr)
      (Host_and_port.port addr)

  let cli_format_initial_peer addr : string =
    Printf.sprintf "(\"%s\", %d)" (Host_and_port.host addr)
      (Host_and_port.port addr)

  let filter_initial_peers initial_peers me =
    List.filter initial_peers ~f:(fun peer ->
        not (Host_and_port.equal peer (fst me)) )

  let%test "filter_initial_peers_test" =
    let me = (Host_and_port.create ~host:"1.1.1.1" ~port:8000, 8001) in
    let other = Host_and_port.create ~host:"1.1.1.2" ~port:8000 in
    filter_initial_peers [fst me; other] me = [other]

  let create ~initial_peers ~me ~log ~conf_dir =
    let lock_path = Filename.concat conf_dir lock_file in
    let filtered_initial_peers = filter_initial_peers initial_peers me in
    let run_kademlia () =
      let args =
        ["test"; cli_format me]
        @ List.map filtered_initial_peers ~f:cli_format_initial_peer
      in
      Logger.debug log "Args: %s\n"
        (List.sexp_of_t String.sexp_of_t args |> Sexp.to_string_hum) ;
      (* This is where nix dumps the haskell artifact *)
      let kademlia_binary = "app/kademlia-haskell/result/bin/kademlia" in
      (* This is where you'd manually install kademlia *)
      let coda_kademlia = "coda-kademlia" in
      let open Deferred.Let_syntax in
      match%map
        keep_trying
          [ Unix.getenv "CODA_KADEMLIA_PATH"
            |> Option.value ~default:coda_kademlia
          ; kademlia_binary
          ; test_prefix ^ kademlia_binary ]
          ~f:(fun prog -> Process.create ~prog ~args ())
        |> Deferred.Or_error.map ~f:(fun process -> {process; lock_path})
      with
      | Ok p -> Ok p
      | Error e ->
          Or_error.error_string
            ( "If you are a dev, did you forget to `make kademlia` and set \
               CODA_KADEMLIA_PATH? Try \
               CODA_KADEMLIA_PATH=$PWD/src/app/kademlia-haskell/result/bin/kademlia "
            ^ Error.to_string_hum e )
    in
    let kill_locked_process ~log =
      match%bind Sys.file_exists lock_path with
      | `Yes -> (
          let%bind p = Reader.file_contents lock_path in
          match%bind Process.run ~prog:"kill" ~args:[p] () with
          | Ok _ ->
              Logger.debug log "Killing Dead Kademlia Process %s" p ;
              let%map () = Sys.remove lock_path in
              Ok ()
          | Error _ ->
              Logger.debug log
                "Process %s does not exists and will not be killed" p ;
              return @@ Ok () )
      | _ -> return @@ Ok ()
    in
    let open Deferred.Or_error.Let_syntax in
    let args =
      ["test"; cli_format me]
      @ List.map initial_peers ~f:cli_format_initial_peer
    in
    Logger.debug log "Args: %s\n"
      (List.sexp_of_t String.sexp_of_t args |> Sexp.to_string_hum) ;
    let%bind () = kill_locked_process ~log in
    match%bind
      Sys.is_directory conf_dir |> Deferred.map ~f:Or_error.return
    with
    | `Yes ->
        let%bind t = run_kademlia () in
        let {process; lock_path} = t in
        let%map () =
          write_lock_file lock_path (Process.pid process)
          |> Deferred.map ~f:Or_error.return
        in
        don't_wait_for
          (Pipe.iter_without_pushback
             (Reader.pipe (Process.stderr process))
             ~f:(fun str -> Logger.error log "%s" str)) ;
        t
    | _ -> Deferred.Or_error.errorf "Config directory (%s) must exist" conf_dir

  let output {process; _} ~log =
    Pipe.filter_map
      (Reader.lines (Process.stdout process))
      ~f:(fun line ->
        let prefix_name_size = 4 in
        let prefix_size = prefix_name_size + 2 in
        (* a colon and a space *)
        let prefix = String.prefix line prefix_name_size in
        let pass_through () =
          Logger.warn log "Unexpected output from Kademlia Haskell: %s" line ;
          None
        in
        if String.length line < prefix_size then pass_through ()
        else
          let line_no_prefix =
            String.slice line prefix_size (String.length line)
          in
          match prefix with
          | "DBUG" ->
              Logger.debug log "%s" line_no_prefix ;
              None
          | "TRAC" ->
              Logger.trace log "%s" line_no_prefix ;
              None
          | "EROR" ->
              Logger.error log "%s" line_no_prefix ;
              None
          | "DATA" ->
              Logger.info log "%s" line_no_prefix ;
              Some [line_no_prefix]
          | _ -> pass_through () )
end

module Make
    (P : Process_intf) (Banlist : sig
        type t

        type punishment

        val lookup :
             t
          -> Host_and_port.t
          -> [ `Normal
             | `Punished of punishment
             | `Suspicious of Banlist.Score.t ]
    end) : sig
  include S with type banlist := Banlist.t

  module For_tests : sig
    val node :
         Peer.t
      -> Host_and_port.t sexp_list
      -> string
      -> Banlist.t
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
    ; banlist: Banlist.t }

  let is_banned banlist peer =
    match Banlist.lookup banlist peer with `Punished _ -> true | _ -> false

  let live t lives =
    let unbanned_lives =
      List.filter lives ~f:(fun (peer, _) ->
          not (is_banned t.banlist (fst peer)) )
    in
    List.iter unbanned_lives ~f:(fun (peer, kkey) ->
        let _ = Peer.Table.add ~key:peer ~data:kkey t.peers in
        () ) ;
    if List.length unbanned_lives > 0 then
      Linear_pipe.write t.changes_writer
        (Peer.Event.Connect (List.map unbanned_lives ~f:fst))
    else Deferred.unit

  let dead t deads =
    List.iter deads ~f:(fun peer -> Peer.Table.remove t.peers peer) ;
    if List.length deads > 0 then
      Linear_pipe.write t.changes_writer (Peer.Event.Disconnect deads)
    else Deferred.unit

  let connect ~initial_peers ~me ~parent_log ~conf_dir ~banlist =
    let open Deferred.Or_error.Let_syntax in
    let log = Logger.child parent_log "membership" in
    let filtered_peers =
      List.filter initial_peers ~f:(Fn.compose not (is_banned banlist))
    in
    let%map p = P.create ~initial_peers:filtered_peers ~me ~log ~conf_dir in
    let peers = Peer.Table.create () in
    let changes_reader, changes_writer = Linear_pipe.create () in
    let first_peers_ivar = ref None in
    let first_peers =
      Deferred.create (fun ivar -> first_peers_ivar := Some ivar)
    in
    let t = {p; peers; changes_reader; changes_writer; first_peers; banlist} in
    don't_wait_for
      (Pipe.iter (P.output p ~log) ~f:(fun lines ->
           let lives, deads =
             List.partition_map lines ~f:(fun line ->
                 match String.split ~on:' ' line with
                 | [addr; kademliaKey; "on"] ->
                     let addr = Host_and_port.of_string addr in
                     `Fst ((addr, Host_and_port.port addr - 1), kademliaKey)
                 | [addr; _; "off"] ->
                     let addr = Host_and_port.of_string addr in
                     `Snd (addr, Host_and_port.port addr - 1)
                 | _ -> failwith (Printf.sprintf "Unexpected line %s\n" line)
             )
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
      | [] -> ([], [])
      | x :: xs ->
          let true_subresult, false_subresult = split ~f xs in
          if f x then (x :: true_subresult, false_subresult)
          else (true_subresult, x :: false_subresult)
    in
    let peers = Peer.Table.keys t.peers in
    let banned_peers, normal_peers =
      split peers ~f:(Fn.compose (is_banned t.banlist) fst)
    in
    don't_wait_for (dead t banned_peers) ;
    normal_peers

  let first_peers t = t.first_peers

  let changes t = t.changes_reader

  let stop t = P.kill t.p

  module For_tests = struct
    let node me peers conf_dir banlist =
      connect ~initial_peers:peers ~me ~parent_log:(Logger.create ()) ~conf_dir
        ~banlist
      >>| Or_error.ok_exn
  end
end

module Haskell = struct
  module Banlist = struct
    include Coda_base.Banlist

    type punishment = Coda_base.Banlist.Punishment_record.t
  end

  include Make (Haskell_process) (Banlist)
end

let%test_module "Tests" =
  ( module struct
    open Core

    module Mocked_banlist = struct
      type t = unit

      type punishment = unit

      let lookup (_ : t) (_ : Host_and_port.t) = `Normal
    end

    module type S_test = sig
      include S with type banlist := unit

      val connect :
           initial_peers:Host_and_port.t list
        -> me:Peer.t
        -> parent_log:Logger.t
        -> conf_dir:string
        -> t Deferred.Or_error.t
    end

    module Make_test (P : Process_intf) = struct
      include Make (P) (Mocked_banlist)

      let connect = connect ~banlist:()
    end

    let fold_membership (module M : S_test) :
        init:'b -> f:('b -> 'a -> 'b) -> 'b =
     fun ~init ~f ->
      Async.Thread_safe.block_on_async_exn (fun () ->
          match%bind
            M.connect ~initial_peers:[]
              ~me:(Host_and_port.create ~host:"127.0.0.1" ~port:3001, 3000)
              ~parent_log:(Logger.create ())
              ~conf_dir:(Filename.temp_dir_name ^/ "membership-test")
          with
          | Ok t ->
              let acc = ref init in
              don't_wait_for
                (Linear_pipe.iter (M.changes t) ~f:(fun e ->
                     return (acc := f !acc e) )) ;
              let%bind () = Async.after (Time.Span.of_sec 3.) in
              let%map () = M.stop t in
              !acc
          | Error e -> failwith (Printf.sprintf "%s" (Error.to_string_hum e))
      )

    module Scripted_process (Script : sig
      val s : [`On of int | `Off of int] list
    end) =
    struct
      type t = string list

      let kill _ = return ()

      let create ~initial_peers:_ ~me:_ ~log:_ ~conf_dir:_ =
        let on p = Printf.sprintf "127.0.0.1:%d key on" p in
        let off p = Printf.sprintf "127.0.0.1:%d key off" p in
        let render cmds =
          List.map cmds ~f:(function `On p -> on p | `Off p -> off p)
        in
        Deferred.Or_error.return (render Script.s)

      let output t ~log:_log =
        let r, w = Pipe.create () in
        List.iter t ~f:(fun line -> Pipe.write_without_pushback w [line]) ;
        r
    end

    module Dummy_process = struct
      open Async

      type t = Process.t

      let kill t =
        let%map _ =
          Process.run_exn ~prog:"kill" ~args:[Pid.to_string (Process.pid t)] ()
        in
        ()

      let create ~initial_peers:_ ~me:_ ~log:_ ~conf_dir:_ =
        (* Try dummy, then prepend test_prefix if it's missing *)
        keep_trying ["./dummy.sh"; test_prefix ^ "./dummy.sh"] ~f:(fun prog ->
            Process.create ~prog ~args:[] () )

      let output t ~log:_log =
        Pipe.map (Reader.pipe (Process.stdout t)) ~f:String.split_lines
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
                  when Host_and_port.port (fst peer) = p ->
                    rest
                | `Off p :: rest, Peer.Event.Disconnect [peer]
                  when Host_and_port.port (fst peer) = p ->
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

    let addr i =
      ( Host_and_port.of_string (Printf.sprintf "127.0.0.1:%d" (3006 + i))
      , 3005 + i )

    let conf_dir = Filename.temp_dir_name ^/ ".kademlia-test-"

    let retry n f =
      let rec go i =
        try f () with e -> if i = 0 then raise e else go (i - 1)
      in
      go n

    let wait_sec s =
      let open Core in
      Async.(after (Time.Span.of_sec s))

    let poll wait_time ~f =
      let rec should_continue () =
        let%bind condition = f () in
        if condition then Deferred.unit else wait_sec 0.5 >>= should_continue
      in
      Deferred.any
        [ (should_continue () >>| fun () -> true)
        ; (wait_sec wait_time >>| fun () -> false) ]

    let run_connection_test ~f =
      retry 3 (fun () ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              File_system.with_temp_dir (conf_dir ^ "1") ~f:(fun conf_dir_1 ->
                  File_system.with_temp_dir (conf_dir ^ "2")
                    ~f:(fun conf_dir_2 -> f conf_dir_1 conf_dir_2 ) ) ) )

    let create_banlist () =
      Haskell.Banlist.create ~suspicious_dir:"" ~punished_dir:""

    let%test_unit "connect" =
      (* This flakes 1 in 20 times, so try a couple times if it fails *)
      run_connection_test ~f:(fun conf_dir_1 conf_dir_2 ->
          let open Deferred.Let_syntax in
          let%bind n0 =
            Haskell.For_tests.node (addr 0) [] conf_dir_1 (create_banlist ())
          and n1 =
            Haskell.For_tests.node (addr 1)
              [fst (addr 0)]
              conf_dir_2 (create_banlist ())
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
            List.hd_exn n0_peers = addr 1 && List.hd_exn n1_peers = addr 0 ) ;
          let%bind () = Haskell.stop n0 and () = Haskell.stop n1 in
          Deferred.unit )

    let%test_module "Banlist" =
      ( module struct
        module Score = Banlist.Score
        module Suspicious_db =
          Banlist.Key_value_database.Make_mock (Host_and_port) (Score)

        let ban_duration_int = 10.0

        let ban_duration = Time.Span.of_sec ban_duration_int

        module Punishment_record = struct
          type time = Time.t

          include Banlist.Punishment.Record.Make (struct
            let duration = ban_duration
          end)
        end

        module Punished_db =
          Banlist.Punished_db.Make (Host_and_port) (Time) (Punishment_record)
            (Banlist.Key_value_database.Make_mock
               (Host_and_port)
               (Punishment_record))

        let ban_threshold = 100

        module Score_mechanism = struct
          open Banlist.Offense

          let score offense =
            Banlist.Score.of_int
              ( match offense with
              | Failed_to_connect -> ban_threshold + 1
              | Send_bad_hash -> ban_threshold / 2
              | Send_bad_aux -> ban_threshold / 4 )
        end

        module Banlist = struct
          type punishment = Punishment_record.t

          include Banlist.Make (Host_and_port) (Punishment_record)
                    (Suspicious_db)
                    (Punished_db)
                    (Score_mechanism)

          let create () =
            create ~ban_threshold ~suspicious_dir:"" ~punished_dir:""
        end

        module Haskell_banlist = Make (Haskell_process) (Banlist)

        let reset node ~addr ~conf_dir ~banlist ~peers =
          let%bind () = Haskell_banlist.stop node in
          Haskell_banlist.For_tests.node addr peers conf_dir banlist

        let%test_unit "connect with ban logic" =
          (* This flakes 1 in 20 times, so try a couple times if it fails *)
          run_connection_test ~f:(fun banner_conf_dir normal_conf_dir ->
              let banner_addr = addr 0 in
              let normal_addr = addr 1 in
              let normal_peer = fst normal_addr in
              let banlist = Banlist.create () in
              let%bind banner_node =
                Haskell_banlist.For_tests.node banner_addr [normal_peer]
                  banner_conf_dir banlist
              and normal_node =
                Haskell.For_tests.node normal_addr [] normal_conf_dir
                  (create_banlist ())
              in
              let%bind initial_discovered_peers =
                Deferred.any
                  [ Haskell_banlist.first_peers banner_node
                  ; Deferred.map (wait_sec 10.) ~f:(fun () -> []) ]
              in
              assert (List.length initial_discovered_peers <> 0) ;
              Banlist.ban banlist normal_peer
                (Punishment_record.create_timeout
                   (Score.of_int (ban_threshold + 1))) ;
              let%bind is_not_connected_to_banned_peer =
                poll (ban_duration_int /. 2.0) ~f:(fun () ->
                    let peers_after_ban = Haskell_banlist.peers banner_node in
                    return (List.length peers_after_ban = 0) )
              in
              assert is_not_connected_to_banned_peer ;
              let%bind new_banner_node =
                reset banner_node ~addr:banner_addr ~conf_dir:banner_conf_dir
                  ~banlist ~peers:[normal_peer]
              in
              let%bind is_reconnecting_to_banned_peer =
                poll (ban_duration_int /. 2.0) ~f:(fun () ->
                    let%map peers_after_reconnect =
                      Haskell_banlist.first_peers new_banner_node
                    in
                    List.length peers_after_reconnect <> 0
                    && List.hd_exn peers_after_reconnect = addr 1 )
              in
              assert is_reconnecting_to_banned_peer ;
              let%bind () = Haskell_banlist.stop new_banner_node
              and () = Haskell.stop normal_node in
              Deferred.unit )
      end )

    let%test_unit "lockfile does not exist after connection calling stop" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let open Async in
          let open Deferred.Let_syntax in
          File_system.with_temp_dir conf_dir ~f:(fun temp_dir ->
              let%bind n =
                Haskell.For_tests.node (addr 1) [] temp_dir (create_banlist ())
              in
              let lock_path = Filename.concat temp_dir lock_file in
              let%bind yes_result = Sys.file_exists lock_path in
              assert (`Yes = yes_result) ;
              let%bind () = Haskell.stop n in
              let%map no_result = Sys.file_exists lock_path in
              assert (`No = no_result) ) )
  end )
