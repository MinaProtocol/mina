open Signature_lib
open Core_kernel
open Async

let generate_keypair =
  Command.async ~summary:"Generate a new public, private keypair"
    (let open Command.Let_syntax in
    let env = Secrets.Keypair.env in
    if Option.is_some (Sys.getenv env) then
      printf "Using password from environment variable %s\n" env ;
    let%map_open privkey_path = Flag.privkey_write_path in
    Exceptions.handle_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let kp = Keypair.create () in
    let%bind () = Secrets.Keypair.Terminal_stdin.write_exn kp ~privkey_path in
    printf "Keypair generated\nPublic key: %s\nRaw public key: %s\n"
      ( kp.public_key |> Public_key.compress
      |> Public_key.Compressed.to_base58_check )
      (Rosetta_coding.Coding.of_public_key kp.public_key) ;
    exit 0)

let validate_keypair =
  Command.async ~summary:"Validate a public, private keypair"
    (let open Command.Let_syntax in
    let open Core_kernel in
    let%map_open privkey_path = Flag.privkey_write_path in
    Exceptions.handle_nicely
    @@ fun () ->
    let read_pk () =
      let pubkey_path = privkey_path ^ ".pub" in
      try
        In_channel.with_file pubkey_path ~f:(fun in_channel ->
            match In_channel.input_line in_channel with
            | Some line -> (
              try Public_key.Compressed.of_base58_check_exn line
              with _exn ->
                eprintf
                  "Could not create public key in file %s from text: %s\n"
                  pubkey_path line ;
                exit 1 )
            | None ->
                eprintf "No public key found in file %s\n" pubkey_path ;
                exit 1 )
      with exn ->
        eprintf "Could not read public key file %s, error: %s\n" pubkey_path
          (Exn.to_string exn) ;
        exit 1
    in
    let compare_public_keys ~pk_from_disk ~pk_from_keypair =
      if Public_key.Compressed.equal pk_from_disk pk_from_keypair then
        printf "Public key on-disk is derivable from private key\n"
      else (
        eprintf
          "Public key read from disk %s different than public key %s derived \
           from private key\n"
          (Public_key.Compressed.to_base58_check pk_from_disk)
          (Public_key.Compressed.to_base58_check pk_from_keypair) ;
        exit 1 )
    in
    let validate_transaction keypair =
      let dummy_payload = Mina_base.Signed_command_payload.dummy in
      let signature =
        Mina_base.Signed_command.sign_payload keypair.Keypair.private_key
          dummy_payload
      in
      let message = Mina_base.Signed_command.to_input dummy_payload in
      let verified =
        Schnorr.verify signature
          (Snark_params.Tick.Inner_curve.of_affine keypair.public_key)
          message
      in
      if verified then
        printf "Verified a transaction using specified keypair\n"
      else (
        eprintf "Failed to verify a transaction using the specific keypair\n" ;
        exit 1 )
    in
    let open Deferred.Let_syntax in
    let%bind () =
      let password =
        lazy
          (Secrets.Keypair.Terminal_stdin.prompt_password "Enter password: ")
      in
      match%map Secrets.Keypair.read ~privkey_path ~password with
      | Ok keypair ->
          let pk_from_disk = read_pk () in
          compare_public_keys ~pk_from_disk
            ~pk_from_keypair:(keypair.public_key |> Public_key.compress) ;
          validate_transaction keypair
      | Error err ->
          eprintf "Could not read the specified keypair: %s\n"
            (Secrets.Privkey_error.to_string err) ;
          exit 1
    in
    exit 0)

