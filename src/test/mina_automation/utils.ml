open Integration_test_lib
open Async
open Core_kernel

let wget ~url ~target = Util.run_cmd_exn "." "wget" [ "-c"; url; "-O"; target ]

let sed ~search ~replacement ~input =
  Util.run_cmd_exn "." "sed"
    [ "-i"; "-e"; Printf.sprintf "s/%s/%s/g" search replacement; input ]

let untar ~archive ~output =
  Util.run_cmd_exn "." "tar" [ "-xf"; archive; "-C"; output ]

let precomputed_blocks_comparator left right =
  let scan_height name = Scanf.sscanf name "%_s@-%d-%_s" Fn.id in
  let left_height = scan_height left in
  let right_height = scan_height right in
  Int.compare left_height right_height

let sort_archive_files files : string list =
  files
  |> List.sort ~compare:(fun left right ->
         precomputed_blocks_comparator left right )

let dedup_and_sort_archive_files files : string list =
  files
  |> List.dedup_and_sort ~compare:(fun left right ->
         precomputed_blocks_comparator left right )

let force_kill process =
  Process.send_signal process Core.Signal.kill ;
  Deferred.map (Process.wait process) ~f:Or_error.return

(** [get_memory_usage_mb pid] retrieves the memory usage in megabytes for the process
  with the given [pid].
  
  This function reads the process memory information from [/proc/pid/statm] and
  extracts the resident set size (RSS) in pages. It then converts this value to
  megabytes by multiplying by the page size (4096 bytes) and dividing by 1024^2.
  
  @param pid The process ID to query memory usage for
  @return [Some mb] where [mb] is the memory usage in megabytes if successful,
      [None] if the process doesn't exist or if there's an error reading
      the memory information *)
let get_memory_usage_mb pid =
  let filename = Printf.sprintf "/proc/%d/statm" pid in
  try
    let line = In_channel.read_all filename |> String.strip in
    match String.split ~on:' ' line with
    | _ :: resident :: _ ->
        let resident_pages = Int64.of_string resident in
        let page_size = Int64.of_int 4096 in
        let bytes = Int64.( * ) resident_pages page_size in
        let mb = Int64.(to_float bytes /. 1024.0 /. 1024.0) in
        Some mb
    | _ ->
        None
  with _ -> None

(** [get_memory_usage_mb_of_user_process process] returns the total memory usage
  in megabytes for all processes matching the specified process name [process].

  This function executes the 'ps' command to retrieve RSS (Resident Set Size) values
  for all processes matching the given process name, sums them up, and converts the result
  from kilobytes to megabytes.

  @param process The process name whose instances' memory usage should be calculated
  @return A deferred float representing the total memory usage in megabytes
  
  @raise If the 'ps' command fails to execute, an exception will be raised by [Util.run_cmd_exn] *)
let get_memory_usage_mb_of_user_process process =
  (* Use 'ps' to get the memory usage of all processes with the given name *)
  (* The command 'ps -eo comm,rss' lists the command name and RSS in kilobytes *)
  (* We filter out empty lines and sum the RSS values for processes matching [process] *)
  (* Example output:
     postgres 29520
     postgres 8544
     postgres 5876
     postgres 10072
     postgres 8612
     postgres 6976
     bash 3488
     ps 3892
  *)
  let%bind output =
    Util.run_cmd_exn "." "ps" [ "-eo"; "comm,rss"; "--no-headers" ]
  in
  let lines = String.split_lines output in
  let total_memory_mb =
    lines
    |> List.filter_map ~f:(fun line ->
           let parts =
             String.split ~on:' ' line
             |> List.filter ~f:(fun s -> not (String.is_empty s))
           in
           match parts with
           | proc_name :: rss_str :: _ when String.equal proc_name process ->
               Some (Int.of_string rss_str)
           | _ ->
               None )
    |> List.fold ~init:0 ~f:( + ) |> Float.of_int
    |> fun kb -> kb /. 1024.0
  in
  Deferred.return total_memory_mb
