open Common

let sock =
  let fn = Filename.temp_file "dune-test" ".socket" in
  Unix.unlink fn;
  Unix.putenv env_var fn;
  at_exit (fun () -> try Unix.unlink fn with _ -> ());
  let fd = Unix.socket PF_UNIX SOCK_STREAM 0 in
  Unix.bind fd (ADDR_UNIX fn);
  Unix.listen fd 5;
  fd

type client =
  { ic : in_channel
  ; oc : out_channel
  }

let wait_for_client () =
  let fd, _ = Unix.accept sock in
  { ic = Unix.in_channel_of_descr fd
  ; oc = Unix.out_channel_of_descr fd
  }

let dune, debug =
  match Sys.argv |> Array.to_list with
  | [_; dune; "debug"] -> dune, true
  | [_; dune] -> dune, false
  | _ -> failwith "invalid command line arguments"

let () = assert (Sys.command "dune clean --root ." = 0)

let test_done = ref false
let dune_fdr, dune_fdw = Unix.pipe ()
let dune_pid =
  let out = if debug then Unix.stdout else dune_fdw in
  Unix.create_process
    dune [|"dune"; "build"; "-w"; "y"; "--root"; "."|]
    Unix.stdin out out
let () = Unix.close dune_fdw
let dune_thread =
  Thread.create (fun () ->
    let ic = Unix.in_channel_of_descr dune_fdr in
    let lines = ref [] in
    try
      while true do
        lines := input_line ic :: !lines
      done
    with exn ->
      if not !test_done then
        Printf.eprintf "----------\n\
                        Dune process exited.\n\
                        Exception: %s\n\
                        Output:\n\
                        %s\n%!"
          (Printexc.to_string exn)
          (List.rev !lines |> String.concat "\n"))
    ()

let log fmt = Printf.eprintf (fmt ^^ "\n%!")

let () =
  if debug then
    ignore (
      Thread.create (fun () ->
        Unix.sleep 2;
        Unix.kill dune_pid Sys.sigterm;
        exit 1)
        () : Thread.t)

let () =
  Sys.set_signal Sys.sigpipe (Signal_handle ignore);
  log "writing 1 to x";
  write_file "x" "1";
  log "waiting for client1";
  let client1 = wait_for_client () in
  log "client1 connected";
  log "writing 2 to x";
  write_file "x" "2";
  log "waiting for client2";
  let client2 = wait_for_client () in
  log "client2 connected";
  log "telling client2 to go";
  Printf.fprintf client2.oc "go\n%!";
  log "waiting for client2 to be done";
  assert (input_line client2.ic = "done");
  log "client2 done";
  begin
    try
      log "telling client1 to go";
      Printf.fprintf client1.oc "go\n%!";
      log "waiting for client1 to be done";
      assert (input_line client1.ic = "done");
      log "client1 done";
    with _ ->
      log "client1 is dead";
  end;
  test_done := true;
  log "killing dune";
  Unix.kill dune_pid Sys.sigterm;
  Unix.close dune_fdr;
  log "waiting for dune";
  ignore (Unix.waitpid [] dune_pid : _ * _);
  Printf.printf "==========\n%s.\n%!"
    (match read_file "_build/default/y" with
     | "2" -> "Success"
     | s   -> "Failure: " ^ s)
