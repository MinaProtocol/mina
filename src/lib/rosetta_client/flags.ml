(* Command-line flags shared by every Rosetta CLI.  See [flags.mli].

   The flags, their documentation and their environment overrides are
   defined here rather than in each binary: the alternative is every CLI
   re-deriving the same [--rosetta-uri] out of the same three values,
   which is how a doc string comes to disagree with the default it
   describes. *)

open Core

let uri_env_var = "MINA_ROSETTA_URI"

let blockchain_env_var = "MINA_ROSETTA_BLOCKCHAIN"

let network_env_var = "MINA_ROSETTA_NETWORK"

(* A variable that is declared but blank -- [MINA_ROSETTA_URI=], or a
   Kubernetes [env:] entry with an empty [value:] -- means "not
   configured", not "configure this to the empty string".  Taking it
   literally would build a request against an empty base URI, or send an
   empty network_identifier.network that every server rejects. *)
let env_value value ~default =
  Option.filter value ~f:(fun value ->
      not (String.is_empty (String.strip value)) )
  |> Option.value ~default

let%test_unit "a blank environment variable falls back to the default" =
  let check value = [%test_eq: string] (env_value value ~default:"d") "d" in
  check None ;
  check (Some "") ;
  check (Some "   ") ;
  [%test_eq: string] (env_value (Some "v") ~default:"d") "v"

let from_env var ~default = env_value (Sys.getenv var) ~default

(* One flag, its default taken from [env_var] and then from [default],
   with both stated in --help: an operator who has exported the variable
   sees the value they will actually get. *)
let env_flag name ~arg ~summary ~env_var ~default =
  let default = from_env env_var ~default in
  Command.Param.flag name
    ~doc:
      (sprintf "%s %s (default: %s, overridable via $%s)" arg summary default
         env_var )
    Command.Param.(optional_with_default default string)

let rosetta_uri =
  env_flag "--rosetta-uri" ~arg:"URI" ~summary:"Rosetta base URL"
    ~env_var:uri_env_var ~default:Defaults.base_uri

let blockchain =
  env_flag "--blockchain" ~arg:"NAME" ~summary:"network_identifier.blockchain"
    ~env_var:blockchain_env_var ~default:Defaults.blockchain

let network =
  env_flag "--network" ~arg:"NAME" ~summary:"network_identifier.network"
    ~env_var:network_env_var ~default:Defaults.network

let timeout ~default =
  Command.Param.flag "--timeout"
    ~doc:(sprintf "SECONDS HTTP request timeout (default: %.0f)" default)
    Command.Param.(optional_with_default default float)

let client ~timeout =
  let open Command.Let_syntax in
  let%map base_uri = rosetta_uri
  and blockchain = blockchain
  and network = network
  and timeout = timeout in
  Http.create ~base_uri:(Uri.of_string base_uri) ~blockchain ~network ~timeout
    ()
