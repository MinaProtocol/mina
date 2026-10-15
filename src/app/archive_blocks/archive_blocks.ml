(* archive_blocks.ml *)

open Core_kernel
open Async
open Archive_lib

(* [pg_prepared_statements] lists only the prepared statements of the session
   that runs the query. With a one-connection pool (CAQTI_POOL_MAX_SIZE=1,
   CAQTI_POOL_MAX_USE_COUNT=none) that session is the one that writes the
   blocks, so these counts show whether its requests are built once. *)
let prepared_statements_count_req =
  Mina_caqti.find_req Caqti_type.unit
    Caqti_type.(t2 int int)
    "SELECT count(*)::int, count(DISTINCT statement)::int FROM \
     pg_prepared_statements"

let duplicate_prepared_statements_req =
  Mina_caqti.collect_req Caqti_type.unit
    Caqti_type.(t2 int string)
    "SELECT count(*)::int, regexp_replace(statement, '\\s+', ' ', 'g') FROM \
     pg_prepared_statements GROUP BY statement HAVING count(*) > 1 ORDER BY 1 \
     DESC, 2 LIMIT 10"

(* Appends one line per block, [block <n> <statements> <distinct texts>], and
   after the last block one [duplicate <count> <statement>] line for each SQL
   text prepared more than once. *)
