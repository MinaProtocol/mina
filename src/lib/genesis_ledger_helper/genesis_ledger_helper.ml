open Core
open Async
open Signature_lib
open Mina_base

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
          ; file ]
        ()
    with
    | Ok _ ->
        Ok ()
    | Error err ->
        Error (Error.tag err ~tag:"Error extracting tar file")
end

let file_exists ?follow_symlinks filename =
  match%map Sys.file_exists ?follow_symlinks filename with
  | `Yes ->
      true
  | _ ->
      false

module Accounts = struct
  module Single = struct
    let to_account_with_pk :
        Runtime_config.Accounts.Single.t -> Mina_base.Account.t Or_error.t =
     fun t ->
      let open Or_error.Let_syntax in
      let%bind pk =
        match t.pk with
        | Some pk ->
            Ok (Signature_lib.Public_key.Compressed.of_base58_check_exn pk)
        | None ->
            Or_error.errorf
              !"No public key to create the account from runtime config \
                %{sexp: Runtime_config.Accounts.Single.t}"
              t
      in
      let delegate =
        Option.map ~f:Signature_lib.Public_key.Compressed.of_base58_check_exn
          t.delegate
      in
      let token_id =
        Option.value_map t.token ~default:Token_id.default
          ~f:Mina_base.Token_id.of_uint64
      in
      let account_id = Mina_base.Account_id.create pk token_id in
      let account =
        match t.timing with
        | Some
            { initial_minimum_balance
            ; cliff_time
            ; cliff_amount
            ; vesting_period
            ; vesting_increment } ->
            Mina_base.Account.create_timed account_id t.balance
              ~initial_minimum_balance ~cliff_time ~cliff_amount
              ~vesting_period ~vesting_increment
            |> Or_error.ok_exn
        | None ->
            Mina_base.Account.create account_id t.balance
      in
      let permissions =
        match t.permissions with
        | None ->
            account.permissions
        | Some
            { stake
            ; edit_state
            ; send
            ; receive
            ; set_delegate
            ; set_permissions
            ; set_verification_key } ->
            let auth_required a =
              match a with
              | Runtime_config.Accounts.Single.Permissions.Auth_required.None
                ->
                  Mina_base.Permissions.Auth_required.None
              | Either ->
                  Either
              | Proof ->
                  Proof
              | Signature ->
                  Signature
              | Both ->
                  Both
              | Impossible ->
                  Impossible
            in
            { Mina_base.Permissions.Poly.stake
            ; edit_state= auth_required edit_state
            ; send= auth_required send
            ; receive= auth_required receive
            ; set_delegate= auth_required set_delegate
            ; set_permissions= auth_required set_permissions
            ; set_verification_key= auth_required set_verification_key }
      in
      let token_permissions =
        Option.value_map t.token_permissions ~default:account.token_permissions
          ~f:(fun {token_owned; disable_new_accounts; account_disabled} ->
            if token_owned then
              Mina_base.Token_permissions.Token_owned {disable_new_accounts}
            else Not_owned {account_disabled} )
      in
      let%map snapp =
        match t.snapp with
        | None ->
            Ok None
        | Some {state; verification_key} ->
            let%bind app_state =
              if
                Pickles_types.Vector.Nat.to_int Snapp_state.Max_state_size.n
                <> List.length state
              then
                Or_error.errorf
                  !"Snap account state has invalid length %{sexp: \
                    Runtime_config.Accounts.Single.t} length: %d"
                  t (List.length state)
              else Ok (Snapp_state.V.of_list_exn state)
            in
            let%map verification_key =
              (* Use a URI-safe alphabet to make life easier for maintaining json
                   We prefer this to base58-check here because users should not
                   be manually entering verification keys.
                *)
              Option.value_map ~default:(Ok None) verification_key
                ~f:(fun verification_key ->
                  let%map vk =
                    Base64.decode ~alphabet:Base64.uri_safe_alphabet
                      verification_key
                    |> Result.map_error ~f:(function `Msg s ->
                           Error.createf
                             !"Could not parse verification key account \
                               %{sexp:Runtime_config.Accounts.Single.t}: %s"
                             t s )
                    |> Result.map
                         ~f:
                           (Binable.of_string
                              ( module Pickles.Side_loaded.Verification_key
                                       .Stable
                                       .Latest ))
                  in
                  Some
                    (With_hash.of_data ~hash_data:Snapp_account.digest_vk vk)
              )
            in
            Some {Snapp_account.verification_key; app_state}
      in
      { account with
        delegate=
          (if Option.is_some delegate then delegate else account.delegate)
      ; token_id
      ; token_permissions
      ; nonce= Account.Nonce.of_uint32 t.nonce
      ; receipt_chain_hash=
          Option.value_map t.receipt_chain_hash
            ~default:account.receipt_chain_hash
            ~f:Mina_base.Receipt.Chain_hash.of_base58_check_exn
      ; voting_for=
          Option.value_map ~default:account.voting_for
            ~f:Mina_base.State_hash.of_base58_check_exn t.voting_for
      ; snapp
      ; permissions }

    let of_account :
           Mina_base.Account.t
        -> Signature_lib.Private_key.t option
        -> Runtime_config.Accounts.Single.t =
     fun account sk ->
      let timing =
        match account.timing with
        | Account.Timing.Untimed ->
            None
        | Timed t ->
            Some
              { Runtime_config.Accounts.Single.Timed.initial_minimum_balance=
                  t.initial_minimum_balance
              ; cliff_time= t.cliff_time
              ; cliff_amount= t.cliff_amount
              ; vesting_period= t.vesting_period
              ; vesting_increment= t.vesting_increment }
      in
      let token_permissions =
        match account.token_permissions with
        | Mina_base.Token_permissions.Token_owned {disable_new_accounts} ->
            Some
              { Runtime_config.Accounts.Single.Token_permissions.token_owned=
                  true
              ; disable_new_accounts
              ; account_disabled= false }
        | Not_owned {account_disabled} ->
            Some
              { token_owned= false
              ; disable_new_accounts= false
              ; account_disabled }
      in
      let permissions =
        let auth_required a =
          match a with
          | Mina_base.Permissions.Auth_required.None ->
              Runtime_config.Accounts.Single.Permissions.Auth_required.None
          | Either ->
              Either
          | Proof ->
              Proof
          | Signature ->
              Signature
          | Both ->
              Both
          | Impossible ->
              Impossible
        in
        let { Mina_base.Permissions.Poly.stake
            ; edit_state
            ; send
            ; receive
            ; set_delegate
            ; set_permissions
            ; set_verification_key } =
          account.permissions
        in
        Some
          { Runtime_config.Accounts.Single.Permissions.stake
          ; edit_state= auth_required edit_state
          ; send= auth_required send
          ; receive= auth_required receive
          ; set_delegate= auth_required set_delegate
          ; set_permissions= auth_required set_permissions
          ; set_verification_key= auth_required set_verification_key }
      in
      let snapp =
        Option.map account.snapp ~f:(fun {app_state; verification_key} ->
            let state = Snapp_state.V.to_list app_state in
            let verification_key =
              Option.map verification_key ~f:(fun vk ->
                  With_hash.data vk
                  |> Binable.to_string
                       ( module Pickles.Side_loaded.Verification_key.Stable
                                .Latest )
                  |> Base64.encode_exn ~alphabet:Base64.uri_safe_alphabet )
            in
            { Runtime_config.Accounts.Single.Snapp_account.state
            ; verification_key } )
      in
      { pk=
          Some
            (Signature_lib.Public_key.Compressed.to_base58_check
               account.public_key)
      ; sk= Option.map ~f:Signature_lib.Private_key.to_base58_check sk
      ; balance= account.balance
      ; delegate=
          Option.map ~f:Signature_lib.Public_key.Compressed.to_base58_check
            account.delegate
      ; timing
      ; token= Some (Mina_base.Token_id.to_uint64 account.token_id)
      ; token_permissions
      ; nonce= account.nonce
      ; receipt_chain_hash=
          Some
            (Mina_base.Receipt.Chain_hash.to_base58_check
               account.receipt_chain_hash)
      ; voting_for=
          Some (Mina_base.State_hash.to_base58_check account.voting_for)
      ; snapp
      ; permissions }
  end

  let to_full :
      Runtime_config.Accounts.t -> (Private_key.t option * Account.t) list =
    List.mapi
      ~f:(fun i ({Runtime_config.Accounts.pk; sk; _} as account_config) ->
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
        let pk =
          match pk with
          | Some pk ->
              pk
          | None ->
              Public_key.Compressed.to_base58_check
                (Quickcheck.random_value
                   ~seed:
                     (`Deterministic
                       ("fake pk for genesis ledger " ^ string_of_int i))
                   Public_key.Compressed.gen)
        in
        let account =
          Single.to_account_with_pk {account_config with pk= Some pk}
          |> Or_error.ok_exn
        in
        (sk, account) )

  let gen_with_balance balance :
      (Private_key.t option * Account.t) Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%map pk = Signature_lib.Public_key.Compressed.gen in
    (None, Account.create (Account_id.create pk Token_id.default) balance)

  let gen : (Private_key.t option * Account.t) Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%bind balance = Int.gen_incl 10 500 >>| Currency.Balance.of_int in
    gen_with_balance balance

  let generate n : (Private_key.t option * Account.t) list =
    let open Quickcheck in
    random_value ~seed:(`Deterministic "fake accounts for genesis ledger")
      (Generator.list_with_length n gen)

  (* This implements a tail-recursive generator using the low-level primitives
     so that we don't blow out the stack.
  *)
  let gen_balances_rev balances :
      (Private_key.t option * Account.t) list Quickcheck.Generator.t =
    match balances with
    | [] ->
        Quickcheck.Generator.return []
    | (n, balance) :: balances_tl ->
        Quickcheck.Generator.create (fun ~size ~random ->
            let rec gen_balances_rev n balance balances_tl accounts =
              if n > 0 then
                let new_random = Splittable_random.State.split random in
                let account =
                  (* Manually generate an account using the [generate] primitive. *)
                  Quickcheck.Generator.generate ~size ~random:new_random
                    (gen_with_balance balance)
                in
                gen_balances_rev (n - 1) balance balances_tl
                  (account :: accounts)
              else
                match balances_tl with
                | [] ->
                    accounts
                | (n, balance) :: balances_tl ->
                    gen_balances_rev n balance balances_tl accounts
            in
            gen_balances_rev n balance balances_tl [] )

  let pad_with_rev_balances balances accounts =
    let balances_accounts =
      Quickcheck.random_value
        ~seed:(`Deterministic "fake accounts with balances for genesis ledger")
        (gen_balances_rev balances)
    in
    List.append accounts balances_accounts

  (* NOTE: When modifying this function, be very careful to ensure that all
     operations are tail-recursive, otherwise a sufficiently large genesis
     ledger will blow the stack.
     In particular, do not use any functions that return values of the form
     [_ :: _], since this construction is NOT tail-recursive.
  *)
  let pad_to n accounts =
    if n <= 0 then accounts
    else
      let exception Stop in
      try
        (* Count accounts and reverse the list while we're doing so to avoid
           re-traversing the list.
        *)
        let rev_accounts, count =
          List.fold ~init:([], 0) accounts ~f:(fun (acc, count) account ->
              let count = count + 1 in
              if count >= n then raise Stop ;
              (account :: acc, count + 1) )
        in
        (* [rev_append] is tail-recursive, and we've already reversed the list,
           so we can avoid calling [append] which may internally reverse the
           list again where it is sufficiently long.
        *)
        List.rev_append rev_accounts (generate (n - count))
      with Stop -> accounts
end

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
          Snark_params.Tick.Field.to_string Mina_base.Account.empty_digest
        ; (* Distinguish ledgers when the account record layout has changed. *)
          Bin_prot.Writer.to_string
            Mina_base.Account.Stable.Latest.bin_writer_t
            Mina_base.Account.empty ]
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
    let search_paths = Cache_dir.possible_paths "" @ [genesis_dir] in
    let file_exists filename path =
      let filename = path ^/ filename in
      if%map file_exists ~follow_symlinks:true filename then (
        [%log trace] "Found $ledger file at $path"
          ~metadata:
            [("ledger", `String ledger_name_prefix); ("path", `String filename)] ;
        Some filename )
      else (
        [%log trace] "Ledger file $path does not exist"
          ~metadata:[("path", `String filename)] ;
        None )
    in
    let load_from_s3 filename =
      let s3_path = s3_bucket_prefix ^/ filename in
      let local_path = Cache_dir.s3_install_path ^/ filename in
      match%bind Cache_dir.load_from_s3 [s3_path] [local_path] ~logger with
      | Ok () ->
          file_exists filename Cache_dir.s3_install_path
      | Error _ ->
          [%log trace] "Could not download $ledger from $uri"
            ~metadata:
              [("ledger", `String ledger_name_prefix); ("uri", `String s3_path)] ;
          return None
    in
    let%bind hash_filename =
      match config.hash with
      | Some hash -> (
          let hash_filename = hash_filename hash ~ledger_name_prefix in
          let%bind tar_path =
            Deferred.List.find_map ~f:(file_exists hash_filename) search_paths
          in
          match tar_path with
          | Some _ ->
              return tar_path
          | None ->
              load_from_s3 hash_filename )
      | None ->
          return None
    in
    let search_local_and_s3 ?other_data name =
      let named_filename =
        named_filename ~constraint_constants ~num_accounts:config.num_accounts
          ~balances:config.balances ~ledger_name_prefix ?other_data name
      in
      match%bind
        Deferred.List.find_map ~f:(file_exists named_filename) search_paths
      with
      | Some path ->
          return (Some path)
      | None ->
          load_from_s3 named_filename
    in
    match hash_filename with
    | Some filename ->
        return (Some filename)
    | None -> (
      match (config.base, config.name) with
      | Named name, _ ->
          let named_filename =
            named_filename ~constraint_constants
              ~num_accounts:config.num_accounts ~balances:config.balances
              ~ledger_name_prefix name
          in
          Deferred.List.find_map ~f:(file_exists named_filename) search_paths
      | Accounts accounts, _ ->
          search_local_and_s3 ~other_data:(accounts_hash accounts) "accounts"
      | Hash hash, None ->
          assert (Some hash = config.hash) ;
          return None
      | _, Some name ->
          search_local_and_s3 name )

  let load_from_tar ?(genesis_dir = Cache_dir.autogen_path) ~logger
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ?accounts ~ledger_name_prefix filename =
    [%log trace] "Loading $ledger from $path"
      ~metadata:
        [("ledger", `String ledger_name_prefix); ("path", `String filename)] ;
    let dirname = Uuid.to_string (Uuid_unix.create ()) in
    (* Unpack the ledger in the autogen directory, since we know that we have
       write permissions there.
    *)
    let dirname = genesis_dir ^/ dirname in
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

  let generate_tar ~genesis_dir ~logger ~ledger_name_prefix ledger =
    Ledger.commit ledger ;
    let dirname = Option.value_exn (Ledger.get_directory ledger) in
    let root_hash = State_hash.to_string @@ Ledger.merkle_root ledger in
    let%bind () = Unix.mkdir ~p:() genesis_dir in
    let tar_path =
      genesis_dir ^/ hash_filename root_hash ~ledger_name_prefix
    in
    [%log trace]
      "Creating $ledger tar file for $root_hash at $path from database at $dir"
      ~metadata:
        [ ("ledger", `String ledger_name_prefix)
        ; ("root_hash", `String root_hash)
        ; ("path", `String tar_path)
        ; ("dir", `String dirname) ] ;
    let open Deferred.Or_error.Let_syntax in
    let%map () = Tar.create ~root:dirname ~file:tar_path ~directory:"." () in
    tar_path

  let padded_accounts_from_runtime_config_opt ~logger ~proof_level
      ~ledger_name_prefix (config : Runtime_config.Ledger.t) =
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
        let pk, _ = Mina_state.Consensus_state_hooks.genesis_winner in
        match accounts with
        | (_, account) :: _
          when Public_key.Compressed.equal (Account.public_key account) pk ->
            accounts
        | _ ->
            ( None
            , Account.create
                (Account_id.create pk Token_id.default)
                (Currency.Balance.of_int 1000) )
            :: accounts
      else accounts
    in
    let accounts_opt =
      match config.base with
      | Hash _ ->
          None
      | Accounts accounts ->
          Some (lazy (add_genesis_winner_account (Accounts.to_full accounts)))
      | Named name -> (
        match Genesis_ledger.fetch_ledger name with
        | Some (module M) ->
            [%log trace] "Found $ledger with name $ledger_name"
              ~metadata:
                [ ("ledger", `String ledger_name_prefix)
                ; ("ledger_name", `String name) ] ;
            Some (Lazy.map ~f:add_genesis_winner_account M.accounts)
        | None ->
            [%log trace] "Could not find a built-in $ledger named $ledger_name"
              ~metadata:
                [ ("ledger", `String ledger_name_prefix)
                ; ("ledger_name", `String name) ] ;
            None )
    in
    let padded_accounts_with_balances_opt =
      Option.map accounts_opt
        ~f:
          (Lazy.map
             ~f:(Accounts.pad_with_rev_balances (List.rev config.balances)))
    in
    Option.map padded_accounts_with_balances_opt
      ~f:
        (Lazy.map
           ~f:(Accounts.pad_to (Option.value ~default:0 config.num_accounts)))

  let packed_genesis_ledger_of_accounts ~depth accounts :
      Genesis_ledger.Packed.t =
    ( module Genesis_ledger.Make (struct
      let accounts = accounts

      let directory = `New

      let depth = depth
    end) )

  let load ~proof_level ~genesis_dir ~logger ~constraint_constants
      ?(ledger_name_prefix = "genesis_ledger")
      (config : Runtime_config.Ledger.t) =
    Monitor.try_with_join_or_error (fun () ->
        let padded_accounts_opt =
          padded_accounts_from_runtime_config_opt ~logger ~proof_level
            ~ledger_name_prefix config
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
                ?accounts:padded_accounts_opt ~ledger_name_prefix tar_path
            with
            | Ok ledger ->
                Ok (ledger, config, tar_path)
            | Error err ->
                [%log error] "Could not load ledger from $path: $error"
                  ~metadata:
                    [ ("path", `String tar_path)
                    ; ("error", Error_json.error_to_yojson err) ] ;
                Error err )
        | None -> (
          match padded_accounts_opt with
          | None -> (
            match config.base with
            | Accounts _ ->
                assert false
            | Hash hash ->
                [%log error]
                  "Could not find or generate a $ledger for $root_hash"
                  ~metadata:
                    [ ("ledger", `String ledger_name_prefix)
                    ; ("root_hash", `String hash) ] ;
                Deferred.Or_error.errorf
                  "Could not find a ledger tar file for hash '%s'" hash
            | Named ledger_name ->
                let ledger_filename =
                  named_filename ~constraint_constants
                    ~num_accounts:config.num_accounts ~balances:config.balances
                    ~ledger_name_prefix ledger_name
                in
                [%log error]
                  "Bad config $config: $ledger named $ledger_name is not \
                   built in, and no ledger file was found at $ledger_filename"
                  ~metadata:
                    [ ("ledger", `String ledger_name_prefix)
                    ; ("config", Runtime_config.Ledger.to_yojson config)
                    ; ("ledger_name", `String ledger_name)
                    ; ("ledger_filename", `String ledger_filename) ] ;
                Deferred.Or_error.errorf "ledger '%s' not found" ledger_name )
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
                  hash= Some (State_hash.to_string @@ Ledger.merkle_root ledger)
                }
              in
              let name, other_data =
                match (config.base, config.name) with
                | Named name, _ ->
                    (Some name, None)
                | Accounts accounts, _ ->
                    (Some "accounts", Some (accounts_hash accounts))
                | Hash _, None ->
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
                    Deferred.Or_error.try_with (fun () -> Sys.remove link_name)
                    |> Deferred.ignore
                  in
                  (* Add a symlink from the named path to the hash path. *)
                  let%map () = Unix.symlink ~target:tar_path ~link_name in
                  [%log trace]
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
                  let tar_path =
                    genesis_dir ^/ hash_filename root_hash ~ledger_name_prefix
                  in
                  [%log error]
                    "Could not generate a $ledger file at $path: $error"
                    ~metadata:
                      [ ("ledger", `String ledger_name_prefix)
                      ; ("path", `String tar_path)
                      ; ("error", Error_json.error_to_yojson err) ] ;
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
        let%bind staking, config' =
          let%map staking_ledger, config', ledger_file =
            load_ledger config.staking.ledger
          in
          [%log trace] "Loaded staking epoch ledger from $ledger_file"
            ~metadata:[("ledger_file", `String ledger_file)] ;
          ( { Consensus.Genesis_epoch_data.Data.ledger=
                Genesis_ledger.Packed.t staking_ledger
            ; seed= Epoch_seed.of_string config.staking.seed }
          , {config.staking with ledger= config'} )
        in
        let%map next, config'' =
          match config.next with
          | None ->
              [%log trace]
                "Configured next epoch ledger to be the same as the staking \
                 epoch ledger" ;
              Deferred.Or_error.return (None, None)
          | Some {ledger; seed} ->
              let%map next_ledger, config'', ledger_file =
                load_ledger ledger
              in
              [%log trace] "Loaded next epoch ledger from $ledger_file"
                ~metadata:[("ledger_file", `String ledger_file)] ;
              ( Some
                  { Consensus.Genesis_epoch_data.Data.ledger=
                      Genesis_ledger.Packed.t next_ledger
                  ; seed= Epoch_seed.of_string seed }
              , Some {Runtime_config.Epoch_data.Data.ledger= config''; seed} )
        in
        ( Some {Consensus.Genesis_epoch_data.staking; next}
        , Some {Runtime_config.Epoch_data.staking= config'; next= config''} )
end

(* This hash encodes the data that determines a genesis proof:
   1. The blockchain snark constraint system
   2. The genesis protocol state (including the genesis ledger)

   It is used to determine whether we should make a new genesis proof, or use the
   one generated at compile-time.
*)
module Base_hash : sig
  type t [@@deriving eq, yojson]

  val create : id:Pickles.Verification_key.Id.t -> state_hash:State_hash.t -> t

  val to_string : t -> string
end = struct
  type t = string [@@deriving eq, yojson]

  let to_string = Fn.id

  let create ~id ~state_hash =
    Pickles.Verification_key.Id.to_string id
    |> ( ^ ) (State_hash.to_string state_hash)
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
          ~metadata:[("path", `String filename)] ;
        Some filename )
      else (
        [%log info] "Genesis proof file $path does not exist"
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
            [%log info]
              "Could not download genesis proof file from $uri: $error"
              ~metadata:
                [ ("uri", `String s3_path)
                ; ("error", Error_json.error_to_yojson e) ] ;
            return None )

  let generate_inputs ~runtime_config ~proof_level ~ledger ~genesis_epoch_data
      ~constraint_constants ~blockchain_proof_system_id
      ~(genesis_constants : Genesis_constants.t) =
    let consensus_constants =
      Consensus.Constants.create ~constraint_constants
        ~protocol_constants:genesis_constants.protocol
    in
    let protocol_state_with_hash =
      Mina_state.Genesis_protocol_state.t
        ~genesis_ledger:(Genesis_ledger.Packed.t ledger)
        ~genesis_epoch_data ~constraint_constants ~consensus_constants
    in
    { Genesis_proof.Inputs.runtime_config
    ; constraint_constants
    ; proof_level
    ; blockchain_proof_system_id
    ; genesis_ledger= ledger
    ; genesis_epoch_data
    ; consensus_constants
    ; protocol_state_with_hash
    ; genesis_constants }

  let blockchain_snark_state (inputs : Genesis_proof.Inputs.t) :
      (module Blockchain_snark.Blockchain_snark_state.S) =
    let module T = Transaction_snark.Make (struct
      let constraint_constants = inputs.constraint_constants
    end) in
    ( module Blockchain_snark.Blockchain_snark_state.Make (struct
      let tag = T.tag

      let constraint_constants = inputs.constraint_constants

      let proof_level = inputs.proof_level
    end) )

  let generate b (inputs : Genesis_proof.Inputs.t) =
    match inputs.proof_level with
    | Genesis_constants.Proof_level.Full ->
        let (module B) =
          match b with Some b -> b | None -> blockchain_snark_state inputs
        in
        let computed_values =
          Genesis_proof.create_values
            (module B)
            { genesis_ledger= inputs.genesis_ledger
            ; genesis_epoch_data= inputs.genesis_epoch_data
            ; runtime_config= inputs.runtime_config
            ; proof_level= inputs.proof_level
            ; blockchain_proof_system_id= Some (Lazy.force B.Proof.id)
            ; protocol_state_with_hash= inputs.protocol_state_with_hash
            ; genesis_constants= inputs.genesis_constants
            ; consensus_constants= inputs.consensus_constants
            ; constraint_constants= inputs.constraint_constants }
        in
        computed_values
    | _ ->
        Deferred.return
          { Genesis_proof.runtime_config= inputs.runtime_config
          ; constraint_constants= inputs.constraint_constants
          ; proof_level= inputs.proof_level
          ; genesis_constants= inputs.genesis_constants
          ; genesis_ledger= inputs.genesis_ledger
          ; genesis_epoch_data= inputs.genesis_epoch_data
          ; consensus_constants= inputs.consensus_constants
          ; protocol_state_with_hash= inputs.protocol_state_with_hash
          ; genesis_proof= Mina_base.Proof.blockchain_dummy }

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

  let id_to_json x =
    `String (Sexp.to_string (Pickles.Verification_key.Id.sexp_of_t x))

  let load_or_generate ~genesis_dir ~logger ~may_generate
      (inputs : Genesis_proof.Inputs.t) =
    let proof_needed =
      match inputs.proof_level with Full -> true | _ -> false
    in
    let b, id =
      match (inputs.blockchain_proof_system_id, inputs.proof_level) with
      | Some id, _ ->
          (None, id)
      | None, Full ->
          let ((module B) as b) = blockchain_snark_state inputs in
          (Some b, Lazy.force B.Proof.id)
      | _ ->
          (None, Pickles.Verification_key.Id.dummy ())
    in
    let compiled = Precomputed_values.compiled in
    let base_hash =
      Base_hash.create ~id ~state_hash:inputs.protocol_state_with_hash.hash
    in
    let compiled_base_hash =
      Base_hash.create
        ~id:(Precomputed_values.blockchain_proof_system_id ())
        ~state_hash:(Lazy.force compiled).protocol_state_with_hash.hash
    in
    let%bind found_proof =
      match%bind find_file ~logger ~base_hash ~genesis_dir with
      | Some file -> (
          match%map load file with
          | Ok genesis_proof ->
              Some
                ( { Genesis_proof.runtime_config= inputs.runtime_config
                  ; constraint_constants= inputs.constraint_constants
                  ; proof_level= inputs.proof_level
                  ; genesis_constants= inputs.genesis_constants
                  ; genesis_ledger= inputs.genesis_ledger
                  ; genesis_epoch_data= inputs.genesis_epoch_data
                  ; consensus_constants= inputs.consensus_constants
                  ; protocol_state_with_hash= inputs.protocol_state_with_hash
                  ; genesis_proof }
                , file )
          | Error err ->
              [%log error] "Could not load genesis proof from $path: $error"
                ~metadata:
                  [ ("path", `String file)
                  ; ("error", Error_json.error_to_yojson err) ] ;
              None )
      | None ->
          return None
    in
    match found_proof with
    | Some found_proof ->
        return (Ok found_proof)
    | None
      when Base_hash.equal base_hash compiled_base_hash || not proof_needed ->
        let compiled = Lazy.force compiled in
        [%log info]
          "Base hash $computed_hash matches compile-time $compiled_hash, \
           using precomputed genesis proof"
          ~metadata:
            [ ("computed_hash", Base_hash.to_yojson base_hash)
            ; ("compiled_hash", Base_hash.to_yojson compiled_base_hash) ] ;
        let filename = genesis_dir ^/ filename ~base_hash in
        let values =
          { Genesis_proof.runtime_config= inputs.runtime_config
          ; constraint_constants= inputs.constraint_constants
          ; proof_level= inputs.proof_level
          ; genesis_constants= inputs.genesis_constants
          ; genesis_ledger= inputs.genesis_ledger
          ; genesis_epoch_data= inputs.genesis_epoch_data
          ; consensus_constants= inputs.consensus_constants
          ; protocol_state_with_hash= inputs.protocol_state_with_hash
          ; genesis_proof= compiled.genesis_proof }
        in
        let%map () =
          match%map store ~filename values.genesis_proof with
          | Ok () ->
              [%log info] "Compile-time genesis proof written to $path"
                ~metadata:[("path", `String filename)]
          | Error err ->
              [%log warn]
                "Compile-time genesis proof could not be written to $path: \
                 $error"
                ~metadata:
                  [ ("path", `String filename)
                  ; ("error", Error_json.error_to_yojson err) ]
        in
        Ok (values, filename)
    | None when may_generate ->
        [%log info]
          "No genesis proof file was found for $base_hash, generating a new \
           genesis proof"
          ~metadata:[("base_hash", Base_hash.to_yojson base_hash)] ;
        let%bind values = generate b inputs in
        let filename = genesis_dir ^/ filename ~base_hash in
        let%map () =
          match%map store ~filename values.genesis_proof with
          | Ok () ->
              [%log info] "New genesis proof written to $path"
                ~metadata:[("path", `String filename)]
          | Error err ->
              [%log warn] "Genesis proof could not be written to $path: $error"
                ~metadata:
                  [ ("path", `String filename)
                  ; ("error", Error_json.error_to_yojson err) ]
        in
        Ok (values, filename)
    | None ->
        [%log error]
          "No genesis proof file was found for $base_hash and not allowed to \
           generate a new genesis proof"
          ~metadata:[("base_hash", Base_hash.to_yojson base_hash)] ;
        Deferred.Or_error.errorf
          "No genesis proof file was found and not allowed to generate a new \
           genesis proof"
end

let make_constraint_constants
    ~(default : Genesis_constants.Constraint_constants.t)
    (config : Runtime_config.Proof_keys.t) :
    Genesis_constants.Constraint_constants.t =
  let work_delay =
    Option.value ~default:default.work_delay config.work_delay
  in
  let block_window_duration_ms =
    Option.value ~default:default.block_window_duration_ms
      config.block_window_duration_ms
  in
  let transaction_capacity_log_2 =
    match config.transaction_capacity with
    | Some (Log_2 i) ->
        i
    | Some (Txns_per_second_x10 tps_goal_x10) ->
        let max_coinbases = 2 in
        let max_user_commands_per_block =
          (* block_window_duration is in milliseconds, so divide by 1000 divide
             by 10 again because we have tps * 10
          *)
          tps_goal_x10 * block_window_duration_ms / (1000 * 10)
        in
        (* Log of the capacity of transactions per transition.
            - 1 will only work if we don't have prover fees.
            - 2 will work with prover fees, but not if we want a transaction
              included in every block.
            - At least 3 ensures a transaction per block and the staged-ledger
              unit tests pass.
        *)
        1
        + Core_kernel.Int.ceil_log2
            (max_user_commands_per_block + max_coinbases)
    | None ->
        default.transaction_capacity_log_2
  in
  let pending_coinbase_depth =
    Core_kernel.Int.ceil_log2
      (((transaction_capacity_log_2 + 1) * (work_delay + 1)) + 1)
  in
  { sub_windows_per_window=
      Option.value ~default:default.sub_windows_per_window
        config.sub_windows_per_window
  ; ledger_depth=
      Option.value ~default:default.ledger_depth config.ledger_depth
  ; work_delay
  ; block_window_duration_ms
  ; transaction_capacity_log_2
  ; pending_coinbase_depth
  ; coinbase_amount=
      Option.value ~default:default.coinbase_amount config.coinbase_amount
  ; supercharged_coinbase_factor=
      Option.value ~default:default.supercharged_coinbase_factor
        config.supercharged_coinbase_factor
  ; account_creation_fee=
      Option.value ~default:default.account_creation_fee
        config.account_creation_fee
  ; fork=
      ( match config.fork with
      | None ->
          default.fork
      | Some {previous_state_hash; previous_length; previous_global_slot} ->
          Some
            { previous_state_hash=
                State_hash.of_base58_check_exn previous_state_hash
            ; previous_length= Mina_numbers.Length.of_int previous_length
            ; previous_global_slot=
                Mina_numbers.Global_slot.of_int previous_global_slot } ) }

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
        [%log error]
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
      ; slots_per_epoch=
          Option.value ~default:default.protocol.slots_per_epoch
            (config.genesis >>= fun cfg -> cfg.slots_per_epoch)
      ; slots_per_sub_window=
          Option.value ~default:default.protocol.slots_per_sub_window
            (config.genesis >>= fun cfg -> cfg.slots_per_sub_window)
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
    ~may_generate ~proof_level (config : Runtime_config.t) =
  let ledger_name_json =
    match
      let open Option.Let_syntax in
      let%bind ledger = config.ledger in
      ledger.name
    with
    | Some name ->
        `String name
    | None ->
        `Null
  in
  [%log info] "Initializing with runtime configuration. Ledger name: $name"
    ~metadata:
      [("name", ledger_name_json); ("config", Runtime_config.to_yojson config)] ;
  let open Deferred.Or_error.Let_syntax in
  let genesis_constants = Genesis_constants.compiled in
  let proof_level =
    List.find_map_exn ~f:Fn.id
      [ proof_level
      ; Option.Let_syntax.(
          let%bind proof = config.proof in
          match%map proof.level with
          | Full ->
              Genesis_constants.Proof_level.Full
          | Check ->
              Check
          | None ->
              None)
      ; Some Genesis_constants.Proof_level.compiled ]
  in
  let ( constraint_constants
      , generated_constraint_constants
      , blockchain_proof_system_id ) =
    match config.proof with
    | None ->
        [%log info] "Using the compiled constraint constants" ;
        ( Genesis_constants.Constraint_constants.compiled
        , false
        , Some (Precomputed_values.blockchain_proof_system_id ()) )
    | Some config ->
        [%log info]
          "Using the constraint constants from the configuration file" ;
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
        ( make_constraint_constants
            ~default:Genesis_constants.Constraint_constants.compiled config
        , true
        , blockchain_proof_system_id )
  in
  let%bind () =
    match (proof_level, Genesis_constants.Proof_level.compiled) with
    | Full, Full ->
        if generated_constraint_constants then
          if
            Genesis_constants.Constraint_constants.(equal compiled)
              constraint_constants
          then (
            [%log warn]
              "This binary only supports the compiled proof constants for \
               proof_level= Full. The 'proof' field in the configuration file \
               should be removed." ;
            return () )
          else (
            [%log fatal]
              "This binary only supports the compiled proof constants for \
               proof_level= Full. The 'proof' field in the configuration file \
               does not match." ;
            Deferred.Or_error.errorf
              "The compiled proof constants do not match the constants in the \
               configuration file" )
        else return ()
    | (Check | None), _ ->
        return ()
    | Full, ((Check | None) as compiled) ->
        let str = Genesis_constants.Proof_level.to_string in
        [%log fatal]
          "Proof level $proof_level is not compatible with compile-time proof \
           level $compiled_proof_level"
          ~metadata:
            [ ("proof_level", `String (str proof_level))
            ; ("compiled_proof_level", `String (str compiled)) ] ;
        Deferred.Or_error.errorf
          "Proof level %s is not compatible with compile-time proof level %s"
          (str proof_level) (str compiled)
  in
  let%bind genesis_ledger, ledger_config, ledger_file =
    Ledger.load ~proof_level ~genesis_dir ~logger ~constraint_constants
      (Option.value config.ledger
         ~default:
           { base= Named Mina_compile_config.genesis_ledger
           ; num_accounts= None
           ; balances= []
           ; hash= None
           ; name= None
           ; add_genesis_winner= None })
  in
  let%bind genesis_epoch_data, genesis_epoch_data_config =
    Epoch_data.load ~proof_level ~genesis_dir ~logger ~constraint_constants
      config.epoch_data
  in
  let config =
    { config with
      ledger= Option.map config.ledger ~f:(fun _ -> ledger_config)
    ; epoch_data= genesis_epoch_data_config }
  in
  let%bind genesis_constants =
    Deferred.return
    @@ make_genesis_constants ~logger ~default:genesis_constants config
  in
  let proof_inputs =
    Genesis_proof.generate_inputs ~runtime_config:config ~proof_level
      ~ledger:genesis_ledger ~constraint_constants ~genesis_constants
      ~blockchain_proof_system_id ~genesis_epoch_data
  in
  let open Deferred.Or_error.Let_syntax in
  let%map values, proof_file =
    Genesis_proof.load_or_generate ~genesis_dir ~logger ~may_generate
      proof_inputs
  in
  [%log info]
    "Loaded ledger from $ledger_file and genesis proof from $proof_file"
    ~metadata:
      [("ledger_file", `String ledger_file); ("proof_file", `String proof_file)] ;
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
        ; "log-block-creation" ]
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
            [("values", `Assoc old_fields); ("filename", `String filename)] ;
        return (`Assoc remaining_fields) )
      else (
        (* This file was written for the old format. Upgrade it. *)
        [%log warn]
          "Automatically upgrading the config file $filename. The values \
           $values have been moved to the 'daemon' object."
          ~metadata:
            [("filename", `String filename); ("values", `Assoc old_fields)] ;
        let upgraded_json =
          `Assoc (("daemon", `Assoc old_fields) :: remaining_fields)
        in
        let%map () =
          Deferred.Or_error.try_with (fun () ->
              Writer.with_file filename ~f:(fun w ->
                  Deferred.return
                  @@ Writer.write w
                       (Yojson.Safe.pretty_to_string upgraded_json) ) )
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
