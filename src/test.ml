open Core
open Async

let addr port =
  Host_and_port.of_string (sprintf "127.0.0.1:%d" (port + 8000))

let swim_client idx =
  Swim.Udp.connect
    ~initial_peers:(List.init idx addr)
    ~me:(addr idx)

let make_all () =
  let%bind c0 = swim_client 0 in
  let%bind () = Async.after (Time.Span.of_sec 0.2) in
  let%bind c1 = swim_client 1 in
  let%bind () = Async.after (Time.Span.of_sec 0.2) in
  let%map c2 = swim_client 2 in
  ()
;;

don't_wait_for(make_all ());

Async.Scheduler.go ();


