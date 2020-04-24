[%%import
"/src/config.mlh"]

open Core
open Async
open Currency
open Signature_lib
open Coda_base
open Coda_state

[%%if
proof_level = "full"]

let use_dummy_values = false

[%%else]

let use_dummy_values = true

[%%endif]

type t =
  { runtime_config: Runtime_config.t
  ; genesis_ledger: Genesis_ledger.Packed.t
  ; genesis_protocol_state: (Protocol_state.Value.t, State_hash.t) With_hash.t
  ; base_hash: State_hash.t
  ; base_proof: Proof.t }

let unit_test_base_hash = Snark_params.Tick.Field.zero

let unit_test_base_proof = Dummy_values.Tock.Bowe_gabizon18.proof

let for_unit_tests =
  lazy
    { runtime_config= Runtime_config.for_unit_tests
    ; genesis_ledger= Genesis_ledger.for_unit_tests
    ; genesis_protocol_state= Lazy.force Genesis_protocol_state.for_unit_tests
    ; base_hash= unit_test_base_hash
    ; base_proof= unit_test_base_proof }

module Config_account = struct
  let to_account i
      ({balance; public_key; private_key; delegate} :
        Runtime_config.Accounts.Account.t) =
    let public_key, private_key =
      match (public_key, private_key) with
      | Some public_key, private_key ->
          ( Public_key.Compressed.of_base58_check_exn public_key
          , Option.map ~f:Private_key.of_base58_check_exn private_key )
      | None, _ ->
          let keypair = (Lazy.force Coda_base.Sample_keypairs.keypairs).(i) in
          (fst keypair, Some (snd keypair))
    in
    let account =
      Account.create
        (Account_id.create public_key Token_id.default)
        (Balance.of_int balance)
    in
    ( private_key
    , { account with
        delegate=
          Option.value_map ~default:account.delegate
            ~f:Public_key.Compressed.of_base58_check_exn delegate } )
end

let get_accounts (runtime_config : Runtime_config.t) :
    (module Genesis_ledger.Intf.Accounts_intf) =
  match runtime_config.accounts with
  | Named name ->
      (module (val Genesis_ledger.fetch_ledger name))
  | Accounts accounts ->
      ( module struct
        let accounts = lazy (List.mapi ~f:Config_account.to_account accounts)
      end )

let get_ledger (runtime_config : Runtime_config.t) : Genesis_ledger.Packed.t =
  (module Genesis_ledger.Make ((val get_accounts runtime_config)))

let get_genesis_protocol_state ~genesis_ledger ~runtime_config =
  Genesis_protocol_state.t
    ~genesis_ledger:(Genesis_ledger.Packed.t genesis_ledger)
    ~runtime_config

(* Helper function for loading or generating the base proof. *)
let find_base_proof_aux ~runtime_config ~f =
  let genesis_ledger = get_ledger runtime_config in
  let genesis_protocol_state =
    get_genesis_protocol_state ~genesis_ledger ~runtime_config
  in
  let%map base_hash, base_proof =
    if use_dummy_values then
      return
        (Snark_params.Tick.Field.zero, Dummy_values.Tock.Bowe_gabizon18.proof)
    else
      let%bind (module Keys) = Keys_lib.Keys.create () in
      let base_hash = Keys.Step.instance_hash genesis_protocol_state.data in
      let%map base_proof =
        f ~runtime_config ~genesis_ledger ~genesis_protocol_state ~base_hash ()
      in
      (base_hash, base_proof)
  in
  { runtime_config
  ; genesis_ledger
  ; genesis_protocol_state
  ; base_hash
  ; base_proof }

let generate_base_proof ~logger ~runtime_config
    ~(genesis_ledger : Genesis_ledger.Packed.t) ~genesis_protocol_state
    ~base_hash:_ () =
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Generating base proof for configuration $config"
    ~metadata:[("config", Runtime_config.to_yojson runtime_config)] ;
  let%map (module K) = Keys_lib.Keys.create () in
  let (module M : Base_proof.S) =
    ( module Base_proof.Make
               (K)
               (struct
                 let config = runtime_config.protocol

                 module Genesis_ledger = (val genesis_ledger)

                 let protocol_state_with_hash = genesis_protocol_state
               end) )
  in
  M.base_proof

