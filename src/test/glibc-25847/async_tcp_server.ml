open! Core
open! Async

let n_bg_fibers =
  Option.value_map (Sys.getenv "N_BG_FIBERS") ~default:0 ~f:Int.of_string

let completions = ref 0

let in_thread_completions = ref 0

(* Background In_thread.run fibers (optional, for extra contention) *)
let in_thread_fiber () =
  Deferred.forever () (fun () ->
      let%map () = In_thread.run (fun () -> ()) in
      in_thread_completions := !in_thread_completions + 1 )

(* Monitor: print throughput every second *)
let monitor () =
  let last_comp = ref 0 in
  let last_it = ref 0 in
  let cycle = ref 0 in
  Deferred.forever () (fun () ->
      let%map () = Clock.after (Time_float.Span.of_sec 1.0) in
      incr cycle ;
      let c = !completions in
      let it = !in_thread_completions in
      let conn_rate = c - !last_comp in
      let it_rate = it - !last_it in
      (* Each connection generates ~4 In_thread ops on the server side:
         2x fcntl_getfl + shutdown + close *)
      Core.printf
        "alive: cycle=%d connections=%d(+%d/s ~%d in_thread_ops/s) \
         bg_in_thread=%d(+%d/s)\n\
         %!"
        !cycle c conn_rate (conn_rate * 4) it it_rate ;
      last_comp := c ;
      last_it := it )

let () =
  don't_wait_for
    ( Core.printf "Async TCP server for glibc #25847 reproducer\n" ;
      Core.printf
        "Background In_thread fibers: %d (set N_BG_FIBERS to change)\n"
        n_bg_fibers ;
      Core.printf
        "Each connection = ~4 In_thread ops on server side (fcntl_getfl, \
         shutdown, close)\n" ;
      Core.printf "If output stops, glibc bug #25847 has been triggered.\n\n%!" ;
      (* Start TCP echo server on ephemeral port *)
      let%bind server =
        Tcp.Server.create ~on_handler_error:`Ignore
          (Tcp.Where_to_listen.of_port 0) (fun _addr reader writer ->
            completions := !completions + 1 ;
            match%bind Reader.read_line reader with
            | `Ok line ->
                Writer.write_line writer line ;
                Writer.close writer
            | `Eof ->
                Deferred.unit )
      in
      let port = Tcp.Server.listening_on server in
      Core.printf "Server listening on port %d\n%!" port ;
      (* Start optional background In_thread fibers *)
      for _ = 1 to n_bg_fibers do
        in_thread_fiber ()
      done ;
      (* Start monitor *)
      monitor () ;
      Deferred.never () ) ;
  never_returns (Scheduler.go ())
