open Core
open Async
open Signature_lib
open Mina_base
include Genesis_ledger_helper_lib

type exn += Genesis_state_initialization_error

module Tar = struct
  let create ~root ~directory ~file () =
    match%map
      Process.run ~prog:"tar"
        ~args:
          [ (* Change directory to [root]. *)
            "-C"
          ; root
          ; (* Create gzipped tar file [file]. *)
            "-czf"
          ; file
          ; (* Add [directory] to tar file. *)
            directory
          ]
        ()
    with
    | Ok _ ->
        Ok ()
    | Error err ->
        Error (Error.tag err ~tag:"Error generating tar file")

  let extract ~root ~file () =
    match%map
      Process.run ~prog:"tar"
        ~args:
          [ (* Change directory to [root]. *)
            "-C"
          ; root
          ; (* Extract gzipped tar file [file]. *)
            "-xzf"
          ; file
          ]
        ()
    with
    | Ok _ ->
        Ok ()
    | Error err ->
        Error (Error.tag err ~tag:"Error extracting tar file")

  let filename_without_extension =
    String.chop_suffix_if_exists ~suffix:".tar.gz"
end

let file_exists ?follow_symlinks filename =
  match%map Sys.file_exists ?follow_symlinks filename with
  | `Yes ->
      true
  | _ ->
      false

let sha3_hash ledger_file =
  let st = ref (Digestif.SHA3_256.init ()) in
  match%map
    Reader.with_file ledger_file ~f:(fun rdr ->
        Reader.read_one_chunk_at_a_time rdr ~handle_chunk:(fun buf ~pos ~len ->
            st := Digestif.SHA3_256.feed_bigstring !st buf ~off:pos ~len ;
            Deferred.return `Continue ) )
  with
  | `Eof ->
      Digestif.SHA3_256.(get !st |> to_hex)
  | _ ->
      failwith "impossible: `Stop not used"

