open Async_kernel
open Core_kernel

module type S = sig
  type t

  val connect :
       initial_peers:Host_and_port.t list
    -> me:Peer.t
    -> parent_log:Logger.t
    -> conf_dir:string
    -> t Deferred.Or_error.t

  val peers : t -> Peer.t list

  val first_peers : t -> Peer.t list Deferred.t

  val changes : t -> Peer.Event.t Linear_pipe.Reader.t

  val stop : t -> unit Deferred.t
end

(* Unfortunately, `dune runtest` runs in a pwd deep inside the build
 * directory, this prefix normalizes it to working-dir *)
let test_prefix = "../../../../"

let lock_file = "kademlia.lock"

let write_lock_file lock_path pid =
  Async.Writer.save lock_path ~contents:(Pid.to_string pid)

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
      let open Deferred.Let_syntax in
      (* Try kademlia, then prepend test_prefix if it's missing *)
      Deferred.Or_error.map
        ~f:(fun process -> {process; lock_path})
        ( match%bind Process.create ~prog:kademlia_binary ~args () with
        | Ok p -> return (Or_error.return p)
        | Error _ ->
            Process.create ~prog:(test_prefix ^ kademlia_binary) ~args () )
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
    Pipe.map
      (Reader.pipe (Process.stdout process))
      ~f:(fun str ->
        List.filter_map (String.split_lines str) ~f:(fun line ->
            let prefix_name_size = 4 in
            let prefix_size = prefix_name_size + 2 in
            (* a colon and a space *)
            let prefix = String.prefix line prefix_name_size in
            let pass_through () =
              Logger.warn log "Unexpected output from Kademlia Haskell: %s"
                line ;
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
              | "EROR" ->
                  Logger.error log "%s" line_no_prefix ;
                  None
              | "DATA" ->
                  Logger.info log "%s" line_no_prefix ;
                  Some line_no_prefix
              | _ -> pass_through () ) )
end

module Make (P : sig
  type t

  val kill : t -> unit Deferred.t

  val create :
       initial_peers:Host_and_port.t list
    -> me:Peer.t
    -> log:Logger.t
    -> conf_dir:string
    -> t Deferred.Or_error.t

  val output : t -> log:Logger.t -> string list Pipe.Reader.t
end) :
  S =
struct
  open Async

  type t =
    { p: P.t
    ; peers: string Peer.Table.t
    ; changes_reader: Peer.Event.t Linear_pipe.Reader.t
    ; changes_writer: Peer.Event.t Linear_pipe.Writer.t
    ; first_peers: Peer.t list Deferred.t }

  let live t lives =
    List.iter lives ~f:(fun (peer, kkey) ->
        let _ = Peer.Table.add ~key:peer ~data:kkey t.peers in
        () ) ;
    if List.length lives > 0 then
      Linear_pipe.write t.changes_writer
        (Peer.Event.Connect (List.map lives ~f:fst))
    else Deferred.unit

  let dead t deads =
    List.iter deads ~f:(fun peer -> Peer.Table.remove t.peers peer) ;
    if List.length deads > 0 then
      Linear_pipe.write t.changes_writer (Peer.Event.Disconnect deads)
    else Deferred.unit

  let connect ~initial_peers ~me ~parent_log ~conf_dir =
    let open Deferred.Or_error.Let_syntax in
    let log = Logger.child parent_log "membership" in
    let%map p = P.create ~initial_peers ~me ~log ~conf_dir in
    let peers = Peer.Table.create () in
    let changes_reader, changes_writer = Linear_pipe.create () in
    let first_peers_ivar = ref None in
    let first_peers =
      Deferred.create (fun ivar -> first_peers_ivar := Some ivar)
    in
    let t = {p; peers; changes_reader; changes_writer; first_peers} in
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

  let peers t = Peer.Table.keys t.peers

  let first_peers t = t.first_peers

  let changes t = t.changes_reader

  let stop t = P.kill t.p
end

let%test_module "Tests" =
  ( module struct
    let fold_membership (module M : S) : init:'b -> f:('b -> 'a -> 'b) -> 'b =
     fun ~init ~f ->
      Async.Thread_safe.block_on_async_exn (fun () ->
          match%bind
            M.connect ~initial_peers:[]
              ~me:(Host_and_port.create ~host:"127.0.0.1" ~port:3001, 3000)
              ~parent_log:(Logger.create ()) ~conf_dir:"/tmp/membership-test"
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
        let open Deferred.Let_syntax in
        (* Try kademlia, then prepend test_prefix if it's missing *)
        match%bind Process.create ~prog:"./dummy.sh" ~args:[] () with
        | Ok p -> return (Or_error.return p)
        | Error _ ->
            Process.create ~prog:(test_prefix ^ "./dummy.sh") ~args:[] ()

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

        module M = Make (Scripted_process (Script))

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

    module M = Make (Dummy_process)

    let%test "Dummy Script" =
      (* Just make sure the dummy is outputting things *)
      fold_membership (module M) ~init:false ~f:(fun b _e -> b || true)
  end )

module Haskell = Make (Haskell_process)

let addr i =
  (Host_and_port.of_string (Printf.sprintf "127.0.0.1:%d" (3006 + i)), 3005 + i)

let node me peers conf_dir =
  Haskell.connect ~initial_peers:peers ~me ~parent_log:(Logger.create ())
    ~conf_dir

let conf_dir = "/tmp/.kademlia-test-"

let retry n f =
  let rec go i = try f () with e -> if i = 0 then raise e else go (i - 1) in
  go n

let%test_unit "connect" =
  (* This flakes 1 in 20 times, so try a couple times if it fails *)
  retry 3 (fun () ->
      Async.Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          let conf_dir_1 = conf_dir ^ "1" and conf_dir_2 = conf_dir ^ "2" in
          let wait_sec s =
            let open Core in
            Async.(after (Time.Span.of_sec s))
          in
          let%bind () = Async.Unix.mkdir ~p:() conf_dir_1 in
          let%bind () = Async.Unix.mkdir ~p:() conf_dir_2 in
          File_system.with_temp_dirs [conf_dir_1; conf_dir_2] ~f:(fun () ->
              let%bind _n0 = node (addr 0) [] conf_dir_1
              and _n1 = node (addr 1) [fst (addr 0)] conf_dir_2 in
              let n0, n1 = (Or_error.ok_exn _n0, Or_error.ok_exn _n1) in
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
                List.hd_exn n0_peers = addr 1 && List.hd_exn n1_peers = addr 0
              ) ;
              let%bind () = Haskell.stop n0 and () = Haskell.stop n1 in
              Deferred.unit ) ) )

let%test_unit "lockfile does not exist after connection calling stop" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Async in
      let open Deferred.Let_syntax in
      File_system.with_temp_dirs [conf_dir] ~f:(fun () ->
          let%bind n = node (addr 1) [] conf_dir >>| Or_error.ok_exn in
          let lock_path = Filename.concat conf_dir lock_file in
          let%bind yes_result = Sys.file_exists lock_path in
          assert (`Yes = yes_result) ;
          let%bind () = Haskell.stop n in
          let%bind no_result = Sys.file_exists lock_path in
          return (assert (`No = no_result)) ) )
