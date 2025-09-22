(* processor.ml -- database processing for archive node *)

(* For each table in the archive database schema, a
   corresponding module contains code to read from and write to
   that table. The module defines a type `t`, a record with fields
   corresponding to columns in the table; typically, the `id` column
   that does not have an associated field.

   The more recently written modules use the Mina_caqti library to
   construct the SQL for those queries. For consistency and
   simplicity, the older modules should probably be refactored to use
   Mina_caqti.

   Module `Account_identifiers` is a good example of how Mina_caqti
   can be used.

   After these table-related modules, there are functions related to
   running the archive process and archive-related apps.
*)

module Archive_rpc = Rpc
open Async
open Core
open Mina_caqti
open Mina_base
open Mina_state
open Mina_block
open Pipe_lib
open Models

let retry ~f ~logger ~error_str retries =
  let rec go retry_count =
    match%bind f () with
    | Error e ->
        if retry_count <= 0 then return (Error e)
        else (
          [%log warn] "Error in %s : $error. Retrying..." error_str
            ~metadata:[ ("error", `String (Caqti_error.show e)) ] ;
          let wait_for = Random.float_range 20. 2000. in
          let%bind () = after (Time.Span.of_ms wait_for) in
          go (retry_count - 1) )
    | Ok res ->
        return (Ok res)
  in
  go retries

let add_block_aux ?(retries = 3) ~logger ~genesis_constants ~pool ~add_block
    ~hash ~delete_older_than ~accounts_accessed ~accounts_created ~tokens_used
    block =
  let state_hash = hash block in

  (* the block itself is added in a single transaction with a transaction block

     once that transaction is committed, we can get a block id

     so we add accounts accessed, accounts created, contained in another
     transaction block
  *)
  let add () =
    [%log info]
      "Populating token owners table for block with state hash $state_hash"
      ~metadata:[ ("state_hash", Mina_base.State_hash.to_yojson state_hash) ] ;
    List.iter tokens_used ~f:(fun (token_id, owner) ->
        match owner with
        | None ->
            ()
        | Some acct_id ->
            Token_owners.add_if_doesn't_exist token_id acct_id ) ;
    Mina_caqti.Pool.use
      (fun (module Conn : Mina_caqti.CONNECTION) ->
        let%bind res =
          let open Deferred.Result.Let_syntax in
          let%bind () = Conn.start () in
          [%log info] "Attempting to add block data for $state_hash"
            ~metadata:
              [ ("state_hash", Mina_base.State_hash.to_yojson state_hash) ] ;
          let%bind block_id =
            O1trace.thread "archive_processor.add_block"
            @@ fun () ->
            Metrics.time ~label:"add_block" ~logger
            @@ fun () -> add_block (module Conn : Mina_caqti.CONNECTION) block
          in
          (* if an existing block has a parent hash that's for the block just added,
             set its parent id
          *)
          let%bind () =
            Block.set_parent_id_if_null
              (module Conn)
              ~parent_hash:(hash block) ~parent_id:block_id
          in
          (* update chain status for existing blocks *)
          let%bind () =
            Metrics.time ~label:"update_chain_status" ~logger (fun () ->
                Block.update_chain_status
                  (module Conn)
                  ~logger ~genesis_constants ~block_id )
          in
          let%bind () =
            match delete_older_than with
            | Some num_blocks ->
                Block.delete_if_older_than ~num_blocks (module Conn)
            | None ->
                return ()
          in
          return block_id
        in
        match res with
        | Error e as err ->
            (*Error in the current transaction*)
            [%log warn]
              "Error when adding block data to the database, rolling back \
               transaction: $error"
              ~metadata:[ ("error", `String (Caqti_error.show e)) ] ;
            let%map _ = Conn.rollback () in
            err
        | Ok block_id -> (
            match%bind Conn.commit () with
            | Error err ->
                [%log warn]
                  "Could not commit data for block with state hash \
                   $state_hash, rolling back transaction: $error"
                  ~metadata:
                    [ ("state_hash", State_hash.to_yojson state_hash)
                    ; ("error", `String (Caqti_error.show err))
                    ] ;
                Conn.rollback ()
            | Ok () -> (
                (* added block data, now add accounts accessed *)
                [%log info]
                  "Added block with state hash $state_hash to archive database"
                  ~metadata:
                    [ ("state_hash", State_hash.to_yojson state_hash)
                    ; ( "num_accounts_accessed"
                      , `Int (List.length accounts_accessed) )
                    ] ;
                let%bind.Deferred.Result () = Conn.start () in
                match%bind
                  Mina_caqti.Pool.use
                    (fun (module Conn : Mina_caqti.CONNECTION) ->
                      Accounts_accessed.add_accounts_if_don't_exist
                        (module Conn)
                        block_id accounts_accessed )
                    pool
                with
                | Error err ->
                    [%log error]
                      "Could not add accounts accessed in block with state \
                       hash $state_hash to archive database: $error"
                      ~metadata:
                        [ ("state_hash", State_hash.to_yojson state_hash)
                        ; ("error", `String (Caqti_error.show err))
                        ] ;
                    Conn.rollback ()
                | Ok _block_and_account_ids -> (
                    [%log info]
                      "Added accounts accessed for block with state hash \
                       $state_hash to archive database"
                      ~metadata:
                        [ ("state_hash", State_hash.to_yojson state_hash)
                        ; ( "num_accounts_accessed"
                          , `Int (List.length accounts_accessed) )
                        ] ;
                    match%bind
                      Mina_caqti.Pool.use
                        (fun (module Conn : Mina_caqti.CONNECTION) ->
                          Accounts_created.add_accounts_created_if_don't_exist
                            (module Conn)
                            block_id accounts_created )
                        pool
                    with
                    | Ok _block_and_public_key_ids ->
                        [%log info]
                          "Added accounts created for block with state hash \
                           $state_hash to archive database"
                          ~metadata:
                            [ ( "state_hash"
                              , Mina_base.State_hash.to_yojson (hash block) )
                            ; ( "num_accounts_created"
                              , `Int (List.length accounts_created) )
                            ] ;
                        Conn.commit ()
                    | Error err ->
                        [%log warn]
                          "Could not add accounts created in block with state \
                           hash $state_hash to archive database: $error"
                          ~metadata:
                            [ ("state_hash", State_hash.to_yojson state_hash)
                            ; ("error", `String (Caqti_error.show err))
                            ] ;

                        Conn.rollback () ) ) ) )
      pool
  in
  retry ~f:add ~logger ~error_str:"add_block_aux" retries

