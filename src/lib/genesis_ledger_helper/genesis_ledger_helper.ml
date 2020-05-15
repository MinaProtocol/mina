open Core
open Async
open Signature_lib
open Coda_base

type exn += Genesis_state_initialization_error

let s3_bucket_prefix =
  "https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net"

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
            directory ]
        ()
    with
    | Ok _ ->
        Ok ()
    | Error err ->
        Or_error.errorf
          !"Error generating tar file %s. %s"
          file (Error.to_string_hum err)

  let extract ~root ~file () =
    match%map
      Process.run ~prog:"tar"
        ~args:
          [ (* Change directory to [root]. *)
            "-C"
          ; root
          ; (* Extract gzipped tar file [file]. *)
            "-xzf"
          ; file ]
        ()
    with
    | Ok _ ->
        Ok ()
    | Error err ->
        Or_error.errorf
          !"Error extracting tar file %s. %s"
          file (Error.to_string_hum err)
end

let file_exists ?follow_symlinks filename =
  match%map Sys.file_exists ?follow_symlinks filename with
  | `Yes ->
      true
  | _ ->
      false

module Accounts = struct
  let to_full :
      Runtime_config.Accounts.t -> (Private_key.t option * Account.t) list =
    List.mapi ~f:(fun i {Runtime_config.Accounts.pk; sk; balance; delegate} ->
        let pk =
          match pk with
          | Some pk ->
              Public_key.Compressed.of_base58_check_exn pk
          | None ->
              Quickcheck.random_value
                ~seed:
                  (`Deterministic
                    ("fake pk for genesis ledger " ^ string_of_int i))
                Public_key.Compressed.gen
        in
        let sk =
          match sk with
          | Some sk -> (
            match Private_key.of_yojson (`String sk) with
            | Ok sk ->
                Some sk
            | Error err ->
                Error.(raise (of_string err)) )
          | None ->
              None
        in
        let delegate =
          Option.map ~f:Public_key.Compressed.of_base58_check_exn delegate
        in
        let account =
          Account.create (Account_id.create pk Token_id.default) balance
        in
        ( sk
        , { account with
            delegate= Option.value ~default:account.delegate delegate } ) )

  let gen : (Private_key.t option * Account.t) Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%bind balance = Int.gen_incl 10 500 >>| Currency.Balance.of_int in
    let%map pk = Signature_lib.Public_key.Compressed.gen in
    (None, Account.create (Account_id.create pk Token_id.default) balance)

  let generate n : (Private_key.t option * Account.t) list =
    let open Quickcheck in
    random_value ~seed:(`Deterministic "fake accounts for genesis ledger")
      (Generator.list_with_length n gen)

  let rec pad_to n accounts =
    if n <= 0 then accounts
    else
      match accounts with
      | [] ->
          generate n
      | account :: accounts ->
          account :: pad_to (n - 1) accounts
end

module Ledger = struct
  let hash_filename hash = "genesis_ledger_" ^ hash ^ ".tar.gz"

  let named_filename
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~num_accounts name =
    let str =
      String.concat
        [ Int.to_string Coda_compile_config.curve_size
        ; Int.to_string constraint_constants.ledger_depth
        ; Int.to_string (Option.value ~default:0 num_accounts) ]
    in
    "genesis_ledger_" ^ name ^ "_"
    ^ Blake2.(to_hex (digest_string str))
    ^ ".tar.gz"

  let find_tar ~logger ~constraint_constants (config : Runtime_config.Ledger.t)
      =
    let search_paths =
      Cache_dir.
        [autogen_path; manual_install_path; brew_install_path; s3_install_path]
    in
    let file_exists filename path =
      let filename = path ^/ filename in
      if%map file_exists ~follow_symlinks:true filename then (
        Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
          "Found ledger file at $path"
          ~metadata:[("path", `String filename)] ;
        Some filename )
      else (
        Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
          "Ledger file $path does not exist"
          ~metadata:[("path", `String filename)] ;
        None )
    in
    let%bind hash_filename =
      match config.hash with
      | Some hash -> (
          let hash_filename = hash_filename hash in
          let%bind tar_path =
            Deferred.List.find_map ~f:(file_exists hash_filename) search_paths
          in
          match tar_path with
          | Some _ ->
              return tar_path
          | None -> (
              let s3_path = s3_bucket_prefix ^/ hash_filename in
              let local_path = Cache_dir.s3_install_path ^/ hash_filename in
              match%bind
                Cache_dir.load_from_s3 [s3_path] [local_path] ~logger
              with
              | Ok () ->
                  file_exists hash_filename Cache_dir.s3_install_path
              | Error e ->
                  Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
                    "Could not download genesis ledger from $uri: $error"
                    ~metadata:
                      [ ("uri", `String s3_path)
                      ; ("error", `String (Error.to_string_hum e)) ] ;
                  return None ) )
      | None ->
          return None
    in
    match hash_filename with
    | Some filename ->
        return (Some filename)
    | None -> (
      match config.base with
      | Hash hash ->
          assert (Some hash = config.hash) ;
          return None
      | Accounts (_accounts, None) ->
          return None
      | Accounts (_accounts, Some {name; newer_than}) ->
          let newer_than =
            Genesis_constants.validate_time (Some newer_than)
            |> Result.map_error ~f:(fun str ->
                   Error.of_string ("Could not parse 'newer_than': " ^ str) )
            |> Or_error.ok_exn
          in
          let named_filename =
            named_filename ~constraint_constants
              ~num_accounts:config.num_accounts ("custom_" ^ name)
          in
          Deferred.List.find_map search_paths ~f:(fun path ->
              match%bind file_exists named_filename path with
              | None ->
                  return None
              | Some filename ->
                  let%map {mtime; _} = Unix.stat filename in
                  if Time.(mtime >= newer_than) then Some filename
                  else (
                    Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
                      "Not using ledger file $path, because it was modified \
                       at $modification_time, before $desired_time"
                      ~metadata:
                        [ ("path", `String filename)
                        ; ("modification_time", `String (Time.to_string mtime))
                        ; ("desired_time", `String (Time.to_string newer_than))
                        ] ;
                    None ) )
      | Named name ->
          let named_filename =
            named_filename ~constraint_constants
              ~num_accounts:config.num_accounts name
          in
          Deferred.List.find_map ~f:(file_exists named_filename) search_paths )

  let load_from_tar ~logger
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ?accounts filename =
    Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
      "Loading genesis ledger from $path"
      ~metadata:[("path", `String filename)] ;
    let dirname = Uuid.to_string (Uuid_unix.create ()) in
    (* Unpack the ledger in the autogen directory, since we know that we have
       write permissions there.
    *)
    let dirname = Cache_dir.autogen_path ^/ dirname in
    let%bind () = Unix.mkdir ~p:() dirname in
    let open Deferred.Or_error.Let_syntax in
    let%map () = Tar.extract ~root:dirname ~file:filename () in
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
                (Ledger.create ~directory_name:dirname
                   ~depth:constraint_constants.ledger_depth ())

            let depth = constraint_constants.ledger_depth
          end) )
    in
    packed

  let generate_tar ~genesis_dir ~logger ledger =
    Ledger.commit ledger ;
    let dirname = Option.value_exn (Ledger.get_directory ledger) in
    let root_hash = State_hash.to_string @@ Ledger.merkle_root ledger in
    let%bind () = Unix.mkdir ~p:() genesis_dir in
    let tar_path = genesis_dir ^/ hash_filename root_hash in
    Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
      "Creating genesis ledger tar file for $root_hash at $path from database \
       at $dir"
      ~metadata:
        [ ("root_hash", `String root_hash)
        ; ("path", `String tar_path)
        ; ("dir", `String dirname) ] ;
    let open Deferred.Or_error.Let_syntax in
    let%map () = Tar.create ~root:dirname ~file:tar_path ~directory:"." () in
    tar_path

  let load ~genesis_dir ~logger ~constraint_constants
      (config : Runtime_config.Ledger.t) =
    Monitor.try_with_join_or_error (fun () ->
        let open Deferred.Or_error.Let_syntax in
        let%bind accounts =
          match config.base with
          | Hash _ ->
              return None
          | Accounts (accounts, _) ->
              return (Some (lazy (Accounts.to_full accounts)))
          | Named name -> (
            match Genesis_ledger.fetch_ledger name with
            | Some (module M) ->
                Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
                  "Found genesis ledger with name $ledger_name"
                  ~metadata:[("ledger_name", `String name)] ;
                return (Some M.accounts)
            | None ->
                Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
                  "Could not find a genesis ledger named $ledger_name"
                  ~metadata:[("ledger_name", `String name)] ;
                Deferred.Or_error.errorf "Genesis ledger '%s' not found" name )
        in
        let accounts =
          Option.map
            ~f:
              (Lazy.map
                 ~f:
                   (Accounts.pad_to
                      (Option.value ~default:0 config.num_accounts)))
            accounts
        in
        let open Deferred.Let_syntax in
        let%bind tar_path = find_tar ~logger ~constraint_constants config in
        match tar_path with
        | Some tar_path -> (
            match%map
              load_from_tar ~logger ~constraint_constants ?accounts tar_path
            with
            | Ok ledger ->
                Ok (ledger, config, tar_path)
            | Error err ->
                Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
                  "Could not load ledger from $path: $error"
                  ~metadata:
                    [ ("path", `String tar_path)
                    ; ("error", `String (Error.to_string_hum err)) ] ;
                Error err )
        | None -> (
          match accounts with
          | None -> (
            match config.base with
            | Hash hash ->
                Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
                  "Could not find or generate a ledger for $root_hash"
                  ~metadata:[("root_hash", `String hash)] ;
                Deferred.Or_error.errorf
                  "Could not find a ledger tar file for hash '%s'" hash
            | _ ->
                Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
                  "Bad config $config"
                  ~metadata:[("config", Runtime_config.Ledger.to_yojson config)] ;
                assert false )
          | Some accounts -> (
              let (packed : Genesis_ledger.Packed.t) =
                ( module Genesis_ledger.Make (struct
                  let accounts = accounts

                  let directory = `New

                  let depth = constraint_constants.ledger_depth
                end) )
              in
              let ledger = Lazy.force (Genesis_ledger.Packed.t packed) in
              let%bind tar_path = generate_tar ~genesis_dir ~logger ledger in
              let config =
                { config with
                  hash= Some (State_hash.to_string @@ Ledger.merkle_root ledger)
                }
              in
              let ledger_name =
                match config.base with
                | Named name ->
                    Some name
                | Accounts (_, Some {name; _}) ->
                    Some ("custom_" ^ name)
                | _ ->
                    None
              in
              match (tar_path, ledger_name) with
              | Ok tar_path, Some name ->
                  let link_name =
                    genesis_dir
                    ^/ named_filename ~constraint_constants
                         ~num_accounts:config.num_accounts name
                  in
                  (* Add a symlink from the named path to the hash path. *)
                  let%map () = Unix.symlink ~target:tar_path ~link_name in
                  Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
                    "Linking ledger file $tar_path to $named_tar_path"
                    ~metadata:
                      [ ("tar_path", `String tar_path)
                      ; ("named_tar_path", `String link_name) ] ;
                  Ok (packed, config, link_name)
              | Ok tar_path, None ->
                  return (Ok (packed, config, tar_path))
              | Error err, _ ->
                  let root_hash =
                    State_hash.to_string @@ Ledger.merkle_root ledger
                  in
                  let tar_path = genesis_dir ^/ hash_filename root_hash in
                  Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
                    "Could not generate a ledger file at $path: $error"
                    ~metadata:
                      [ ("path", `String tar_path)
                      ; ("error", `String (Error.to_string_hum err)) ] ;
                  return (Error err) ) ) )
end

module Genesis_proof = struct
  let filename ~base_hash = "genesis_proof_" ^ Ledger_hash.to_string base_hash

  let find_file ~logger ~base_hash =
    let search_paths =
      Cache_dir.
        [autogen_path; manual_install_path; brew_install_path; s3_install_path]
    in
    let file_exists filename path =
      let filename = path ^/ filename in
      if%map file_exists ~follow_symlinks:true filename then (
        Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
          "Found genesis proof file at $path"
          ~metadata:[("path", `String filename)] ;
        Some filename )
      else (
        Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
          "Genesis proof file $path does not exist"
          ~metadata:[("path", `String filename)] ;
        None )
    in
    let filename = filename ~base_hash in
    match%bind
      Deferred.List.find_map ~f:(file_exists filename) search_paths
    with
    | Some filename ->
        return (Some filename)
    | None -> (
        let s3_path = s3_bucket_prefix ^/ filename in
        let local_path = Cache_dir.s3_install_path ^/ filename in
        match%bind Cache_dir.load_from_s3 [s3_path] [local_path] ~logger with
        | Ok () ->
            file_exists filename Cache_dir.s3_install_path
        | Error e ->
            Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
              "Could not download genesis proof file from $uri: $error"
              ~metadata:
                [ ("uri", `String s3_path)
                ; ("error", `String (Error.to_string_hum e)) ] ;
            return None )

  let generate_inputs ~proof_level ~ledger ~constraint_constants
      ~(genesis_constants : Genesis_constants.t) =
    let protocol_state_with_hash =
      Coda_state.Genesis_protocol_state.t
        ~genesis_ledger:(Genesis_ledger.Packed.t ledger)
        ~constraint_constants ~genesis_constants
    in
    let%map base_hash =
      match proof_level with
      | Genesis_constants.Proof_level.Full ->
          Keys_lib.Keys.step_instance_hash protocol_state_with_hash.data
      | _ ->
          return Snark_params.Tick.Field.zero
    in
    { Genesis_proof.Inputs.genesis_ledger= ledger
    ; protocol_state_with_hash
    ; base_hash
    ; genesis_constants }

  let generate ~proof_level ~constraint_constants inputs =
    (* TODO(4829): Runtime proof-level. *)
    match proof_level with
    | Genesis_constants.Proof_level.Full ->
        let%map ((module Keys) as keys) = Keys_lib.Keys.create () in
        Genesis_proof.create_values ~constraint_constants ~proof_level ~keys
          inputs
    | _ ->
        return
          { Genesis_proof.genesis_constants= inputs.genesis_constants
          ; genesis_ledger= inputs.genesis_ledger
          ; protocol_state_with_hash= inputs.protocol_state_with_hash
          ; base_hash= inputs.base_hash
          ; genesis_proof= Dummy_values.Tock.Bowe_gabizon18.proof }

  let store ~filename proof =
    (* TODO: Use [Writer.write_bin_prot]. *)
    Monitor.try_with_or_error ~extract_exn:true (fun () ->
        let%bind wr = Writer.open_file filename in
        Writer.write wr (Proof.Stable.V1.sexp_of_t proof |> Sexp.to_string) ;
        Writer.close wr )

  let load filename =
    (* TODO: Use [Reader.load_bin_prot]. *)
    Monitor.try_with_or_error ~extract_exn:true (fun () ->
        Reader.file_contents filename
        >>| Sexp.of_string >>| Proof.Stable.V1.t_of_sexp )

  let load_or_generate ~genesis_dir ~logger ~may_generate ~proof_level
      ~constraint_constants (inputs : Genesis_proof.Inputs.t) =
    match%bind find_file ~logger ~base_hash:inputs.base_hash with
    | Some file -> (
        match%map load file with
        | Ok genesis_proof ->
            Ok
              ( { Genesis_proof.genesis_constants= inputs.genesis_constants
                ; genesis_ledger= inputs.genesis_ledger
                ; protocol_state_with_hash= inputs.protocol_state_with_hash
                ; base_hash= inputs.base_hash
                ; genesis_proof }
              , file )
        | Error err ->
            Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
              "Could not load genesis proof from $path: $error"
              ~metadata:
                [ ("path", `String file)
                ; ("error", `String (Error.to_string_hum err)) ] ;
            Error err )
    | None when may_generate ->
        Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
          "No genesis proof file was found for $base_hash, generating a new \
           genesis proof"
          ~metadata:[("base_hash", Ledger_hash.to_yojson inputs.base_hash)] ;
        let%bind values = generate ~proof_level ~constraint_constants inputs in
        let filename = genesis_dir ^/ filename ~base_hash:inputs.base_hash in
        let%map () =
          match%map store ~filename values.genesis_proof with
          | Ok () ->
              Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
                "New genesis proof written to $path"
                ~metadata:[("path", `String filename)]
          | Error err ->
              Logger.warn ~module_:__MODULE__ ~location:__LOC__ logger
                "Genesis proof could not be written to $path: $error"
                ~metadata:
                  [ ("path", `String filename)
                  ; ("error", `String (Error.to_string_hum err)) ]
        in
        Ok (values, filename)
    | None ->
        Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
          "No genesis proof file was found for $base_hash and not allowed to \
           generate a new genesis proof"
          ~metadata:[("base_hash", Ledger_hash.to_yojson inputs.base_hash)] ;
        Deferred.Or_error.errorf
          "No genesis proof file was found for and not allowed to generate a \
           new genesis proof"
end

let make_genesis_constants ~logger ~(default : Genesis_constants.t)
    (config : Runtime_config.t) =
  let open Or_error.Let_syntax in
  let%map genesis_state_timestamp =
    let open Option.Let_syntax in
    match
      let%bind daemon = config.genesis in
      let%map genesis_state_timestamp = daemon.genesis_state_timestamp in
      Genesis_constants.validate_time (Some genesis_state_timestamp)
    with
    | Some (Ok time) ->
        Ok (Some time)
    | Some (Error msg) ->
        Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
          "Could not build genesis constants from the configuration file: \
           $error"
          ~metadata:[("error", `String msg)] ;
        Or_error.errorf
          "Could not build genesis constants from the configuration file: %s"
          msg
    | None ->
        Ok None
  in
  let open Option.Let_syntax in
  { Genesis_constants.protocol=
      { k=
          Option.value ~default:default.protocol.k
            (config.genesis >>= fun cfg -> cfg.k)
      ; delta=
          Option.value ~default:default.protocol.delta
            (config.genesis >>= fun cfg -> cfg.delta)
      ; genesis_state_timestamp=
          Option.value ~default:default.protocol.genesis_state_timestamp
            genesis_state_timestamp }
  ; txpool_max_size=
      Option.value ~default:default.txpool_max_size
        (config.daemon >>= fun cfg -> cfg.txpool_max_size)
  ; num_accounts=
      Option.value_map ~default:default.num_accounts
        (config.ledger >>= fun cfg -> cfg.num_accounts)
        ~f:(fun num_accounts -> Some num_accounts) }

let load_config_json filename =
  Monitor.try_with_or_error (fun () ->
      let%map json = Reader.file_contents filename in
      Yojson.Safe.from_string json )

let load_config_file filename =
  let open Deferred.Or_error.Let_syntax in
  Monitor.try_with_join_or_error (fun () ->
      let%map json = load_config_json filename in
      match Runtime_config.of_yojson json with
      | Ok config ->
          Ok config
      | Error err ->
          Or_error.error_string err )

let init_from_config_file ?(genesis_dir = Cache_dir.autogen_path) ~logger
    ~may_generate ~constraint_constants ~proof_level ~genesis_constants
    (config : Runtime_config.t) =
  let open Deferred.Or_error.Let_syntax in
  let%bind genesis_ledger, ledger_config, ledger_file =
    Ledger.load ~genesis_dir ~logger ~constraint_constants
      (Option.value config.ledger
         ~default:
           { base= Named Coda_compile_config.genesis_ledger
           ; num_accounts= None
           ; hash= None })
  in
  let config =
    {config with ledger= Option.map config.ledger ~f:(fun _ -> ledger_config)}
  in
  let%bind genesis_constants =
    Deferred.return
    @@ make_genesis_constants ~logger ~default:genesis_constants config
  in
  let open Deferred.Let_syntax in
  let%bind proof_inputs =
    Genesis_proof.generate_inputs ~proof_level ~ledger:genesis_ledger
      ~constraint_constants ~genesis_constants
  in
  let open Deferred.Or_error.Let_syntax in
  let%map values, proof_file =
    Genesis_proof.load_or_generate ~genesis_dir ~logger ~may_generate
      ~proof_level ~constraint_constants proof_inputs
  in
  Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
    "Loaded ledger from $ledger_file and genesis proof from $proof_file"
    ~metadata:
      [("ledger_file", `String ledger_file); ("proof_file", `String proof_file)] ;
  (values, config)
