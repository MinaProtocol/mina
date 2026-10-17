(* archive_blocks.ml *)

open Core_kernel
open Async
open Archive_lib

let main ~genesis_constants ~constraint_constants ~archive_uri ~precomputed
    ~extensional ~success_file ~failure_file ~log_successes ~files () =
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
      let format : Block_json.format =
        if precomputed then Precomputed else Extensional
      in
      let add_block ~json ~file =
        match%map
          Block_json.add ~format ~proof_cache_db ~genesis_constants
            ~constraint_constants ~pool ~logger json
        with
        | Ok () ->
            if log_successes then
              [%log info] "Added block" ~metadata:[ ("file", `String file) ] ;
            add_to_success_file file
        | Error (Rejected err) ->
            [%log error] "Error when adding block"
              ~metadata:
                [ ("file", `String file)
                ; ("error", `String (Caqti_error.show err))
                ] ;
            add_to_failure_file file
        | Error (Decode err) ->
            [%log error] "Could not create block from JSON"
              ~metadata:[ ("file", `String file); ("error", `String err) ] ;
            add_to_failure_file file
      in
      Deferred.List.iter files ~f:(fun file ->
          In_channel.with_file file ~f:(fun in_channel ->
              try
                let json = Yojson.Safe.from_channel in_channel in
                add_block ~json ~file
              with
              | Yojson.Json_error err ->
                  [%log error] "Could not parse JSON from file"
                    ~metadata:[ ("file", `String file); ("error", `String err) ] ;
                  return (add_to_failure_file file)
              | exn ->
                  (* should be unreachable *)
                  [%log error] "Internal error when processing file"
                    ~metadata:
                      [ ("file", `String file)
                      ; ("error", `String (Exn.to_string exn))
                      ] ;
                  return (add_to_failure_file file) ) )

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
         and files = Param.anon Anons.(sequence ("FILES" %: Param.string)) in
         main ~genesis_constants ~constraint_constants ~archive_uri ~precomputed
           ~extensional ~success_file ~failure_file ~log_successes ~files )))
