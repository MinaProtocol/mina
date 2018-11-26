
let restore_cwd_and_execve prog argv ~env =
  let env = Env.to_unix env in
  let argv = Array.of_list argv in
  Sys.chdir (Path.External.to_string Path.External.initial_cwd);
  if Sys.win32 then
    let pid = Unix.create_process_env prog argv env
                Unix.stdin Unix.stdout Unix.stderr
    in
    match snd (Unix.waitpid [] pid) with
    | WEXITED   0 -> ()
    | WEXITED   n -> exit n
    | WSIGNALED _ -> exit 255
    | WSTOPPED  _ -> assert false
  else begin
    ignore (Unix.sigprocmask SIG_SETMASK [] : int list);
    Unix.execve prog argv env
  end
