module Env = struct
  type t = string array

  let of_array t = t
end

external sys_exit : int -> 'a = "caml_sys_exit"

let rec file_descr_not_standard fd =
  assert (not Sys.win32);
  if (Obj.magic (fd : Unix.file_descr) : int) >= 3 then
    fd
  else
    file_descr_not_standard (Unix.dup fd)

let safe_close fd =
  try Unix.close fd with Unix.Unix_error _ -> ()

let perform_redirections stdin stdout stderr =
  let stdin = file_descr_not_standard stdin in
  let stdout = file_descr_not_standard stdout in
  let stderr = file_descr_not_standard stderr in
  Unix.dup2 stdin Unix.stdin;
  Unix.dup2 stdout Unix.stdout;
  Unix.dup2 stderr Unix.stderr;
  safe_close stdin;
  safe_close stdout;
  safe_close stderr

let spawn ?env ~prog ~argv
      ?(stdin=Unix.stdin)
      ?(stdout=Unix.stdout)
      ?(stderr=Unix.stderr) () =
  let argv = Array.of_list argv in
  if Sys.win32 then
    match env with
    | None -> Unix.create_process prog argv stdin stdout stderr
    | Some env -> Unix.create_process_env prog argv env stdin stdout stderr
  else
    match Unix.fork () with
    | 0 ->
      begin try
        ignore (Unix.sigprocmask SIG_SETMASK [] : int list);
        perform_redirections stdin stdout stderr;
        match env with
        | None -> Unix.execv prog argv
        | Some env -> Unix.execve prog argv env
      with _ ->
        sys_exit 127
      end
    | pid -> pid

