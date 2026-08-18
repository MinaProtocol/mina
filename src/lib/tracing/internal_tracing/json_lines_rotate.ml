(* NOTE: This code is based on src/lib/logger/file_system/logger_file_system.ml *)

open Core
open Core.Unix

let log_perm = 0o644

type t =
  { directory : string
  ; log_filename : string
  ; max_size : int
  ; num_rotate : int
  ; mutable curr_index : int
  ; mutable primary_log : File_descr.t
  ; mutable primary_log_size : int
  }

let create ~directory ~max_size ~log_filename ~num_rotate =
  if not (Result.is_ok (access directory [ `Exists ])) then
    mkdir_p ~perm:0o755 directory ;
  if not (Result.is_ok (access directory [ `Exists; `Read; `Write ])) then
    failwithf "cannot create log files: read/write permissions required on %s"
      directory () ;
  let primary_log_loc = Filename.concat directory log_filename in
  let primary_log_size, mode =
    if Result.is_ok (access primary_log_loc [ `Exists; `Read; `Write ]) then
      let log_stats = stat primary_log_loc in
      (Int64.to_int_exn log_stats.st_size, [ O_RDWR; O_APPEND ])
    else (0, [ O_RDWR; O_CREAT ])
  in
  let primary_log = openfile ~perm:log_perm ~mode primary_log_loc in
  { directory
  ; log_filename
  ; max_size
  ; primary_log
  ; primary_log_size
  ; num_rotate
  ; curr_index = 0
  }

let rotate t =
  let primary_log_loc = Filename.concat t.directory t.log_filename in
  let secondary_log_filename =
    t.log_filename ^ "." ^ string_of_int t.curr_index
  in
  if t.curr_index < t.num_rotate then t.curr_index <- t.curr_index + 1
  else t.curr_index <- 0 ;
  let secondary_log_loc = Filename.concat t.directory secondary_log_filename in
  close t.primary_log ;
  rename ~src:primary_log_loc ~dst:secondary_log_loc ;
  t.primary_log <-
    openfile ~perm:log_perm ~mode:[ O_RDWR; O_CREAT ] primary_log_loc ;
  t.primary_log_size <- 0

let write_lines t lines =
  let str = lines ^ "\n" in
  let len = String.length str in
  if write t.primary_log ~buf:(Bytes.of_string str) ~len <> len then
    printf "unexpected error writing to persistent log" ;
  t.primary_log_size <- t.primary_log_size + len

let transport t lines =
  if t.primary_log_size > t.max_size then (
    (* Log the rotation event so that external event stream consumers are aware of it *)
    write_lines t
      (Yojson.Safe.to_string ~std:true
         (`Assoc [ ("rotated_log_end", `Float (Unix.gettimeofday ())) ]) ) ;
    rotate t ;
    write_lines t
      (Yojson.Safe.to_string ~std:true
         (`Assoc [ ("rotated_log_start", `Float (Unix.gettimeofday ())) ]) ) ) ;
  write_lines t lines