(* used by `archive_blocks` app *)
let add_block_aux_precomputed ~proof_cache_db ~constraint_constants ~logger
    ?retries ~pool ~delete_older_than block =
  add_block_aux ~logger ?retries ~pool ~delete_older_than
    ~add_block:
      (Block.add_from_precomputed ~logger ~proof_cache_db ~constraint_constants)
    ~hash:(fun block ->
      (block.Precomputed.protocol_state |> Protocol_state.hashes).state_hash )
    ~accounts_accessed:block.Precomputed.accounts_accessed
    ~accounts_created:block.Precomputed.accounts_created
    ~tokens_used:block.Precomputed.tokens_used block

(* used by `archive_blocks` app *)
let add_block_aux_extensional ~proof_cache_db ~logger ~signature_kind ?retries
    ~pool ~delete_older_than block =
  add_block_aux ~logger ?retries ~pool ~delete_older_than
    ~add_block:
      (Block.add_from_extensional ~logger ~proof_cache_db
         ~v1_transaction_hash:false ~signature_kind )
    ~hash:(fun (block : Extensional.Block.t) -> block.state_hash)
    ~accounts_accessed:block.Extensional.Block.accounts_accessed
    ~accounts_created:block.Extensional.Block.accounts_created
    ~tokens_used:block.Extensional.Block.tokens_used block

