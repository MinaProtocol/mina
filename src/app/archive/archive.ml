open Core
open Async
open Cli_lib

let command_run =
  let open Command.Let_syntax in
  Command.async
    ~summary:"Run an archive process that can store all of the data of Coda"
    (let%map_open log_json = Flag.Log.json
     and log_level = Flag.Log.level
     and server_port = Flag.Port.Archive.server
     and postgres = Flag.Uri.Archive.postgres in
     fun () ->
       let logger = Logger.create () in
       Stdout_log.setup log_json log_level ;
       Archive_lib.Processor.setup_server ~logger
         ~constraint_constants:Genesis_constants.Constraint_constants.compiled
         ~postgres_address:postgres.value
         ~server_port:
           (Option.value server_port.value ~default:server_port.default))

let time_arg =
  (* Same timezone as Genesis_constants.genesis_state_timestamp. *)
  let default_timezone = Core.Time.Zone.of_utc_offset ~hours:(-8) in
  Command.Arg_type.create
    (Time.of_string_gen ~if_no_timezone:(`Use_this_one default_timezone))

let command_prune =
  let open Command.Let_syntax in
  Command.async ~summary:"Prune old blocks and their transactions"
    (let%map_open height =
       flag "--height" (optional int)
         ~doc:"int Delete blocks with height lower than the given height"
     and num_blocks =
       flag "--num-blocks" (optional int)
         ~doc:
           "int Delete blocks that are more than n blocks lower than the \
            maximum seen block. This argument is ignored if the --height \
            argument is also given"
     and timestamp =
       flag "--timestamp" (optional time_arg)
         ~doc:
           "timestamp Delete blocks that are older than the given timestamp. \
            Format: 2000-00-00 12:00:00+0100"
     and postgres = Flag.Uri.Archive.postgres in
     fun () ->
       let timestamp =
         timestamp
         |> Option.map ~f:Block_time.of_time
         |> Option.map ~f:Block_time.to_int64
       in
       let go () =
         let open Deferred.Result.Let_syntax in
         let%bind ((module Conn) as conn) =
           Caqti_async.connect postgres.value
         in
         let%bind () = Conn.start () in
         match%bind.Async
           let%bind () =
             Archive_lib.Processor.Block.delete_if_older_than ?height
               ?num_blocks ?timestamp conn
           in
           Conn.commit ()
         with
         | Ok () ->
             return ()
         | Error err ->
             let%bind.Async _ = Conn.rollback () in
             Deferred.Result.fail err
       in
       let logger = Logger.create () in
       let cmd_metadata =
         List.filter_opt
           [ Option.map height ~f:(fun v -> ("height", `Int v))
           ; Option.map num_blocks ~f:(fun v -> ("num_blocks", `Int v))
           ; Option.map timestamp ~f:(fun v ->
                 ("timestamp", `String (Int64.to_string v)) ) ]
       in
       match%map.Async go () with
       | Ok () ->
           Logger.info logger ~module_:__MODULE__ ~location:__LOC__
             "Successfully purged blocks." ~metadata:cmd_metadata
       | Error err ->
           Logger.error logger ~module_:__MODULE__ ~location:__LOC__
             "Failed to purge blocks"
             ~metadata:
               (("error", `String (Caqti_error.show err)) :: cmd_metadata))

let commands = [("run", command_run); ("prune", command_prune)]

let () = Command.run (Command.group ~summary:"Archive node commands" commands)