let load_base_proof ~logger directory =
  let open Option.Let_syntax in
  let runtime_config_path = directory ^/ "runtime_config.json" in
  let base_proof_path = directory ^/ "base_proof" in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Attempting to load runtime configuration from $runtime_config_path"
    ~metadata:[("runtime_config_path", `String runtime_config_path)] ;
  let%bind runtime_config =
    if Core.Sys.file_exists runtime_config_path = `Yes then (
      match
        Or_error.try_with (fun () ->
            Yojson.Safe.from_file ~fname:runtime_config_path
              runtime_config_path
            |> Runtime_config.of_yojson )
      with
      | Ok (Ok x) ->
          Some x
      | Ok (Error err) ->
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            "Error parsing JSON from $runtime_config_path: $error"
            ~metadata:
              [ ("runtime_config_path", `String runtime_config_path)
              ; ("error", `String err) ] ;
          None
      | Error err ->
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            "Error loading from $runtime_config_path: $error"
            ~metadata:
              [ ("runtime_config_path", `String runtime_config_path)
              ; ("error", `String (Error.to_string_hum err)) ] ;
          None )
    else (
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "File $runtime_config_path not found"
        ~metadata:[("runtime_config_path", `String runtime_config_path)] ;
      None )
  in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Attempting to load base proof from $base_proof_path"
    ~metadata:[("base_proof_path", `String base_proof_path)] ;
  let%map base_proof =
    if Core.Sys.file_exists base_proof_path = `Yes then (
      match
        Or_error.try_with (fun () ->
            In_channel.with_file ~binary:true base_proof_path
              ~f:(fun base_proof_file ->
                let length =
                  Option.value_exn
                    (Int64.to_int (In_channel.length base_proof_file))
                in
                let buffer = Bigstring.create length in
                Bigstring.really_input base_proof_file buffer ;
                Proof.Stable.Latest.bin_read_t buffer ~pos_ref:(ref 0) ) )
      with
      | Ok x ->
          Some x
      | Error err ->
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            "Error loading from $base_proof_path: $error"
            ~metadata:
              [ ("base_proof_path", `String base_proof_path)
              ; ("error", `String (Error.to_string_hum err)) ] ;
          None )
    else (
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "File $base_proof_path not found"
        ~metadata:[("base_proof_path", `String base_proof_path)] ;
      None )
  in
  (runtime_config, base_proof)

let s3_bucket_prefix =
  "https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net"

