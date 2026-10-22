(** An archive that answers [Announce_hardfork] and nothing else.

    It implements the archive's own RPC, so daemon code talking to it runs
    unchanged over a real connection. It records every announcement it
    answers. It can fail the exchange a number of times first (the
    implementation raises: no answer, which the daemon retries), and it can
    answer with a refusal (an answer, which the daemon does not retry). *)

open Core
open Async
open Archive_lib.Hardfork_announcement

type t =
  { port : int
  ; answered : Query.t Queue.t
  ; failed_exchanges : int ref
  ; server : (Socket.Address.Inet.t, int) Tcp.Server.t
  }

(** Fails the first [fail_exchanges] calls, then answers [reply]. Listens on
    a port the OS chooses. *)
let start ?(fail_exchanges = 0) ?(reply = Reply.Accepted Recorded) () =
  let answered = Queue.create () in
  let failed_exchanges = ref 0 in
  let implementations =
    Rpc.Implementations.create_exn ~on_unknown_rpc:`Close_connection
      ~implementations:
        [ Rpc.Rpc.implement Archive_lib.Rpc.announce_hardfork (fun () query ->
              if !failed_exchanges < fail_exchanges then (
                incr failed_exchanges ;
                failwith "mock archive fails the exchange" )
              else (
                Queue.enqueue answered query ;
                return reply ) )
        ]
  in
  let%map server =
    Rpc.Connection.serve ~implementations
      ~initial_connection_state:(fun _ _ -> ())
      ~where_to_listen:Tcp.Where_to_listen.of_port_chosen_by_os ()
  in
  { port = Tcp.Server.listening_on server; answered; failed_exchanges; server }

(** The address the daemon takes with --archive-address. *)
let location t =
  { Cli_lib.Flag.Types.name = "--archive-address"
  ; value = Host_and_port.create ~host:"127.0.0.1" ~port:t.port
  }

(** The announcements answered so far, oldest first. *)
let answered t = Queue.to_list t.answered

(** How many exchanges were failed on purpose. *)
let failed_exchanges t = !(t.failed_exchanges)

let stop t = Tcp.Server.close t.server

(** Runs [f] against a fresh mock, and stops the mock afterwards. *)
let with_mock ?fail_exchanges ?reply f =
  let%bind mock = start ?fail_exchanges ?reply () in
  Monitor.protect ~finally:(fun () -> stop mock) (fun () -> f mock)
