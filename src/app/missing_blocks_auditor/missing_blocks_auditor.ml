(* missing_blocks_auditor.ml -- report missing blocks from an archive db *)

open Core_kernel
open Async

let main ~archive_uri () =
  let logger = Logger.create () in
  let archive_uri = Uri.of_string archive_uri in
  match Caqti_async.connect_pool ~max_size:128 archive_uri with
  | Error e ->
      [%log fatal]
        ~metadata:[ ("error", `String (Caqti_error.show e)) ]
        "Failed to create a Caqti pool for Postgresql" ;
      exit 1
  | Ok pool ->
      [%log info] "Successfully created Caqti pool for Postgresql" ;
      [%log info] "Querying missing blocks" ;
      let%bind missing_blocks_raw =
        match%bind
          Caqti_async.Pool.use (fun db -> Sql.Unparented_blocks.run db ()) pool
        with
        | Ok blocks ->
            return blocks
        | Error msg ->
            [%log error] "Error getting missing blocks"
              ~metadata:[ ("error", `String (Caqti_error.show msg)) ] ;
            exit 1
      in
      (* filter out genesis block *)
      let missing_blocks =
        List.filter missing_blocks_raw ~f:(fun (_, _, height, _) -> height <> 1)
      in
      if List.is_empty missing_blocks then
        [%log info] "There are no missing blocks in the archive db"
      else
        List.iter missing_blocks
          ~f:(fun (block_id, state_hash, height, parent_hash) ->
            if height > 1 then
              [%log info] "Block has no parent in archive db"
                ~metadata:
                  [ ("block_id", `Int block_id)
                  ; ("state_hash", `String state_hash)
                  ; ("height", `Int height)
                  ; ("parent_hash", `String parent_hash)
                  ; ("parent_height", `Int (height - 1))
                  ]) ;
      [%log info] "Querying for gaps in chain statuses" ;
      let%bind highest_canonical =
        match%bind
          Caqti_async.Pool.use
            (fun db -> Sql.Chain_status.run_highest_canonical db ())
            pool
        with
        | Ok height ->
            return height
        | Error msg ->
            [%log error] "Error getting greatest height of canonical blocks"
              ~metadata:[ ("error", `String (Caqti_error.show msg)) ] ;
            exit 1
      in
      let%bind pending_below =
        match%bind
          Caqti_async.Pool.use
            (fun db ->
              Sql.Chain_status.run_count_pending_below db highest_canonical)
            pool
        with
        | Ok count ->
            return count
        | Error msg ->
            [%log error] "Error getting greatest height of canonical blocks"
              ~metadata:[ ("error", `String (Caqti_error.show msg)) ] ;
            exit 1
      in
      if Int64.equal pending_below Int64.zero then
        [%log info] "There are no gaps in the chain statuses"
      else
        [%log info]
          "There are $num_pending_blocks_below pending blocks lower than the \
           highest canonical block"
          ~metadata:
            [ ( "max_height_canonical_block"
              , `String (Int64.to_string highest_canonical) )
            ; ( "num_pending_blocks_below"
              , `String (Int64.to_string pending_below) )
            ] ;
      return ()

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async
        ~summary:"Report state hashes of blocks missing from archive database"
        (let%map archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER@localhost:5432/archiver)"
             Param.(required string)
         in
         main ~archive_uri)))
