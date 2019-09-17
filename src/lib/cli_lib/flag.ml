open Async

let json =
  Command.Param.(
    flag "json" no_arg ~doc:"Use json output (default: plaintext)")

let performance =
  Command.Param.(
    flag "performance" no_arg
      ~doc:
        "Include performance histograms in status output (default: don't \
         include)")

let privkey_write_path =
  let open Command.Param in
  flag "privkey-path"
    ~doc:"FILE File to write private key into (public key will be FILE.pub)"
    (required string)

let privkey_read_path =
  let open Command.Param in
  flag "privkey-path" ~doc:"FILE File to read private key from"
    (required string)

let conf_dir =
  let open Command.Param in
  flag "config-directory" ~doc:"DIR Configuration directory" (optional string)

let port =
  Command.Param.flag "daemon-port"
    ~doc:
      (Printf.sprintf "PORT Client to daemon local communication (default: %d)"
         Port.default_client)
    (Command.Param.optional Arg_type.int16)

let rest_port =
  Command.Param.flag "rest-port"
    ~doc:
      (Printf.sprintf "PORT Client to daemon rest server (default: %d)"
         Port.default_rest)
    (Command.Param.optional Arg_type.int16)