let record_prepared_statements ~pool ~logger path =
  let out = Out_channel.create ~append:true path in
  let use f =
    match%map Mina_caqti.Pool.use f pool with
    | Ok x ->
        Some x
    | Error err ->
        [%log error] "Could not read pg_prepared_statements"
          ~metadata:[ ("error", `String (Caqti_error.show err)) ] ;
        None
  in
  let after_block n =
    use (fun (module Conn : Mina_caqti.CONNECTION) ->
        Conn.find prepared_statements_count_req () )
    >>| Option.iter ~f:(fun (total, distinct) ->
            Out_channel.output_lines out
              [ sprintf "block %d %d %d" n total distinct ] ;
            Out_channel.flush out )
  in
  let finish () =
    let%map duplicates =
      use (fun (module Conn : Mina_caqti.CONNECTION) ->
          Conn.collect_list duplicate_prepared_statements_req () )
    in
    Option.iter duplicates ~f:(fun rows ->
        Out_channel.output_lines out
          (List.map rows ~f:(fun (count, statement) ->
               sprintf "duplicate %d %s" count statement ) ) ) ;
    Out_channel.close out
  in
  (after_block, finish)

let main ~genesis_constants ~constraint_constants ~archive_uri ~precomputed
    ~extensional ~success_file ~failure_file ~log_successes
    ~prepared_statements_file ~files () =
  let proof_cache_db = Proof_cache_tag.create_identity_db () in
  let output_file_line path =
    match path with
    | Some path ->
        let file = Out_channel.create ~append:true path in
        fun line -> Out_channel.output_lines file [ line ]
    | None ->
        fun _line -> ()
  in
  let add_to_success_file = output_file_line success_file in
  let add_to_failure_file = output_file_line failure_file in
  let archive_uri = Uri.of_string archive_uri in
  if Bool.equal precomputed extensional then
    failwith "Must provide exactly one of -precomputed and -extensional" ;
  let logger = Logger.create () in
  match Mina_caqti.connect_pool archive_uri with
  | Error e ->
      [%log fatal]
        ~metadata:[ ("error", `String (Caqti_error.show e)) ]
        "Failed to create a Caqti connection to Postgresql" ;
      exit 1
  | Ok pool ->
      [%log info] "Successfully created Caqti connection to Postgresql" ;
      let make_add_block of_yojson add_block_aux ~json ~file =
        match of_yojson json with
        | Ok block -> (
            match%map add_block_aux block with
            | Ok () ->
                if log_successes then
                  [%log info] "Added block" ~metadata:[ ("file", `String file) ] ;
                add_to_success_file file
            | Error err ->
                [%log error] "Error when adding block"
                  ~metadata:
                    [ ("file", `String file)
                    ; ("error", `String (Caqti_error.show err))
                    ] ;
                add_to_failure_file file )
        | Error err ->
            [%log error] "Could not create block from JSON"
              ~metadata:[ ("file", `String file); ("error", `String err) ] ;
            return (add_to_failure_file file)
      in
      let add_precomputed_block =
        (* allow use of older-versioned blocks *)
        let of_yojson json =
          match Mina_block.Precomputed.Stable.of_yojson_to_latest json with
          | Ok block ->
              Ok block
          | Error err ->
              Error (Error.to_string_hum err)
        in
        make_add_block of_yojson
          (Processor.add_block_aux_precomputed ~proof_cache_db
             ~genesis_constants ~constraint_constants ~pool
             ~delete_older_than:None ~logger )
      in
      let add_extensional_block =
        (* allow use of older-versioned blocks *)
        let of_yojson json =
          match
            Archive_lib.Extensional.Block.Stable.of_yojson_to_latest json
          with
          | Ok block ->
              Ok block
          | Error err ->
              Error (Error.to_string_hum err)
        in
        make_add_block of_yojson
          (Processor.add_block_aux_extensional ~proof_cache_db
             ~genesis_constants ~logger ~pool ~delete_older_than:None
             ~signature_kind:Mina_signature_kind.t_DEPRECATED )
      in
      let after_block, finish =
        match prepared_statements_file with
        | Some path ->
            record_prepared_statements ~pool ~logger path
        | None ->
            ((fun _ -> Deferred.unit), fun () -> Deferred.unit)
      in
      let%bind () =
        Deferred.List.iteri files ~f:(fun n file ->
            let%bind () =
              In_channel.with_file file ~f:(fun in_channel ->
                  try
                    let json = Yojson.Safe.from_channel in_channel in
                    if precomputed then add_precomputed_block ~json ~file
                    else if extensional then add_extensional_block ~json ~file
                    else failwith "Internal error, bad flags"
                  with
                  | Yojson.Json_error err ->
                      [%log error] "Could not parse JSON from file"
                        ~metadata:
                          [ ("file", `String file); ("error", `String err) ] ;
                      return (add_to_failure_file file)
                  | exn ->
                      (* should be unreachable *)
                      [%log error] "Internal error when processing file"
                        ~metadata:
                          [ ("file", `String file)
                          ; ("error", `String (Exn.to_string exn))
                          ] ;
                      return (add_to_failure_file file) )
            in
            after_block (n + 1) )
      in
      finish ()

let () =
  Command.(
    let (module G) = Genesis_constants.profiled () in
    let genesis_constants = G.genesis_constants in
    let constraint_constants = G.constraint_constants in
    run
      (let open Let_syntax in
      async ~summary:"Write blocks to an archive database"
        (let%map archive_uri =
           Param.flag "--archive-uri" ~aliases:[ "archive-uri" ]
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER@localhost:5432/archiver)"
             Param.(required string)
         and precomputed =
           Param.(flag "--precomputed" ~aliases:[ "precomputed" ] no_arg)
             ~doc:"Blocks are in precomputed format"
         and extensional =
           Param.(flag "--extensional" ~aliases:[ "extensional" ] no_arg)
             ~doc:"Blocks are in extensional format"
         and success_file =
           Param.flag "--successful-files" ~aliases:[ "successful-files" ]
             ~doc:
               "PATH Appends the list of files that were processed successfully"
             (Flag.optional Param.string)
         and failure_file =
           Param.flag "--failed-files" ~aliases:[ "failed-files" ]
             ~doc:"PATH Appends the list of files that failed to be processed"
             (Flag.optional Param.string)
         and log_successes =
           Param.flag "--log-successful" ~aliases:[ "log-successful" ]
             ~doc:
               "true/false Whether to log messages for files that were \
                processed successfully"
             (Flag.optional_with_default true Param.bool)
         and prepared_statements_file =
           Param.flag "--prepared-statements-file"
             ~doc:
               "PATH Append the prepared-statement count of the database \
                session after each block (meaningful only with a \
                one-connection pool, CAQTI_POOL_MAX_SIZE=1)"
             (Flag.optional Param.string)
         and files = Param.anon Anons.(sequence ("FILES" %: Param.string)) in
         main ~genesis_constants ~constraint_constants ~archive_uri ~precomputed
           ~extensional ~success_file ~failure_file ~log_successes
           ~prepared_statements_file ~files )))
