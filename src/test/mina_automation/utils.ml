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

(** [get_memory_usage_mb_of_process_family process_name] returns the total memory usage
  in megabytes for all processes belonging to the specified user [process_name].
  
  This function executes the 'ps' command to retrieve RSS (Resident Set Size) values
  for all processes owned by the given user, sums them up, and converts the result
  from kilobytes to megabytes.
  
  @param process_name The username whose processes' memory usage should be calculated
  @return A deferred float representing the total memory usage in megabytes
  
  @raise If the 'ps' command fails to execute, an exception will be raised by [Util.run_cmd_exn] *)
let get_memory_usage_mb_of_process_family process_name =
  let%bind output =
    Util.run_cmd_exn "." "ps" [ "-u"; process_name; "-o"; "rss=" ]
  in
  let lines = String.split_lines output in
  let memory_usages =
    List.filter_map lines ~f:(fun line ->
        try Some (String.strip line |> Int.of_string) with _ -> None )
  in
  let total_memory = List.fold memory_usages ~init:0 ~f:( + ) in
  let total_memory_mb = Float.of_int total_memory /. 1024.0 in
  Deferred.return total_memory_mb
