open Core
open Async
open Signature_lib

let main privkey_path =
  let%map {public_key; _} =
    Secrets.Keypair.Terminal_stdin.read_exn privkey_path
  in
  printf "%s\n%!"
    (Public_key.Compressed.to_base58_check (Public_key.compress public_key))

let handle_exception_nicely (type a) (f : unit -> a Deferred.t) () :
    a Deferred.t =
  match%bind Deferred.Or_error.try_with ~extract_exn:true f with
  | Ok e ->
      return e
  | Error e ->
      eprintf "Error: %s" (Error.to_string_hum e) ;
      exit 4

let cmd =
  Command.async ~summary:"Generate a new public-key/private-key pair"
    (let open Command.Let_syntax in
    let%map_open privkey_path = Cli_lib.Flag.privkey_write_path in
    handle_exception_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let kp = Keypair.create () in
    let%bind () = Secrets.Keypair.Terminal_stdin.write_exn kp ~privkey_path in
    printf "Keypair generated\nPublic key: %s\n"
      ( kp.public_key |> Public_key.compress
      |> Public_key.Compressed.to_base58_check ) ;
    exit 0)

let () = Command.run cmd
