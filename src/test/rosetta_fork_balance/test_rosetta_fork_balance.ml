(* A running Rosetta asked for a balance after a hard fork.

   The archive holds a pre-fork chain in which alice's account changed at
   height 2, then the fork: its genesis at height 4 and a block at height 5.
   The fork's genesis ledger gives alice a new balance, and no post-fork block
   touches her account. Asked for her balance at height 5, Rosetta must answer
   the fork's genesis balance; at height 2, the pre-fork one.

   Rosetta reads balances from the archive; the daemon is only asked which
   network it serves, so a stub GraphQL server answers that. Needs a
   PostgreSQL server: MINA_TEST_POSTGRES. *)

open Core
open Async
module B = Synthetic_archive

let network = "testnet"

let pre_fork_balance = 400_000_000_000

let fork_genesis_balance = 7_777_000_000_000

let scenario () =
  let s = B.create () in
  let alice = B.account s "alice" in
  let b1 = B.block s ~name:"b1" ~height:1 Canonical in
  let b2 = B.block s ~name:"b2" ~height:2 ~parent:b1 Canonical in
  let fork_block = B.block s ~name:"fork" ~height:3 ~parent:b2 Canonical in
  let genesis =
    B.block ~parent:fork_block ~global_slot_since_hard_fork:0
      ~protocol_version:(5, 0, 0) s ~name:"genesis" ~height:4 Canonical
  in
  let (_ : B.block) =
    B.block ~parent:genesis ~protocol_version:(5, 0, 0) s ~name:"b5" ~height:5
      Canonical
  in
  B.account_state ~nonce:3 s b2 alice ~balance:pre_fork_balance ;
  B.genesis_account ~nonce:3 s ~genesis_height:4 alice
    ~balance:fork_genesis_balance ;
  (s, alice)

let free_port () =
  let server =
    Tcp.Server.create_sock_inet ~on_handler_error:`Raise
      Tcp.Where_to_listen.of_port_chosen_by_os (fun _ _ -> Deferred.unit)
  in
  let port = Tcp.Server.listening_on server in
  let%map () = Tcp.Server.close server in
  port

(* Answers every GraphQL query with the network id, the only thing Rosetta
   asks the daemon on the way to an archive balance. *)
let with_graphql_stub f =
  let%bind port = free_port () in
  let%bind server =
    Cohttp_async.Server.create ~on_handler_error:`Ignore
      (Tcp.Where_to_listen.of_port port) (fun ~body:_ _ _ ->
        Cohttp_async.Server.respond_string
          ~headers:
            (Cohttp.Header.of_list [ ("Content-Type", "application/json") ])
          (sprintf {|{"data":{"networkID":"mina:%s"}}|} network) )
  in
  Monitor.protect
    (fun () -> f (Uri.of_string (sprintf "http://127.0.0.1:%d/graphql" port)))
    ~finally:(fun () -> Cohttp_async.Server.close server)

let with_rosetta ~archive_uri ~graphql_uri f =
  let%bind port = free_port () in
  let%bind rosetta =
    Process.create_exn ~prog:"../../app/rosetta/rosetta.exe"
      ~env:(`Extend [ ("MINA_ROSETTA_MAX_DB_POOL_SIZE", "4") ])
      ~args:
        [ "--archive-uri"
        ; Uri.to_string archive_uri
        ; "--graphql-uri"
        ; Uri.to_string graphql_uri
        ; "--port"
        ; Int.to_string port
        ]
      ()
  in
  don't_wait_for (Reader.drain (Process.stdout rosetta)) ;
  don't_wait_for (Reader.drain (Process.stderr rosetta)) ;
  let client =
    Rosetta_client.Http.create
      ~base_uri:(Uri.of_string (sprintf "http://127.0.0.1:%d" port))
      ~network ()
  in
  Monitor.protect
    (fun () -> f client)
    ~finally:(fun () ->
      Signal.send_i Signal.term (`Pid (Process.pid rosetta)) ;
      Deferred.ignore_m (Process.wait rosetta) )

(* The total balance of [account] at [height], once Rosetta answers. *)
let balance client account ~height =
  let rec ask tries =
    match%bind
      Rosetta_client.Data.account_balance client ~address:(B.public_key account)
        ~block_index:height ()
    with
    | Ok json ->
        return
          Yojson.Safe.Util.(
            json |> member "balances" |> index 0 |> member "value" |> to_string
            |> Int.of_string)
    | Error _ when tries > 0 ->
        (* not listening yet *)
        let%bind () = after (Time.Span.of_sec 1.) in
        ask (tries - 1)
    | Error e ->
        Error.raise e
  in
  ask 60

let fork_balance server_uri () =
  let s, alice = scenario () in
  B.Db.with_fresh ~server_uri ~name:"test_rosetta_fork_balance" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind (_ : B.built) = B.materialize s db in
      Deferred.ok
      @@ with_graphql_stub (fun graphql_uri ->
             with_rosetta ~archive_uri:db.uri ~graphql_uri (fun client ->
                 let open Deferred.Let_syntax in
                 let%bind before = balance client alice ~height:2 in
                 let%map after = balance client alice ~height:5 in
                 Alcotest.(check int)
                   "before the fork: the pre-fork state" pre_fork_balance before ;
                 Alcotest.(check int)
                   "after the fork: the fork's genesis balance"
                   fork_genesis_balance after ) ) )

let () =
  let uri = B.Db.test_server_uri () in
  let run f () = Thread_safe.block_on_async_exn (f uri) |> Or_error.ok_exn in
  Alcotest.run "rosetta_fork_balance"
    [ ( "rosetta_fork_balance"
      , [ Alcotest.test_case
            "an account untouched since the fork: its genesis balance" `Quick
            (run fork_balance)
        ] )
    ]
