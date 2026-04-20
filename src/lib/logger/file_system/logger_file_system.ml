open Core

let log_perm = 0o644

module Timestamped_logrotate = struct
  open Core.Unix

  type t =
    { directory : string
    ; log_filename : string
    ; max_size : int
    ; num_rotate : int
    ; mutable primary_log : File_descr.t
    ; mutable primary_log_size : int
    ; mutable primary_log_start_time : Time.t
    }

  let format_timestamp t =
    Time.format t "%Y-%m-%dT%H:%M:%SZ" ~zone:Time.Zone.utc

  let create ~directory ~max_size ~log_filename ~num_rotate =
    if not (Result.is_ok (access directory [ `Exists ])) then
      mkdir_p ~perm:0o755 directory ;
    if not (Result.is_ok (access directory [ `Exists; `Read; `Write ])) then
      failwithf "cannot create log files: read/write permissions required on %s"
        directory () ;
    let primary_log_loc = Filename.concat directory log_filename in
    let primary_log_size, mode, start_time =
      if Result.is_ok (access primary_log_loc [ `Exists; `Read; `Write ]) then
        let log_stats = stat primary_log_loc in
        ( Int64.to_int_exn log_stats.st_size
        , [ O_RDWR; O_APPEND ]
        , Time.of_span_since_epoch (Time.Span.of_sec log_stats.st_mtime) )
      else (0, [ O_RDWR; O_CREAT ], Time.now ())
    in
    let primary_log = openfile ~perm:log_perm ~mode primary_log_loc in
    { directory
    ; log_filename
    ; max_size
    ; primary_log
    ; primary_log_size
    ; num_rotate
    ; primary_log_start_time = start_time
    }

  let collect_rotated_logs t =
    let prefix = t.log_filename ^ "." in
    Core.Sys.readdir t.directory
    |> Array.to_list
    |> List.filter ~f:(fun name -> String.is_prefix name ~prefix)
    |> List.sort ~compare:String.compare

  let cleanup_old_logs t =
    let rotated = collect_rotated_logs t in
    let num_to_delete = List.length rotated - t.num_rotate in
    if num_to_delete > 0 then
      List.take rotated num_to_delete
      |> List.iter ~f:(fun name -> unlink (Filename.concat t.directory name))

  let find_unique_path base_path =
    let rec go n =
      let candidate =
        if n = 0 then base_path else base_path ^ "." ^ string_of_int n
      in
      if Result.is_ok (access candidate [ `Exists ]) then go (n + 1)
      else candidate
    in
    go 0

  let rotate t =
    let primary_log_loc = Filename.concat t.directory t.log_filename in
    let suffix = format_timestamp t.primary_log_start_time in
    let base_loc = primary_log_loc ^ "." ^ suffix in
    let secondary_log_loc = find_unique_path base_loc in
    close t.primary_log ;
    rename ~src:primary_log_loc ~dst:secondary_log_loc ;
    t.primary_log <-
      openfile ~perm:log_perm ~mode:[ O_RDWR; O_CREAT ] primary_log_loc ;
    t.primary_log_size <- 0 ;
    t.primary_log_start_time <- Time.now () ;
    cleanup_old_logs t

  let transport t str =
    if t.primary_log_size > t.max_size then rotate t ;
    let str = str ^ "\n" in
    let len = String.length str in
    if write t.primary_log ~buf:(Bytes.of_string str) ~len <> len then
      printf "unexpected error writing to persistent log" ;
    t.primary_log_size <- t.primary_log_size + len
end

let timestamped_logrotate ~directory ~log_filename ~max_size ~num_rotate =
  Logger.Transport.create
    (module Timestamped_logrotate)
    (Timestamped_logrotate.create ~directory ~log_filename ~max_size ~num_rotate)

let evergrowing ~log_filename =
  let open Unix in
  Logger.Transport.create
    ( module struct
      type t = File_descr.t

      let transport t str =
        let str = str ^ "\n" in
        let len = String.length str in
        if write t ~buf:(Bytes.of_string str) ~len <> len then
          printf "unexpected error writing to log"
    end )
    (openfile ~perm:log_perm ~mode:[ O_RDWR; O_APPEND; O_CREAT ] log_filename)

let time_pretty_to_string timestamp =
  Time.format timestamp "%Y-%m-%d %H:%M:%S UTC" ~zone:Time.Zone.utc

let () = Logger.Time.set_pretty_to_string time_pretty_to_string