let fetch_base_proof ~logger ~runtime_config ~genesis_ledger:_
    ~genesis_protocol_state:_ ~base_hash () =
  let base_hash_string = State_hash.to_string base_hash in
  let dirname = "base_proof_" ^ base_hash_string in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Searching for base proof for configuration $config. Using $dirname as \
     directory name"
    ~metadata:
      [ ("config", Runtime_config.to_yojson runtime_config)
      ; ("dirname", `String dirname) ] ;
  let directories =
    Cache_dir.
      [autogen_path; manual_install_path; brew_install_path; s3_install_path]
  in
  match
    List.find_map directories ~f:(fun directory ->
        load_base_proof ~logger (directory ^/ dirname) )
  with
  | Some (runtime_config, base_proof) ->
      (* TODO: Check that the runtime config is the same. *)
      ignore runtime_config ; return (Some base_proof)
  | None ->
      let tar_filename = dirname ^/ ".tar.gz" in
      let s3_url = s3_bucket_prefix ^/ tar_filename in
      let local_path = Cache_dir.s3_install_path ^/ tar_filename in
      let s3_install_dirname = s3_bucket_prefix ^/ dirname in
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "No local base proof found for $base_hash. Attempting to load from S3 \
         $url"
        ~metadata:
          [("base_hash", `String base_hash_string); ("url", `String s3_url)] ;
      let%bind load_res =
        Cache_dir.load_from_s3 [s3_bucket_prefix] [local_path] ~logger
      in
      let%map extract_res =
        match load_res with
        | Ok () ->
            Logger.info logger ~module_:__MODULE__ ~location:__LOC__
              "Loaded base proof from S3 $url. Extracting into $dirname"
              ~metadata:
                [ ("url", `String s3_url)
                ; ("dirname", `String s3_install_dirname) ] ;
            let%map _result =
              Process.run_exn ~prog:"tar"
                ~args:["-C"; s3_install_dirname; "-xzf"; local_path]
                ()
            in
            Some ()
        | Error e ->
            Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
              "Could not load base proof from from S3 $url: $error"
              ~metadata:
                [ ("url", `String s3_url)
                ; ("error", `String (Error.to_string_hum e)) ] ;
            return None
      in
      let open Option.Let_syntax in
      let%bind () = extract_res in
      let%map runtime_config, base_proof =
        load_base_proof ~logger s3_install_dirname
      in
      (* TODO: Check that the runtime config is the same. *)
      ignore runtime_config ; base_proof

let store_base_proof ~root_directory
    ({runtime_config; base_hash; base_proof; _} : t) =
  let base_hash_string = State_hash.to_string base_hash in
  let dir_name = "base_proof_" ^ base_hash_string in
  let dir_path = root_directory ^/ dir_name in
  let runtime_config_path = dir_path ^/ "runtime_config.json" in
  let base_proof_path = dir_path ^/ "base_proof" in
  let%map () = File_system.create_dir dir_path ~clear_if_exists:true in
  Yojson.Safe.to_file runtime_config_path
    (Runtime_config.to_yojson runtime_config) ;
  Out_channel.with_file base_proof_path ~binary:true ~f:(fun base_proof_file ->
      let buf =
        Bin_prot.Utils.bin_dump Proof.Stable.Latest.bin_writer_t base_proof
      in
      ignore @@ Bigstring.output base_proof_file buf )

let create_tar ~base_hash ?tar_file directory =
  let base_hash_string = State_hash.to_string base_hash in
  let dir_name = "base_proof_" ^ base_hash_string in
  let dir_path = directory ^/ dir_name in
  let tar_file =
    Option.value_map ~default:(dir_path ^ ".tar.gz") tar_file
      ~f:(fun tar_file ->
        if Filename.is_absolute tar_file then tar_file
        else Core.Sys.getcwd () ^/ tar_file )
  in
  let%map _result =
    Process.run_exn ~prog:"tar"
      ~args:["-C"; directory; "-czf"; tar_file; dir_path]
      ()
  in
  ()

let load_values ~logger ~not_found ~runtime_config () =
  let store = ref false in
  let retrieve ~runtime_config ~genesis_ledger ~genesis_protocol_state
      ~base_hash () =
    let%bind found_base_proof =
      Monitor.try_with_or_error (fun () ->
          fetch_base_proof ~logger ~runtime_config ~genesis_ledger
            ~genesis_protocol_state ~base_hash () )
    in
    let found_base_proof =
      match found_base_proof with
      | Ok x ->
          x
      | Error err ->
          Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
            "Encountered an error while finding a base proof: $error"
            ~metadata:[("error", `String (Error.to_string_hum err))] ;
          None
    in
    match found_base_proof with
    | Some base_proof ->
        return base_proof
    | None -> (
      match not_found with
      | `Generate | `Generate_and_store ->
          store := not_found = `Generate_and_store ;
          let%map base_proof =
            generate_base_proof ~logger ~runtime_config ~genesis_ledger
              ~genesis_protocol_state ~base_hash ()
          in
          base_proof
      | `Error ->
          Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
            "Could not find an appropriate base proof" ;
          failwith "Could not find an appropriate base proof" )
  in
  Monitor.try_with_or_error (fun () ->
      let%bind t = find_base_proof_aux ~runtime_config ~f:retrieve in
      let%map () =
        if !store then
          store_base_proof ~root_directory:Cache_dir.autogen_path t
        else return ()
      in
      t )

let of_base_proof ~runtime_config ~base_proof =
  let genesis_ledger = get_ledger runtime_config in
  let genesis_protocol_state =
    get_genesis_protocol_state ~genesis_ledger ~runtime_config
  in
  let%map base_hash =
    if use_dummy_values then return Snark_params.Tick.Field.zero
    else
      let%map (module Keys) = Keys_lib.Keys.create () in
      let base_hash = Keys.Step.instance_hash genesis_protocol_state.data in
      base_hash
  in
  { runtime_config
  ; genesis_ledger
  ; genesis_protocol_state
  ; base_hash
  ; base_proof }
