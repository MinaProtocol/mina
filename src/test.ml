open Core_kernel
open Async_kernel

let addr port =
  Host_and_port.of_string (sprintf "127.0.0.1:%d" (port + 8000))

let swim_client idx =
  printf "Starting client %d\n" idx;
  Swim.Udp.connect
    ~initial_peers:(List.init idx addr)
    ~me:(addr idx)

let make_all () =
  let live_nodes_str client =
    let nodes = Swim.Udp.peers client in
    let strs = List.map nodes ~f:(fun node -> node
      |> Host_and_port.sexp_of_t
      |> Sexp.to_string
    ) in
    String.concat ~sep:"," strs
  in
  Log.current_level := 40;
  let%bind c0 = swim_client 0 in
  let%bind () = Async.after (Time.Span.of_sec 0.2) in
  let%bind c1 = swim_client 1 in
  let%bind () = Async.after (Time.Span.of_sec 0.2) in
  let%bind c2 = swim_client 2 in
  let%bind () = Async.after (Time.Span.of_sec 0.2) in
  let%bind c3 = swim_client 3 in
  print_endline "Waiting a bit so the network can settle";
  let%map () = Async.after (Time.Span.of_sec 6.) in
  print_endline "*********";
  print_endline "*********";
  printf "0: %s; 1: %s; 2: %s; 3: %s\n" (live_nodes_str c0) (live_nodes_str c1) (live_nodes_str c2) (live_nodes_str c3);
  print_endline "*********";
  print_endline "*********";
  ()
;;

don't_wait_for(make_all ());

Async.Scheduler.go ();