(* receive blocks from a daemon, write them to the database *)
let run pool reader ~proof_cache_db ~genesis_constants ~constraint_constants
    ~logger ~delete_older_than : unit Deferred.t =
  Strict_pipe.Reader.iter reader ~f:(function
    | Diff.Transition_frontier
        (Breadcrumb_added
          { block; accounts_accessed; accounts_created; tokens_used; _ } ) -> (
        let add_block =
          Block.add_if_doesn't_exist ~logger ~constraint_constants
        in
        let hash = State_hash.With_state_hashes.state_hash in
        let block =
          With_hash.map
            ~f:(Mina_block.write_all_proofs_to_disk ~proof_cache_db)
            block
        in
        match%bind
          add_block_aux ~logger ~genesis_constants ~pool ~delete_older_than
            ~hash ~add_block ~accounts_accessed ~accounts_created ~tokens_used
            block
        with
        | Error e ->
            let state_hash = hash block in
            [%log warn]
              ~metadata:
                [ ("state_hash", State_hash.to_yojson state_hash)
                ; ("error", `String (Caqti_error.show e))
                ]
              "Failed to archive block with state hash $state_hash, see $error" ;
            Deferred.unit
        | Ok () ->
            Deferred.unit )
    | Transition_frontier _ ->
        Deferred.unit )

(* [add_genesis_accounts] is called when starting the archive process *)
let add_genesis_accounts ~logger ~(runtime_config_opt : Runtime_config.t option)
    ~(genesis_constants : Genesis_constants.t) ~chunks_length
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) pool =
  match runtime_config_opt with
  | None ->
      Deferred.unit
  | Some runtime_config -> (
      let%bind precomputed_values =
        match%map
          Genesis_ledger_helper.init_from_config_file ~logger
            ~proof_level:Genesis_constants.Compiled.proof_level
            ~genesis_constants ~constraint_constants runtime_config
            ~cli_proof_level:None ~genesis_backing_type:Stable_db
        with
        | Ok (precomputed_values, _) ->
            precomputed_values
        | Error err ->
            failwithf "Could not get precomputed values, error: %s"
              (Error.to_string_hum err) ()
      in
      let ledger =
        Precomputed_values.genesis_ledger precomputed_values |> Lazy.force
      in
      let%bind account_ids =
        let%map account_id_set = Mina_ledger.Ledger.accounts ledger in
        Account_id.Set.to_list account_id_set
      in
      let genesis_block =
        let With_hash.{ data = block; hash = the_hash }, _ =
          Mina_block.genesis ~precomputed_values
        in
        With_hash.{ data = block; hash = the_hash }
      in
      let add_accounts () =
        let%bind.Deferred.Result ledger_hash, genesis_block_id =
          Mina_caqti.Pool.use
            (fun (module Conn : Mina_caqti.CONNECTION) ->
              let%bind.Deferred.Result genesis_block_id =
                Block.add_if_doesn't_exist
                  (module Conn)
                  ~logger
                  ~constraint_constants:precomputed_values.constraint_constants
                  genesis_block
              in
              let%bind.Deferred.Result { ledger_hash; _ } =
                Block.load (module Conn) ~id:genesis_block_id
              in
              return (Ok (ledger_hash, genesis_block_id)) )
            pool
        in
        let db_ledger_hash = Ledger_hash.of_base58_check_exn ledger_hash in
        let actual_ledger_hash = Mina_ledger.Ledger.merkle_root ledger in
        if Ledger_hash.equal db_ledger_hash actual_ledger_hash then
          [%log info]
            "Archived genesis block ledger hash equals actual genesis ledger \
             hash"
            ~metadata:
              [ ("ledger_hash", Ledger_hash.to_yojson actual_ledger_hash) ]
        else (
          [%log error]
            "Archived genesis block ledger hash different than actual genesis \
             ledger hash"
            ~metadata:
              [ ("archived_ledger_hash", Ledger_hash.to_yojson db_ledger_hash)
              ; ("actual_ledger_hash", Ledger_hash.to_yojson actual_ledger_hash)
              ] ;
          exit 1 ) ;
        let open Deferred.Let_syntax in
        let genesis_accounts_count = List.length account_ids in
        [%log info] "Archiving genesis accounts"
          ~metadata:[ ("count", `Int genesis_accounts_count) ] ;

        let acccount_with_index_of_id ~ledger acct_id =
          match Mina_ledger.Ledger.location_of_account ledger acct_id with
          | None ->
              [%log error] "Could not get location for account"
                ~metadata:[ ("account_id", Account_id.to_yojson acct_id) ] ;
              failwith "Could not get location for genesis account"
          | Some loc -> (
              let index =
                Mina_ledger.Ledger.index_of_account_exn ledger acct_id
              in
              match Mina_ledger.Ledger.get ledger loc with
              | None ->
                  [%log error] "Could not get account, given a location"
                    ~metadata:[ ("account_id", Account_id.to_yojson acct_id) ] ;
                  failwith "Could not get genesis account, given a location"
              | Some acct ->
                  (index, acct) )
        in
        let%bind list_of_results =
          List.map account_ids ~f:(fun acct_id ->
              acccount_with_index_of_id ~ledger acct_id )
          |> List.chunks_of ~length:chunks_length
          |> Deferred.List.mapi ~f:(fun i batch ->
                 match%bind
                   Pool.use
                     (fun (module Conn : CONNECTION) ->
                       Accounts_accessed.add_accounts_if_don't_exist
                         (module Conn)
                         genesis_block_id batch )
                     pool
                 with
                 | Ok _ ->
                     [%log trace] "Archived batch of account %d of %d"
                       (i * chunks_length) genesis_accounts_count ;
                     return (Result.Ok ())
                 | Error err ->
                     [%log error] "Could not add batch of genesis account"
                       ~metadata:
                         [ ("batch number", `Int i)
                         ; ("error", `String (Caqti_error.show err))
                         ] ;
                     return (Result.Error err) )
        in

        return
          ( List.find list_of_results ~f:(fun result -> Result.is_error result)
          |> Option.value ~default:(Result.Ok ()) )
      in
      match%map
        retry ~f:add_accounts ~logger ~error_str:"add_genesis_accounts" 3
      with
      | Error e ->
          [%log warn] "genesis accounts could not be added"
            ~metadata:[ ("error", `String (Caqti_error.show e)) ] ;
          failwith "Failed to add genesis accounts"
      | Ok () ->
          () )

let serve_metrics_server ~logger ~metrics_server_port ~missing_blocks_width
    ~block_window_duration_ms pool =
  match metrics_server_port with
  | None ->
      return ()
  | Some port ->
      let missing_blocks_width =
        Option.value ~default:Metrics.default_missing_blocks_width
          missing_blocks_width
      in
      let%map metric_server =
        Mina_metrics.Archive.create_archive_server ~port ~logger ()
      in
      let interval =
        Time.Span.of_ms @@ Float.of_int (block_window_duration_ms * 2)
      in
      let serve () =
        let%bind () =
          Metrics.update pool metric_server ~logger ~missing_blocks_width
        in
        after interval
      in
      Deferred.forever () serve

(* for running the archive process *)
let setup_server ~proof_cache_db ~(genesis_constants : Genesis_constants.t)
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~metrics_server_port ~logger ~postgres_address ~server_port ~chunks_length
    ~delete_older_than ~runtime_config_opt ~missing_blocks_width ~signature_kind
    =
  let where_to_listen =
    Async.Tcp.Where_to_listen.bind_to All_addresses (On_port server_port)
  in
  let reader, writer = Strict_pipe.create ~name:"archive" Synchronous in
  let precomputed_block_reader, precomputed_block_writer =
    Strict_pipe.create ~name:"precomputed_archive_block" Synchronous
  in
  let extensional_block_reader, extensional_block_writer =
    Strict_pipe.create ~name:"extensional_archive_block" Synchronous
  in
  let implementations =
    [ Async.Rpc.Rpc.implement Archive_rpc.t (fun () archive_diff ->
          Strict_pipe.Writer.write writer archive_diff )
    ; Async.Rpc.Rpc.implement Archive_rpc.precomputed_block
        (fun () precomputed_block ->
          Strict_pipe.Writer.write precomputed_block_writer precomputed_block )
    ; Async.Rpc.Rpc.implement Archive_rpc.extensional_block
        (fun () extensional_block ->
          Strict_pipe.Writer.write extensional_block_writer extensional_block )
    ]
  in
  match Mina_caqti.connect_pool ~max_size:30 postgres_address with
  | Error e ->
      [%log error]
        "Failed to create a Caqti pool for Postgresql, see error: $error"
        ~metadata:[ ("error", `String (Caqti_error.show e)) ] ;
      Deferred.unit
  | Ok pool ->
      let%bind () =
        add_genesis_accounts pool ~logger ~genesis_constants
          ~constraint_constants ~runtime_config_opt ~chunks_length
      in
      run ~proof_cache_db ~constraint_constants ~genesis_constants pool reader
        ~logger ~delete_older_than
      |> don't_wait_for ;
      Strict_pipe.Reader.iter precomputed_block_reader
        ~f:(fun precomputed_block ->
          match%map
            add_block_aux_precomputed ~proof_cache_db ~logger ~pool
              ~genesis_constants ~constraint_constants ~delete_older_than
              precomputed_block
          with
          | Error e ->
              [%log warn]
                "Precomputed block $block could not be archived: $error"
                ~metadata:
                  [ ( "block"
                    , (Protocol_state.hashes precomputed_block.protocol_state)
                        .state_hash |> State_hash.to_yojson )
                  ; ("error", `String (Caqti_error.show e))
                  ]
          | Ok _block_id ->
              () )
      |> don't_wait_for ;
      Strict_pipe.Reader.iter extensional_block_reader
        ~f:(fun extensional_block ->
          match%map
            add_block_aux_extensional ~proof_cache_db ~genesis_constants ~logger
              ~pool ~delete_older_than ~signature_kind extensional_block
          with
          | Error e ->
              [%log warn]
                "Extensional block $block could not be archived: $error"
                ~metadata:
                  [ ( "block"
                    , extensional_block.state_hash |> State_hash.to_yojson )
                  ; ("error", `String (Caqti_error.show e))
                  ]
          | Ok _block_id ->
              () )
      |> don't_wait_for ;
      Deferred.ignore_m
      @@ Tcp.Server.create
           ~on_handler_error:
             (`Call
               (fun _net exn ->
                 [%log error]
                   "Exception while handling TCP server request: $error"
                   ~metadata:
                     [ ("error", `String (Core.Exn.to_string_mach exn))
                     ; ("context", `String "rpc_tcp_server")
                     ] ) )
           where_to_listen
           (fun address reader writer ->
             let address = Socket.Address.Inet.addr address in
             Async.Rpc.Connection.server_with_close reader writer
               ~implementations:
                 (Async.Rpc.Implementations.create_exn ~implementations
                    ~on_unknown_rpc:`Raise )
               ~connection_state:(fun _ -> ())
               ~on_handshake_error:
                 (`Call
                   (fun exn ->
                     [%log error]
                       "Exception while handling RPC server request from \
                        $address: $error"
                       ~metadata:
                         [ ("error", `String (Core.Exn.to_string_mach exn))
                         ; ("context", `String "rpc_server")
                         ; ( "address"
                           , `String (Unix.Inet_addr.to_string address) )
                         ] ;
                     Deferred.unit ) ) )
      |> don't_wait_for ;
      (*Update archive metrics*)
      serve_metrics_server ~logger ~metrics_server_port ~missing_blocks_width
        ~block_window_duration_ms:constraint_constants.block_window_duration_ms
        pool
      |> don't_wait_for ;
      [%log info] "Archive process ready. Clients can now connect" ;
      Async.never ()

module For_test = struct
  let assert_parent_exist ~parent_id ~parent_hash conn =
    let open Deferred.Result.Let_syntax in
    match parent_id with
    | Some id ->
        let%map Block.{ state_hash = actual; _ } = Block.load conn ~id in
        [%test_result: string]
          ~expect:(parent_hash |> State_hash.to_base58_check)
          actual
    | None ->
        failwith "Failed to find parent block in database"
end
