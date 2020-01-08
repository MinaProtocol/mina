open Core
open Async
open Coda_base

type exn += Genesis_state_initialization_error

let retrieve_genesis_state dir_opt ~logger :
    (Ledger.t lazy_t * Proof.t) Deferred.t =
  let open Cache_dir in
  let tar_filename = Cache_dir.genesis_dir_name ^ ".tar.gz" in
  let s3_bucket_prefix =
    "https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net" ^/ tar_filename
  in
  let extract dir =
    match%map
      Monitor.try_with_or_error ~extract_exn:true (fun () ->
          let genesis_dir = dir ^/ Cache_dir.genesis_dir_name in
          if Core.Sys.file_exists genesis_dir = `Yes then Deferred.return ()
          else
            (*Look for the tar and extract*)
            let tar_file = genesis_dir ^ ".tar.gz" in
            let%map _result =
              Process.run_exn ~prog:"tar"
                ~args:["-C"; dir; "-xzf"; tar_file]
                ()
            in
            () )
    with
    | Ok () ->
        ()
    | Error e ->
        Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
          "Error extracting genesis ledger and proof : $error"
          ~metadata:[("error", `String (Error.to_string_hum e))]
  in
  let retrieve dir =
    Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
      "Retrieving genesis ledger and genesis proof from $path"
      ~metadata:[("path", `String dir)] ;
    let%bind () = extract dir in
    let dir = dir ^/ Cache_dir.genesis_dir_name in
    let ledger_dir = dir ^/ "ledger" in
    let proof_file = dir ^/ "genesis_proof" in
    if
      Core.Sys.file_exists ledger_dir = `Yes
      && Core.Sys.file_exists proof_file = `Yes
    then (
      let genesis_ledger =
        let ledger = lazy (Ledger.create ~directory_name:ledger_dir ()) in
        match Or_error.try_with (fun () -> Lazy.force ledger |> ignore) with
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
      let%map base_proof =
        match%map
          Monitor.try_with_or_error ~extract_exn:true (fun () ->
              let%bind r = Reader.open_file proof_file in
              let%map contents =
                Pipe.to_list (Reader.lines r) >>| String.concat
              in
              Sexp.of_string contents |> Proof.Stable.V1.t_of_sexp )
        with
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
        ~metadata:[("path", `String dir)] ;
      Some (genesis_ledger, base_proof) )
    else (
      Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
        "Error retrieving genesis ledger and genesis proof from $path"
        ~metadata:[("path", `String dir)] ;
      Deferred.return None )
  in
  let res_or_fail dir_str = function
    | Some res ->
        res
    | None ->
        Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
          "Could not retrieve genesis ledger and genesis proof from $dir"
          ~metadata:[("dir", `String dir_str)] ;
        raise Genesis_state_initialization_error
  in
  match dir_opt with
  | Some dir ->
      let%map res = retrieve dir in
      res_or_fail dir res
  | None -> (
      let directories =
        [ manual_install_path
        ; brew_install_path
        ; Cache_dir.s3_install_path
        ; autogen_path ]
      in
      match%bind
        Deferred.List.fold directories ~init:None ~f:(fun acc dir ->
            if is_some acc then Deferred.return acc else retrieve dir )
      with
      | Some res ->
          Deferred.return res
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
            (String.concat ~sep:"," (s3_install_path :: directories))
            res )
