open Async

let json =
  Command.Param.(
    flag "json" no_arg ~doc:"Use json output (default: plaintext)")

let privkey_write_path =
  let open Command.Param in
  flag "privkey-path"
    ~doc:"FILE File to write private key into (public key will be FILE.pub)"
    (required file)

let privkey_read_path =
  let open Command.Param in
  flag "privkey-path" ~doc:"FILE File to read private key from" (required file)

let port =
  Command.Param.flag "daemon-port"
    ~doc:
      (Printf.sprintf
          "PORT Client to daemon local communication (default: %d)"
          Port.default_client)
    (Command.Param.optional Arg_type.int16)