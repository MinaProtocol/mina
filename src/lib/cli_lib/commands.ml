open Signature_lib
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
          validate_transaction keypair
      | Error err ->
          eprintf "Could not read the specified keypair: %s\n"
            (Secrets.Privkey_error.to_string err) ;
          exit 1
    in
    exit 0)