let assert_filehash_equal ~file ~hash ~logger =
  let%bind computed_hash = sha3_hash file in
  if String.equal computed_hash hash then Deferred.unit
  else
    let%map () = Unix.rename ~src:file ~dst:(file ^ ".incorrect-hash") in
    [%log error]
      "Verification failure: downloaded $path and expected SHA3-256 = \
       $expected_hash but it had $computed_hash"
      ~metadata:
        [ ("path", `String file)
        ; ("expected_hash", `String hash)
        ; ("computed_hash", `String computed_hash)
        ] ;
    failwith "Tarball hash mismatch"

module Ledger = struct
  let hash_filename hash ~ledger_name_prefix =
    let str =
      (* Consider the serialization of accounts as well as the hash. In
         particular, adding fields that are
         * hashed as a bit string
         * default to an all-zero bit representation
         may result in the same hash, but the accounts in the ledger will not
         match the account record format.
      *)
      hash
      ^ Bin_prot.Writer.to_string Mina_base.Account.Stable.Latest.bin_writer_t
          Mina_base.Account.empty
    in
    ledger_name_prefix ^ "_"
    ^ Blake2.to_hex (Blake2.digest_string str)
    ^ ".tar.gz"

  let named_filename
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~num_accounts ~balances ~ledger_name_prefix ?other_data name =
    let str =
      String.concat
        [ Int.to_string constraint_constants.ledger_depth
        ; Int.to_string (Option.value ~default:0 num_accounts)
        ; List.to_string balances ~f:(fun (i, balance) ->
              sprintf "%i %s" i (Currency.Balance.to_string balance) )
        ; (* Distinguish ledgers when the hash function is different. *)
          Snark_params.Tick.Field.to_string
            (Lazy.force Mina_base.Account.empty_digest)
        ; (* Distinguish ledgers when the account record layout has changed. *)
          Bin_prot.Writer.to_string Mina_base.Account.Stable.Latest.bin_writer_t
            Mina_base.Account.empty
        ]
    in
    let str =
      match other_data with None -> str | Some other_data -> str ^ other_data
    in
    ledger_name_prefix ^ "_" ^ name ^ "_"
    ^ Blake2.(to_hex (digest_string str))
    ^ ".tar.gz"

  let accounts_hash accounts =
    Runtime_config.Accounts.to_yojson accounts
    |> Yojson.Safe.to_string |> Blake2.digest_string |> Blake2.to_hex

  let find_tar ~logger ~genesis_dir ~constraint_constants ~ledger_name_prefix
      (config : Runtime_config.Ledger.t) =
    let search_paths = Cache_dir.possible_paths "" @ [ genesis_dir ] in
    let file_exists filename path =
      let filename = path ^/ filename in
      if%map file_exists ~follow_symlinks:true filename then (
        [%log trace] "Found $ledger file at $path"
          ~metadata:
            [ ("ledger", `String ledger_name_prefix)
            ; ("path", `String filename)
            ] ;
        Some filename )
      else (
        [%log trace] "Ledger file $path does not exist"
          ~metadata:[ ("path", `String filename) ] ;
        None )
    in
    let load_from_s3 filename =
      match config.s3_data_hash with
      | Some s3_hash -> (
          let s3_path = Cache_dir.s3_keys_bucket_prefix ^/ filename in
          let local_path = Cache_dir.s3_install_path ^/ filename in
          match%bind Cache_dir.load_from_s3 s3_path local_path ~logger with
          | Ok () ->
              let%bind () =
                assert_filehash_equal
                  ~file:(Cache_dir.s3_install_path ^/ filename)
                  ~hash:s3_hash ~logger
              in
              file_exists filename Cache_dir.s3_install_path
          | Error e ->
              [%log trace] "Could not download $ledger from $uri: $error"
                ~metadata:
                  [ ("ledger", `String ledger_name_prefix)
                  ; ("uri", `String s3_path)
                  ; ("error", `String (Error.to_string_hum e))
                  ] ;
              return None )
      | None ->
          [%log warn]
            "Need S3 hash specified in runtime config to verify download for \
             $ledger (root hash $root_hash), not attempting"
            ~metadata:
              [ ( "root_hash"
                , `String (Option.value ~default:"not specified" config.hash) )
              ; ("ledger", `String ledger_name_prefix)
              ] ;
          return None
    in
    let search_local filename =
      Deferred.List.find_map ~f:(file_exists filename) search_paths
    in
    let search_local_and_s3 filename =
      match%bind search_local filename with
      | Some path ->
          return (Some path)
      | None ->
          load_from_s3 filename
    in
    let%bind hash_filename =
      match config.hash with
      | Some hash ->
          let hash_filename = hash_filename hash ~ledger_name_prefix in
          search_local_and_s3 hash_filename
      | None ->
          return None
    in
    match hash_filename with
    | Some filename ->
        return (Some filename)
    | None -> (
        let search_local_and_s3 ?other_data name =
          let named_filename =
            named_filename ~constraint_constants
              ~num_accounts:config.num_accounts ~balances:config.balances
              ~ledger_name_prefix ?other_data name
          in
          search_local_and_s3 named_filename
        in
        match (config.base, config.name) with
        | Named name, _ ->
            let named_filename =
              named_filename ~constraint_constants
                ~num_accounts:config.num_accounts ~balances:config.balances
                ~ledger_name_prefix name
            in
            search_local named_filename
        | Accounts accounts, _ ->
            search_local_and_s3 ~other_data:(accounts_hash accounts) "accounts"
        | Hash, None ->
            assert (Option.is_some config.hash) ;
            return None
        | _, Some name ->
            search_local_and_s3 name )

  let load_from_tar ?(genesis_dir = Cache_dir.autogen_path) ~logger
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ?accounts ~ledger_name_prefix ~expected_merkle_root filename =
    [%log trace] "Loading $ledger from $path"
      ~metadata:
        [ ("ledger", `String ledger_name_prefix); ("path", `String filename) ] ;
    let dirname =
      Tar.filename_without_extension @@ Filename.basename filename
    in
    let dirname = genesis_dir ^/ dirname in
    let%bind () = File_system.create_dir ~clear_if_exists:true dirname in
    let%map.Deferred.Or_error () =
      Tar.extract ~root:dirname ~file:filename ()
    in
    let (packed : Genesis_ledger.Packed.t) =
      match accounts with
      | Some accounts ->
          ( module Genesis_ledger.Make (struct
            let accounts = accounts

            let directory = `Path dirname

            let depth = constraint_constants.ledger_depth
          end) )
      | None ->
          ( module Genesis_ledger.Of_ledger (struct
            let t =
              lazy
                (let ledger =
                   Mina_ledger.Ledger.create ~directory_name:dirname
                     ~depth:constraint_constants.ledger_depth ()
                 in
                 let ledger_root = Mina_ledger.Ledger.merkle_root ledger in
                 ( match expected_merkle_root with
                 | Some expected_merkle_root ->
                     if not (Ledger_hash.equal ledger_root expected_merkle_root)
                     then (
                       [%log error]
                         "Ledger root hash $root_hash loaded from $path does \
                          not match root hash expected from the config file: \
                          $expected_root_hash"
                         ~metadata:
                           [ ("root_hash", Ledger_hash.to_yojson ledger_root)
                           ; ("path", `String filename)
                           ; ( "expected_root_hash"
                             , Ledger_hash.to_yojson expected_merkle_root )
                           ] ;
                       failwith "Ledger root mismatch" )
                 | None ->
                     [%log warn]
                       "Config file did not specify expected hash for ledger \
                        loaded from $filename"
                       ~metadata:
                         [ ("path", `String filename)
                         ; ("root_hash", Ledger_hash.to_yojson ledger_root)
                         ] ) ;
                 ledger )

            let depth = constraint_constants.ledger_depth
          end) )
    in
    packed

  let generate_tar ~genesis_dir ~logger ~ledger_name_prefix ledger =
    Mina_ledger.Ledger.commit ledger ;
    let dirname = Option.value_exn (Mina_ledger.Ledger.get_directory ledger) in
    let root_hash =
      Ledger_hash.to_base58_check @@ Mina_ledger.Ledger.merkle_root ledger
    in
    let%bind () = Unix.mkdir ~p:() genesis_dir in
    let tar_path = genesis_dir ^/ hash_filename root_hash ~ledger_name_prefix in
    [%log trace]
      "Creating $ledger tar file for $root_hash at $path from database at $dir"
      ~metadata:
        [ ("ledger", `String ledger_name_prefix)
        ; ("root_hash", `String root_hash)
        ; ("path", `String tar_path)
        ; ("dir", `String dirname)
        ] ;
    (* This sleep for 5s is a hack for rocksdb. It seems like rocksdb would need some
       time to stablize *)
    let%bind () = after (Time.Span.of_int_sec 5) in
    let%map.Deferred.Or_error () =
      Tar.create ~root:dirname ~file:tar_path ~directory:"." ()
    in
    tar_path

  let padded_accounts_from_runtime_config_opt ~logger ~proof_level
      ~ledger_name_prefix ?overwrite_version (config : Runtime_config.Ledger.t)
      =
    let patch_accounts_version accounts_with_keys =
      match overwrite_version with
      | Some version ->
          List.map accounts_with_keys ~f:(fun (key, account) ->
              let patched_account =
                Mina_base.Account.
                  { account with
                    permissions =
                      Mina_base.Permissions.Poly.
                        { account.permissions with
                          set_verification_key =
                            ( fst account.permissions.set_verification_key
                            , version )
                        }
                  }
              in
              (key, patched_account) )
      | None ->
          accounts_with_keys
    in

    let add_genesis_winner_account accounts =
      (* We allow configurations to explicitly override adding the genesis
         winner, so that we can guarantee a certain ledger layout for
         integration tests.
         If the configuration does not include this setting, we add the
         genesis winner when we have [proof_level = Full] so that we can
         create a genesis proof. For all other proof levels, we do not add
         the winner.
      *)
      let add_genesis_winner_account =
        match config.add_genesis_winner with
        | Some add_genesis_winner ->
            add_genesis_winner
        | None ->
            Genesis_constants.Proof_level.equal Full proof_level
      in
      if add_genesis_winner_account then
        let genesis_winner_pk, _ =
          Mina_state.Consensus_state_hooks.genesis_winner
        in
        match accounts with
        | (_, account) :: _
          when Public_key.Compressed.equal
                 (Account.public_key account)
                 genesis_winner_pk ->
            accounts
        | _ ->
            (None, Mina_state.Consensus_state_hooks.genesis_winner_account)
            :: accounts
      else accounts
    in
    let accounts_opt =
      match config.base with
      | Hash ->
          None
      | Accounts accounts ->
          Some
            ( lazy
              (patch_accounts_version
                 (add_genesis_winner_account (Accounts.to_full accounts)) ) )
      | Named name -> (
          match Genesis_ledger.fetch_ledger name with
          | Some (module M) ->
              [%log trace] "Found $ledger with name $ledger_name"
                ~metadata:
                  [ ("ledger", `String ledger_name_prefix)
                  ; ("ledger_name", `String name)
                  ] ;
              Some (Lazy.map ~f:add_genesis_winner_account M.accounts)
          | None ->
              [%log trace]
                "Could not find a built-in $ledger named $ledger_name"
                ~metadata:
                  [ ("ledger", `String ledger_name_prefix)
                  ; ("ledger_name", `String name)
                  ] ;
              None )
    in
    let padded_accounts_with_balances_opt =
      Option.map accounts_opt
        ~f:
          (Lazy.map
             ~f:(Accounts.pad_with_rev_balances (List.rev config.balances)) )
    in
    Option.map padded_accounts_with_balances_opt
      ~f:
        (Lazy.map
           ~f:(Accounts.pad_to (Option.value ~default:0 config.num_accounts)) )

  let packed_genesis_ledger_of_accounts ~depth accounts :
      Genesis_ledger.Packed.t =
    ( module Genesis_ledger.Make (struct
      let accounts = accounts

      let directory = `New

      let depth = depth
    end) )

  let load ~proof_level ~genesis_dir ~logger ~constraint_constants
      ?(ledger_name_prefix = "genesis_ledger") ?overwrite_version
      (config : Runtime_config.Ledger.t) =
    Monitor.try_with_join_or_error ~here:[%here] (fun () ->
        let padded_accounts_opt =
          padded_accounts_from_runtime_config_opt ~logger ~proof_level
            ~ledger_name_prefix ?overwrite_version config
        in
        let open Deferred.Let_syntax in
        let%bind tar_path =
          find_tar ~logger ~genesis_dir ~constraint_constants
            ~ledger_name_prefix config
        in
        match tar_path with
        | Some tar_path -> (
            match%map
              load_from_tar ~genesis_dir ~logger ~constraint_constants
                ~expected_merkle_root:
                  (Option.map config.hash ~f:Ledger_hash.of_base58_check_exn)
                ?accounts:padded_accounts_opt ~ledger_name_prefix tar_path
            with
            | Ok ledger ->
                Ok (ledger, config, tar_path)
            | Error err ->
                [%log error] "Could not load ledger from $path: $error"
                  ~metadata:
                    [ ("path", `String tar_path)
                    ; ("error", Error_json.error_to_yojson err)
                    ] ;
                Error err )
        | None -> (
            match padded_accounts_opt with
            | None -> (
                match config.base with
                | Accounts _ ->
                    assert false
                | Hash ->
                    let missing_hash =
                      Option.value ~default:"not specified" config.hash
                    in
                    [%log error]
                      "Could not find or generate a $ledger for $root_hash"
                      ~metadata:
                        [ ("ledger", `String ledger_name_prefix)
                        ; ("root_hash", `String missing_hash)
                        ] ;
                    Deferred.Or_error.errorf
                      "Could not find a ledger tar file for hash '%s'"
                      missing_hash
                | Named ledger_name ->
                    let ledger_filename =
                      named_filename ~constraint_constants
                        ~num_accounts:config.num_accounts
                        ~balances:config.balances ~ledger_name_prefix
                        ledger_name
                    in
                    [%log error]
                      "Bad config $config: $ledger named $ledger_name is not \
                       built in, and no ledger file was found at \
                       $ledger_filename"
                      ~metadata:
                        [ ("ledger", `String ledger_name_prefix)
                        ; ("config", Runtime_config.Ledger.to_yojson config)
                        ; ("ledger_name", `String ledger_name)
                        ; ("ledger_filename", `String ledger_filename)
                        ] ;
                    Deferred.Or_error.errorf "ledger '%s' not found" ledger_name
                )
            | Some accounts -> (
                let packed =
                  packed_genesis_ledger_of_accounts
                    ~depth:constraint_constants.ledger_depth accounts
                in
                let ledger = Lazy.force (Genesis_ledger.Packed.t packed) in
                let%bind tar_path =
                  generate_tar ~genesis_dir ~logger ~ledger_name_prefix ledger
                in
                let config =
                  { config with
                    hash =
                      Some
                        ( Ledger_hash.to_base58_check
                        @@ Mina_ledger.Ledger.merkle_root ledger )
                  }
                in
                let name, other_data =
                  match (config.base, config.name) with
                  | Named name, _ ->
                      (Some name, None)
                  | Accounts accounts, _ ->
                      (Some "accounts", Some (accounts_hash accounts))
                  | Hash, None ->
                      (None, None)
                  | _, Some name ->
                      (Some name, None)
                in
                match (tar_path, name) with
                | Ok tar_path, Some name ->
                    let link_name =
                      genesis_dir
                      ^/ named_filename ~constraint_constants
                           ~num_accounts:config.num_accounts
                           ~balances:config.balances ~ledger_name_prefix
                           ?other_data name
                    in
                    (* Delete the file if it already exists. *)
                    let%bind () =
                      Deferred.Or_error.try_with ~here:[%here] (fun () ->
                          Sys.remove link_name )
                      |> Deferred.ignore_m
                    in
                    (* Add a symlink from the named path to the hash path. *)
                    let%map () = Unix.symlink ~target:tar_path ~link_name in
                    [%log trace]
                      "Linking ledger file $tar_path to $named_tar_path"
                      ~metadata:
                        [ ("tar_path", `String tar_path)
                        ; ("named_tar_path", `String link_name)
                        ] ;
                    Ok (packed, config, link_name)
                | Ok tar_path, _ ->
                    return (Ok (packed, config, tar_path))
                | Error err, _ ->
                    let root_hash =
                      Ledger_hash.to_base58_check
                      @@ Mina_ledger.Ledger.merkle_root ledger
                    in
                    let tar_path =
                      genesis_dir ^/ hash_filename root_hash ~ledger_name_prefix
                    in
                    [%log error]
                      "Could not generate a $ledger file at $path: $error"
                      ~metadata:
                        [ ("ledger", `String ledger_name_prefix)
                        ; ("path", `String tar_path)
                        ; ("error", Error_json.error_to_yojson err)
                        ] ;
                    return (Error err) ) ) )
end

module Epoch_data = struct
  let load ~proof_level ~genesis_dir ~logger ~constraint_constants
      (config : Runtime_config.Epoch_data.t option) =
    let open Deferred.Or_error.Let_syntax in
    match config with
    | None ->
        Deferred.Or_error.return (None, None)
    | Some config ->
        let ledger_name_prefix = "epoch_ledger" in
        let load_ledger ledger =
          Ledger.load ~proof_level ~genesis_dir ~logger ~constraint_constants
            ~ledger_name_prefix ledger
        in
        let%bind staking, staking_config =
          let%map staking_ledger, config', ledger_file =
            load_ledger config.staking.ledger
          in
          [%log trace] "Loaded staking epoch ledger from $ledger_file"
            ~metadata:[ ("ledger_file", `String ledger_file) ] ;
          ( { Consensus.Genesis_epoch_data.Data.ledger =
                Genesis_ledger.Packed.t staking_ledger
            ; seed = Epoch_seed.of_base58_check_exn config.staking.seed
            }
          , { config.staking with ledger = config' } )
        in
        let%map next, next_config =
          match config.next with
          | None ->
              [%log trace]
                "Configured next epoch ledger to be the same as the staking \
                 epoch ledger" ;
              Deferred.Or_error.return (None, None)
          | Some { ledger; seed } ->
              let%map next_ledger, config'', ledger_file = load_ledger ledger in
              [%log trace] "Loaded next epoch ledger from $ledger_file"
                ~metadata:[ ("ledger_file", `String ledger_file) ] ;
              ( Some
                  { Consensus.Genesis_epoch_data.Data.ledger =
                      Genesis_ledger.Packed.t next_ledger
                  ; seed = Epoch_seed.of_base58_check_exn seed
                  }
              , Some { Runtime_config.Epoch_data.Data.ledger = config''; seed }
              )
        in
        (* the staking ledger and the next ledger, if it exists,
           should have the genesis winner account as the first account, under
           the conditions where the genesis ledger has that account (proof level
           is Full, or we've specified `add_genesis_winner = true`

           because the ledger is lazy, we don't want to force it in order to
           check that invariant
        *)
        ( Some { Consensus.Genesis_epoch_data.staking; next }
        , Some
            { Runtime_config.Epoch_data.staking = staking_config
            ; next = next_config
            } )
end

(* This hash encodes the data that determines a genesis proof:
   1. The blockchain snark constraint system
   2. The genesis protocol state (including the genesis ledger)

   It is used to determine whether we should make a new genesis proof, or use the
   one generated at compile-time.
*)
module Base_hash : sig
  type t [@@deriving equal, yojson]

  val create : id:Pickles.Verification_key.Id.t -> state_hash:State_hash.t -> t

  val to_string : t -> string
end = struct
  type t = string [@@deriving equal, yojson]

  let to_string = Fn.id

  let create ~id ~state_hash =
    Pickles.Verification_key.Id.to_string id
    |> ( ^ ) (State_hash.to_base58_check state_hash)
    |> Blake2.digest_string |> Blake2.to_hex
end

module Genesis_proof = struct
  let filename ~base_hash = "genesis_proof_" ^ Base_hash.to_string base_hash

  let find_file ~logger ~base_hash ~genesis_dir =
    let search_paths = genesis_dir :: Cache_dir.possible_paths "" in
    let file_exists filename path =
      let filename = path ^/ filename in
      if%map file_exists ~follow_symlinks:true filename then (
        [%log info] "Found genesis proof file at $path"
          ~metadata:[ ("path", `String filename) ] ;
        Some filename )
      else (
        [%log info] "Genesis proof file $path does not exist"
          ~metadata:[ ("path", `String filename) ] ;
        None )
    in
    let filename = filename ~base_hash in
    match%bind
      Deferred.List.find_map ~f:(file_exists filename) search_paths
    with
    | Some filename ->
        return (Some filename)
    | None ->
        [%log warn] "No genesis proof found for $base_hash"
          ~metadata:[ ("base_hash", Base_hash.to_yojson base_hash) ] ;
        return None

  let generate_inputs ~runtime_config ~proof_level ~ledger ~genesis_epoch_data
      ~constraint_constants ~blockchain_proof_system_id
      ~(genesis_constants : Genesis_constants.t) =
    let consensus_constants =
      Consensus.Constants.create ~constraint_constants
        ~protocol_constants:genesis_constants.protocol
    in
    let open Staged_ledger_diff in
    let protocol_state_with_hashes =
      Mina_state.Genesis_protocol_state.t
        ~genesis_ledger:(Genesis_ledger.Packed.t ledger)
        ~genesis_epoch_data ~constraint_constants ~consensus_constants
        ~genesis_body_reference
    in
    { Genesis_proof.Inputs.runtime_config
    ; constraint_constants
    ; proof_level
    ; blockchain_proof_system_id
    ; genesis_ledger = ledger
    ; genesis_epoch_data
    ; consensus_constants
    ; protocol_state_with_hashes
    ; constraint_system_digests = None
    ; genesis_constants
    ; genesis_body_reference
    }

  let generate (inputs : Genesis_proof.Inputs.t) =
    match inputs.proof_level with
    | Genesis_constants.Proof_level.Full ->
        Deferred.return
        @@ Genesis_proof.create_values_no_proof
             { genesis_ledger = inputs.genesis_ledger
             ; genesis_epoch_data = inputs.genesis_epoch_data
             ; runtime_config = inputs.runtime_config
             ; proof_level = inputs.proof_level
             ; blockchain_proof_system_id = None
             ; constraint_system_digests = None
             ; protocol_state_with_hashes = inputs.protocol_state_with_hashes
             ; genesis_constants = inputs.genesis_constants
             ; consensus_constants = inputs.consensus_constants
             ; constraint_constants = inputs.constraint_constants
             ; genesis_body_reference = inputs.genesis_body_reference
             }
    | _ ->
        Deferred.return (Genesis_proof.create_values_no_proof inputs)

  let store ~filename proof =
    (* TODO: Use [Writer.write_bin_prot]. *)
    Monitor.try_with_or_error ~here:[%here] ~extract_exn:true (fun () ->
        let%bind wr = Writer.open_file filename in
        Writer.write wr (Proof.Stable.V2.sexp_of_t proof |> Sexp.to_string) ;
        Writer.close wr )

  let load filename =
    (* TODO: Use [Reader.load_bin_prot]. *)
    Monitor.try_with_or_error ~here:[%here] ~extract_exn:true (fun () ->
        Reader.file_contents filename
        >>| Sexp.of_string >>| Proof.Stable.V2.t_of_sexp )

  let id_to_json x =
    `String (Sexp.to_string (Pickles.Verification_key.Id.sexp_of_t x))

  let create_values_no_proof = Genesis_proof.create_values_no_proof
end

let load_config_json filename =
  Monitor.try_with_or_error ~here:[%here] (fun () ->
      let%map json = Reader.file_contents filename in
      Yojson.Safe.from_string json )

let load_config_file filename =
  let open Deferred.Or_error.Let_syntax in
  Monitor.try_with_join_or_error ~here:[%here] (fun () ->
      let%map json = load_config_json filename in
      match Runtime_config.of_yojson json with
      | Ok config ->
          Ok config
      | Error err ->
          Or_error.error_string err )

let print_config ~logger config =
  let ledger_name_json =
    Option.value ~default:`Null
    @@ let%bind.Option ledger = config.Runtime_config.ledger in
       let%map.Option name = ledger.name in
       `String name
  in
  let ( json_config
      , `Accounts_omitted
          ( `Genesis genesis_accounts_omitted
          , `Staking staking_accounts_omitted
          , `Next next_accounts_omitted ) ) =
    Runtime_config.to_yojson_without_accounts config
  in
  let append_accounts_omitted s =
    Option.value_map
      ~f:(fun i -> List.cons (s ^ "_accounts_omitted", `Int i))
      ~default:Fn.id
  in
  let metadata =
    append_accounts_omitted "genesis" genesis_accounts_omitted
    @@ append_accounts_omitted "staking" staking_accounts_omitted
    @@ append_accounts_omitted "next" next_accounts_omitted
         [ ("name", ledger_name_json); ("config", json_config) ]
  in
  [%log info] "Initializing with runtime configuration. Ledger name: $name"
    ~metadata

let inputs_from_config_file ?(genesis_dir = Cache_dir.autogen_path) ~logger
    ~cli_proof_level ~(genesis_constants : Genesis_constants.t)
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~proof_level:compiled_proof_level ?overwrite_version
    (config : Runtime_config.t) =
  print_config ~logger config ;
  let open Deferred.Or_error.Let_syntax in
  let proof_level =
    List.find_map_exn ~f:Fn.id
      [ cli_proof_level
      ; Option.Let_syntax.(
          let%bind proof = config.proof in
          match%map proof.level with
          | Full ->
              Genesis_constants.Proof_level.Full
          | Check ->
              Check
          | None ->
              None)
      ; Some compiled_proof_level
      ]
  in
  let constraint_constants, blockchain_proof_system_id =
    match config.proof with
    | None ->
        [%log info] "Using the compiled constraint constants" ;
        (constraint_constants, Some (Pickles.Verification_key.Id.dummy ()))
    | Some config ->
        [%log info] "Using the constraint constants from the configuration file" ;
        let blockchain_proof_system_id =
          (* We pass [None] here, which will force the constraint systems to be
             set up and their hashes evaluated before we can calculate the
             genesis proof's filename.
             This adds no overhead if we are generating a genesis proof, since
             we will do these evaluations anyway to load the blockchain proving
             key. Otherwise, this will in a slight slowdown.
          *)
          None
        in
        ( make_constraint_constants ~default:constraint_constants config
        , blockchain_proof_system_id )
  in
  let%bind () =
    match (proof_level, compiled_proof_level) with
    | _, Full | (Check | None), _ ->
        return ()
    | Full, ((Check | None) as compiled) ->
        let str = Genesis_constants.Proof_level.to_string in
        [%log fatal]
          "Proof level $proof_level is not compatible with compile-time proof \
           level $compiled_proof_level"
          ~metadata:
            [ ("proof_level", `String (str proof_level))
            ; ("compiled_proof_level", `String (str compiled))
            ] ;
        Deferred.Or_error.errorf
          "Proof level %s is not compatible with compile-time proof level %s"
          (str proof_level) (str compiled)
  in
  let%bind genesis_ledger, ledger_config, ledger_file =
    match config.ledger with
    | Some ledger ->
        Ledger.load ~proof_level ~genesis_dir ~logger ~constraint_constants
          ?overwrite_version ledger
    | None ->
        [%log fatal] "No ledger was provided in the runtime configuration" ;
        Deferred.Or_error.errorf
          "No ledger was provided in the runtime configuration"
  in
  [%log info] "Loaded genesis ledger from $ledger_file"
    ~metadata:[ ("ledger_file", `String ledger_file) ] ;
  let%bind genesis_epoch_data, genesis_epoch_data_config =
    Epoch_data.load ~proof_level ~genesis_dir ~logger ~constraint_constants
      config.epoch_data
  in
  let config =
    { config with
      ledger = Option.map config.ledger ~f:(fun _ -> ledger_config)
    ; epoch_data = genesis_epoch_data_config
    }
  in
  let%map genesis_constants =
    Deferred.return
    @@ make_genesis_constants ~logger ~default:genesis_constants config
  in
  let proof_inputs =
    Genesis_proof.generate_inputs ~runtime_config:config ~proof_level
      ~ledger:genesis_ledger ~constraint_constants ~genesis_constants
      ~blockchain_proof_system_id ~genesis_epoch_data
  in
  (proof_inputs, config)

let init_from_config_file ?genesis_dir ~cli_proof_level ~genesis_constants
    ~constraint_constants ~logger ~proof_level ?overwrite_version
    (config : Runtime_config.t) :
    (Precomputed_values.t * Runtime_config.t) Deferred.Or_error.t =
  let open Deferred.Or_error.Let_syntax in
  let%map inputs, config =
    inputs_from_config_file ?genesis_dir ~cli_proof_level ~genesis_constants
      ~constraint_constants ~logger ~proof_level ?overwrite_version config
  in
  let values = Genesis_proof.create_values_no_proof inputs in
  (values, config)

let upgrade_old_config ~logger filename json =
  match json with
  | `Assoc fields ->
      (* Fields previously part of daemon.json *)
      let old_fields =
        [ "client_port"
        ; "libp2p-port"
        ; "rest-port"
        ; "block-producer-key"
        ; "block-producer-pubkey"
        ; "block-producer-password"
        ; "coinbase-receiver"
        ; "run-snark-worker"
        ; "snark-worker-fee"
        ; "peers"
        ; "work-selection"
        ; "work-reassignment-wait"
        ; "log-received-blocks"
        ; "log-txn-pool-gossip"
        ; "log-snark-work-gossip"
        ; "log-block-creation"
        ]
      in
      let found_daemon = ref false in
      let old_fields, remaining_fields =
        List.partition_tf fields ~f:(fun (key, _) ->
            if String.equal key "daemon" then (
              found_daemon := true ;
              false )
            else List.mem ~equal:String.equal old_fields key )
      in
      if List.is_empty old_fields then return json
      else if !found_daemon then (
        (* This file has already been upgraded, or was written for the new
           format. Do not accept old-style fields.
        *)
        [%log warn]
          "Ignoring old-format values $values from the config file $filename. \
           These flags are now fields in the 'daemon' object of the config \
           file."
          ~metadata:
            [ ("values", `Assoc old_fields); ("filename", `String filename) ] ;
        return (`Assoc remaining_fields) )
      else (
        (* This file was written for the old format. Upgrade it. *)
        [%log warn]
          "Automatically upgrading the config file $filename. The values \
           $values have been moved to the 'daemon' object."
          ~metadata:
            [ ("filename", `String filename); ("values", `Assoc old_fields) ] ;
        let upgraded_json =
          `Assoc (("daemon", `Assoc old_fields) :: remaining_fields)
        in
        let%map () =
          Deferred.Or_error.try_with ~here:[%here] (fun () ->
              Writer.with_file filename ~f:(fun w ->
                  Deferred.return
                  @@ Writer.write w (Yojson.Safe.pretty_to_string upgraded_json) ) )
          |> Deferred.ignore_m
        in
        upgraded_json )
  | _ ->
      (* This error will get handled properly elsewhere, do nothing here. *)
      return json

let%test_module "Account config test" =
  ( module struct
    let%test_unit "Runtime config <=> Account" =
      let module Ledger = (val Genesis_ledger.for_unit_tests) in
      let accounts = Lazy.force Ledger.accounts in
      List.iter accounts ~f:(fun (sk, acc) ->
          let acc_config = Accounts.Single.of_account acc sk in
          let acc' =
            Accounts.Single.to_account_with_pk acc_config |> Or_error.ok_exn
          in
          [%test_eq: Account.t] acc acc' )
  end )
