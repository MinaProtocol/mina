open Core

(* Read RSS (Resident Set Size) from /proc/<pid>/status *)
let read_rss_kb pid_opt =
  try
    let proc_file =
      match pid_opt with
      | None ->
          "/proc/self/status"
      | Some pid ->
          Printf.sprintf "/proc/%d/status" (Pid.to_int pid)
    in
    let ic = In_channel.create proc_file in
    let rec find_vmrss () =
      let%bind.Option line = In_channel.input_line ic in
      match Option.try_with (fun () -> Scanf.sscanf line "VmRSS: %f" Fn.id) with
      | None ->
          find_vmrss ()
      | Some kb ->
          Some kb
    in
    let result = find_vmrss () in
    In_channel.close ic ; result
  with _ -> None
