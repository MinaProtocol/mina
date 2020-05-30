open Core
open Async
open Coda_base

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

module Accounts = struct
  let path ~root = root ^/ "accounts.json"

  let compiled () =
    List.map (Lazy.force Test_genesis_ledger.accounts) ~f:(fun (sk_opt, acc) ->
        { Account_config.pk= acc.public_key
        ; sk= sk_opt
        ; balance= acc.balance
        ; delegate= Some acc.delegate } )

  let store ~filename accounts =
    Out_channel.with_file filename ~f:(fun json_file ->
        Yojson.Safe.pretty_to_channel json_file
          (Account_config.to_yojson accounts) )

  let load filename =
    let open Deferred.Let_syntax in
    match%map
      Deferred.Or_error.try_with_join (fun () ->
          let%map accounts_str = Reader.file_contents filename in
          let res = Yojson.Safe.from_string accounts_str in
          match Account_config.of_yojson res with
          | Ok res ->
              Ok res
          | Error s ->
              Error
                (Error.of_string
                   (sprintf "Account_config.of_yojson failed: %s" s)) )
    with
    | Ok res ->
        Ok res
    | Error e ->
        Or_error.errorf "Could not read accounts from file: %s\n%s" filename
          (Error.to_string_hum e)
end

module Ledger = struct
  let path ~root = root ^/ "ledger"

  let generate ?directory_name (accounts : Account_config.t) :
      Genesis_ledger.Packed.t =
    let accounts =
      List.map accounts ~f:(fun {pk; sk; balance; delegate} ->
          let account =
            let account_id = Account_id.create pk Token_id.default in
            let base_acct = Account.create account_id balance in
            {base_acct with delegate= Option.value ~default:pk delegate}
          in
          (sk, account) )
    in
    let (packed : Genesis_ledger.Packed.t) =
      ( module Genesis_ledger.Make (struct
        let accounts = lazy accounts

        let directory =
          match directory_name with
          | Some directory_name ->
              `Path directory_name
          | None ->
              `New

        let depth =
          Genesis_constants.Constraint_constants.compiled.ledger_depth
      end) )
    in
    packed |> Genesis_ledger.Packed.t |> Lazy.force |> Ledger.commit ;
    packed

  let load directory_name : Genesis_ledger.Packed.t =
    ( module Genesis_ledger.Of_ledger (struct
      let depth = Genesis_constants.Constraint_constants.compiled.ledger_depth

      let t = lazy (Ledger.create ~depth ~directory_name ())
    end) )
end

module Genesis_proof = struct
  let path ~root = root ^/ "genesis_proof"

  let generate ~proof_level ~ledger ~constraint_constants
      ~(genesis_constants : Genesis_constants.t) =
    (* TODO(4829): Runtime proof-level. *)
    match proof_level with
    | Genesis_constants.Proof_level.Full ->
        let module B =
          Blockchain_snark.Blockchain_snark_state.Make
            (Transaction_snark.Make ()) in
        let protocol_state_with_hash =
          Coda_state.Genesis_protocol_state.t
            ~genesis_ledger:(Genesis_ledger.Packed.t ledger)
            ~constraint_constants ~genesis_constants
        in
        let computed_values =
          Genesis_proof.create_values ~constraint_constants ~proof_level
            (module B)
            { genesis_ledger= ledger
            ; protocol_state_with_hash
            ; genesis_constants }
        in
        computed_values.genesis_proof
    | _ ->
        Coda_base.Proof.dummy

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
end