let validate_transaction =
  Command.async
    ~summary:
      "Validate the signature on one or more transactions, provided to stdin \
       in rosetta format"
    ( Command.Param.return
    @@ fun () ->
    let num_fails = ref 0 in
    let jsons = Yojson.Safe.stream_from_channel In_channel.stdin in
    ( match
        Or_error.try_with (fun () ->
            Caml.Stream.iter
              (fun transaction_json ->
                match
                  Or_error.try_with_join (fun () ->
                      let open Or_error.Let_syntax in
                      let%bind rosetta_transaction_rendered =
                        Rosetta_lib.Transaction.Signed.Rendered.of_yojson
                          transaction_json
                        |> Result.map_error ~f:Error.of_string
                      in
                      let%bind rosetta_transaction =
                        Rosetta_lib.Transaction.Signed.of_rendered
                          rosetta_transaction_rendered
                        |> Result.map_error ~f:(fun err ->
                               Error.of_string (Rosetta_lib.Errors.show err) )
                      in
                      let valid_until, memo =
                        (* This is a hack..
                   TODO: Handle these properly in rosetta.
                *)
                        match rosetta_transaction.command.kind with
                        | `Payment ->
                            ( Option.bind rosetta_transaction_rendered.payment
                                ~f:(fun {valid_until; _} -> valid_until)
                            , Option.bind rosetta_transaction_rendered.payment
                                ~f:(fun {memo; _} -> memo) )
                        | `Delegation ->
                            ( Option.bind
                                rosetta_transaction_rendered.stake_delegation
                                ~f:(fun {valid_until; _} -> valid_until)
                            , Option.bind
                                rosetta_transaction_rendered.stake_delegation
                                ~f:(fun {memo; _} -> memo) )
                        | `Create_token ->
                            ( Option.bind
                                rosetta_transaction_rendered.create_token
                                ~f:(fun {valid_until; _} -> valid_until)
                            , Option.bind
                                rosetta_transaction_rendered.create_token
                                ~f:(fun {memo; _} -> memo) )
                        | `Create_token_account ->
                            ( Option.bind
                                rosetta_transaction_rendered
                                  .create_token_account
                                ~f:(fun {valid_until; _} -> valid_until)
                            , Option.bind
                                rosetta_transaction_rendered
                                  .create_token_account ~f:(fun {memo; _} ->
                                  memo ) )
                        | `Mint_tokens ->
                            ( Option.bind
                                rosetta_transaction_rendered.mint_tokens
                                ~f:(fun {valid_until; _} -> valid_until)
                            , Option.bind
                                rosetta_transaction_rendered.mint_tokens
                                ~f:(fun {memo; _} -> memo) )
                      in
                      let pk (`Pk x) =
                        Public_key.Compressed.of_base58_check_exn x
                      in
                      let%bind payload =
                        Rosetta_lib.User_command_info.Partial
                        .to_user_command_payload rosetta_transaction.command
                          ~nonce:rosetta_transaction.nonce ?memo ?valid_until
                        |> Result.map_error ~f:(fun err ->
                               Error.of_string (Rosetta_lib.Errors.show err) )
                      in
                      let%map signature =
                        match
                          Mina_base.Signature.Raw.decode
                            rosetta_transaction.signature
                        with
                        | Some signature ->
                            Ok signature
                        | None ->
                            Or_error.errorf "Could not decode signature"
                      in
                      let command : Mina_base.Signed_command.t =
                        { Mina_base.Signed_command.Poly.signature
                        ; signer=
                            pk rosetta_transaction.command.fee_payer
                            |> Public_key.decompress_exn
                        ; payload }
                      in
                      command )
                with
                | Ok cmd ->
                    if Mina_base.Signed_command.check_signature cmd then
                      Format.eprintf "Transaction was valid@."
                    else (
                      incr num_fails ;
                      Format.eprintf "Transaction was invalid@." )
                | Error err ->
                    incr num_fails ;
                    Format.eprintf
                      "Failed to validate transaction:@.%s@.Failed with \
                       error:%s@."
                      (Yojson.Safe.pretty_to_string transaction_json)
                      (Yojson.Safe.pretty_to_string
                         (Error_json.error_to_yojson err)) )
              jsons )
      with
    | Ok () ->
        ()
    | Error err ->
        Format.eprintf "Error:@.%s@.@."
          (Yojson.Safe.pretty_to_string (Error_json.error_to_yojson err)) ;
        Format.printf "Invalid transaction.@." ;
        Core_kernel.exit 1 ) ;
    if !num_fails > 0 then (
      Format.printf "Some transactions failed to verify@." ;
      exit 1 )
    else (
      Format.printf "All transactions were valid@." ;
      exit 0 ) )
