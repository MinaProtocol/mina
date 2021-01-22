open Core_kernel
open Signature_lib
open Async

let generate_keypair =
  Command.async ~summary:"Generate a new public, private keypair"
    (let open Command.Let_syntax in
    let env = Secrets.Keypair.env in
    ( match Sys.getenv env with
    | None ->
        ()
    | Some _ ->
        printf "Using password from environment variable %s\n" env ) ;
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