let load_genesis_constants (module M : Genesis_constants.Config_intf) ~path
    ~default ~logger =
  let config_res =
    Result.bind
      ( Result.try_with (fun () -> Yojson.Safe.from_file path)
      |> Result.map_error ~f:Exn.to_string )
      ~f:(fun json -> M.of_yojson json)
  in
  match config_res with
  | Ok config ->
      let new_constants = M.to_genesis_constants ~default config in
      Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
        "Overriding genesis constants $genesis_constants with the constants \
         $config_constants at $path. The new genesis constants are: \
         $new_genesis_constants"
        ~metadata:
          [ ("genesis_constants", Genesis_constants.(to_yojson default))
          ; ("new_genesis_constants", Genesis_constants.to_yojson new_constants)
          ; ("config_constants", M.to_yojson config)
          ; ("path", `String path) ] ;
      new_constants
  | Error s ->
      Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
        "Error loading genesis constants from $path: $error. Sample data: \
         $sample_data"
        ~metadata:
          [ ("path", `String path)
          ; ("error", `String s)
          ; ( "sample_data"
            , M.of_genesis_constants Genesis_constants.compiled |> M.to_yojson
            ) ] ;
      raise Genesis_state_initialization_error

let retrieve_genesis_state dir_opt ~logger ~conf_dir ~daemon_conf :
    (Genesis_ledger.Packed.t * Proof.t * Genesis_constants.t) Deferred.t =
  let open Cache_dir in
  let genesis_dir_name =
    Cache_dir.genesis_dir_name
      ~constraint_constants:Genesis_constants.Constraint_constants.compiled
      ~genesis_constants:Genesis_constants.compiled
      ~proof_level:Genesis_constants.Proof_level.compiled
  in
  let tar_filename = genesis_dir_name ^ ".tar.gz" in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Looking for the genesis tar file $filename"
    ~metadata:[("filename", `String tar_filename)] ;
  let s3_bucket_prefix =
    "https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net" ^/ tar_filename
  in
  let extract tar_dir =
    let target_dir = conf_dir ^/ genesis_dir_name in
    match%map
      Monitor.try_with_or_error ~extract_exn:true (fun () ->
          (*Delete any old genesis state*)
          let%bind () =
            File_system.remove_dir (conf_dir ^/ "coda_genesis_*")
          in
          (*Look for the tar and extract*)
          let tar_file = tar_dir ^/ genesis_dir_name ^ ".tar.gz" in
          Deferred.Or_error.ok_exn
          @@ Tar.extract ~root:conf_dir ~file:tar_file () )
    with
    | Ok () ->
        Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
          "Found genesis tar file at $source and extracted it to $path"
          ~metadata:[("source", `String tar_dir); ("path", `String target_dir)]
    | Error e ->
        Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
          "Error extracting genesis ledger and proof : $error"
          ~metadata:[("error", `String (Error.to_string_hum e))]
  in
  let retrieve tar_dir =
    Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
      "Retrieving genesis ledger and genesis proof from $path"
      ~metadata:[("path", `String tar_dir)] ;
    let%bind () = extract tar_dir in
    let extract_target = conf_dir ^/ genesis_dir_name in
    let ledger_dir = Ledger.path ~root:extract_target in
    let proof_file = Genesis_proof.path ~root:extract_target in
    let constants_file = extract_target ^/ "genesis_constants.json" in
    if
      Core.Sys.file_exists ledger_dir = `Yes
      && Core.Sys.file_exists proof_file = `Yes
      && Core.Sys.file_exists constants_file = `Yes
    then (
      let genesis_ledger =
        let ledger = Ledger.load ledger_dir in
        match
          Or_error.try_with (fun () ->
              Lazy.force (Genesis_ledger.Packed.t ledger) |> ignore )
        with
        | Ok _ ->
            ledger
        | Error e ->
            Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
              "Error loading the genesis ledger from $dir: $error"
              ~metadata:
                [ ("dir", `String ledger_dir)
                ; ("error", `String (Error.to_string_hum e)) ] ;
            raise Genesis_state_initialization_error
      in
      let genesis_constants =
        load_genesis_constants
          (module Genesis_constants.Config_file)
          ~default:Genesis_constants.compiled ~path:constants_file ~logger
      in
      let%map base_proof =
        match%map Genesis_proof.load proof_file with
        | Ok base_proof ->
            base_proof
        | Error e ->
            Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
              "Error reading the base proof from $file: $error"
              ~metadata:
                [ ("file", `String proof_file)
                ; ("error", `String (Error.to_string_hum e)) ] ;
            raise Genesis_state_initialization_error
      in
      Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
        "Successfully retrieved genesis ledger and genesis proof from $path"
        ~metadata:[("path", `String tar_dir)] ;
      Some (genesis_ledger, base_proof, genesis_constants) )
    else (
      Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
        "Error retrieving genesis ledger and genesis proof from $path"
        ~metadata:[("path", `String tar_dir)] ;
      Deferred.return None )
  in
  let res_or_fail dir_str = function
    | Some ((ledger, proof, (constants : Genesis_constants.t)) as res) ->
        (*Replace runtime-configurable constants from the dameon, if any*)
        Option.value_map daemon_conf ~default:res ~f:(fun daemon_config_file ->
            let new_constants =
              load_genesis_constants
                (module Genesis_constants.Daemon_config)
                ~default:constants ~path:daemon_config_file ~logger
            in
            (ledger, proof, new_constants) )
    | None ->
        Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
          "Could not retrieve genesis ledger and genesis proof from paths \
           $paths"
          ~metadata:[("paths", `String dir_str)] ;
        raise Genesis_state_initialization_error
  in
  match dir_opt with
  | Some dir ->
      let%map res = retrieve dir in
      res_or_fail dir res
  | None -> (
      let directories =
        [ autogen_path
        ; manual_install_path
        ; brew_install_path
        ; Cache_dir.s3_install_path ]
      in
      match%bind
        Deferred.List.fold directories ~init:None ~f:(fun acc dir ->
            if is_some acc then Deferred.return acc
            else
              match%map retrieve dir with
              | Some res ->
                  Some (res, dir)
              | None ->
                  None )
      with
      | Some (res, dir) ->
          Deferred.return (res_or_fail dir (Some res))
      | None ->
          (*Check if it's in s3*)
          let local_path = Cache_dir.s3_install_path ^/ tar_filename in
          let%bind () =
            match%map
              Cache_dir.load_from_s3 [s3_bucket_prefix] [local_path] ~logger
            with
            | Ok () ->
                ()
            | Error e ->
                Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
                  "Could not curl genesis ledger and genesis proof from $uri: \
                   $error"
                  ~metadata:
                    [ ("uri", `String s3_bucket_prefix)
                    ; ("error", `String (Error.to_string_hum e)) ]
          in
          let%map res = retrieve Cache_dir.s3_install_path in
          res_or_fail
            (String.concat ~sep:"," (s3_bucket_prefix :: directories))
            res )
